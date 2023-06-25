import xmltodict
from panos.panorama import Panorama
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.network import NetworkManagementClient
from utility import *


class PanoramaMgmt:
    """Utility for Panorama credentials"""

    def __init__(self, subscription_id, environment, api_admin_key_name="api-admin-key"):
        self.environment = environment
        self.subscription_id = subscription_id
        self.api_admin_key_name = api_admin_key_name
        self.credential = DefaultAzureCredential()
        self.pano = None

    def connect_to_mgmt_server(self):
        """
        Uses the api key and host detail to establish a connection
        to the panorama management server
        :return: True if no exceptions
        """
        api_key = self.get_panos_api_key()
        host_detail = self.get_host_detail()
        self.pano = Panorama(hostname=host_detail.get("ip"), api_key=api_key)
        return True

    def get_system_info(self):
        xml_response = self.pano.op('show system info', xml=True)
        return xml_response

    def generate_mgmt_server_document(self):
        """
        Generate requited document to be saved in cosmos db
        for Panorama vm record
        :return: vm detail document
        """
        document = get_document()

        try:
            self.connect_to_mgmt_server()
            system_info = self.get_system_info()
            host_detail = self.get_host_detail()
            sw_version = self.get_pan_software_version(system_info)
            desired_version = self.get_desired_software_version()

            update_document(document, {"lastUpdated": get_formatted_datetime("%d %b %Y at %H:%M:%S %p")})
            update_document_report(document, {"name": host_detail.get("name")})
            update_document_report(document, {"environment": self.environment})
            update_document_report(document, {"resourceType": "Panorama"})
            update_document_report(document, {"sw_version_installed": sw_version})
            update_document_report(document, {"sw_version_desired": desired_version})

            entry = self.get_latest_software_version()
            update_document_report(document, entry)

            # color code
            sw_version_latest = entry.get("sw_version_latest")
            self.update_document_verdict(desired_version, document, sw_version, sw_version_latest)

        except Exception as e:
            logger("Error occurred generating panorama host details:\n{}".format(e))

        return document

    def generate_connected_device_documents(self):
        devices = self.get_connected_devices()
        desired_version = self.get_desired_software_version()
        entry = self.get_latest_software_version()
        sw_version_latest = entry.get("sw_version_latest")

        documents = []
        for device in devices:
            document = get_document()
            update_document(document, {"lastUpdated": get_formatted_datetime("%d %b %Y at %H:%M:%S %p")})
            update_document_report(document, {"name": device.get("hostname")})
            update_document_report(document, {"environment": self.environment})
            update_document_report(document, {"resourceType": "Firewall"})
            update_document_report(document, {"sw_version_installed": device.get("sw-version")})
            update_document_report(document, {"sw_version_desired": desired_version})
            update_document_report(document, entry)

            self.update_document_verdict(desired_version, document, device.get("sw-version"), sw_version_latest)
            documents.append(document)

        return documents

    def get_panos_api_key(self):
        panorama_keyvault_name = f"panorama-{self.environment}-uks-kv"
        kv_uri = f"https://{panorama_keyvault_name}.vault.azure.net"

        logger(f"Retrieving api key from {panorama_keyvault_name}.")
        keyvault = SecretClient(vault_url=kv_uri, credential=self.credential)
        panos_api_key = keyvault.get_secret(self.api_admin_key_name)

        logger(f"Api key  retrieved from {panorama_keyvault_name}.")
        return panos_api_key.value

    def get_host_detail(self):
        vm_rg = f"panorama-{self.environment}-uks-rg"
        vm_name = f"panorama-{self.environment}-uks-0"

        compute_client = ComputeManagementClient(self.credential, self.subscription_id)
        network_client = NetworkManagementClient(self.credential, self.subscription_id)

        logger("Get virtual machine detail {} from {}".format(vm_name, vm_rg))
        vm_os = compute_client.virtual_machines.get(vm_rg, vm_name)
        private_ip = self.get_private(vm_os, network_client)

        pano_vm = {
            "name": vm_name,
            "ip": private_ip,
            "environment": self.environment,
            "resource_group": vm_rg
        }

        return pano_vm

    def get_latest_software_version(self):
        xml_response = self.pano.op('request system software info', xml=True)
        response = xmltodict.parse(xml_response)
        versions = response["response"]["result"]["sw-updates"]["versions"]["entry"]
        entry = {}
        hot_fixes = []
        latest = ""

        for version in versions:
            if version.get("latest") == "yes":
                latest = version.get("version")
                entry.update({"sw_version_latest": version.get("version")})
                entry.update({"releaseNotes": version.get("release-notes")})
                entry.update({"sw_version_released_on": version.get("released-on")})

            if latest + "-h" in version.get("version"):
                if version.get("current") == "no":
                    hot_fixes.append(version.get("version"))

        entry.update({"hot_fixes": hot_fixes})

        return entry

    def get_connected_devices(self):
        xml_response = self.pano.op('show devices connected', xml=True)
        response = xmltodict.parse(xml_response)
        return response["response"]["result"]["devices"]["entry"]

    # -------
    # Static methods
    # -------

    @staticmethod
    def update_document_verdict(desired_version, document, sw_version, sw_version_latest):
        if (
                (get_major_version(sw_version_latest) - get_major_version(sw_version)) >= 2 or
                (get_major_version(desired_version) - get_major_version(sw_version)) >= 2
        ):
            update_document_report(document, {"colorCode": "red"})
            update_document_report(document, {"verdict": "upgrade"})

        elif (
                (get_major_version(desired_version) == get_major_version(sw_version)) and
                ((get_minor_version(desired_version) - get_minor_version(sw_version)) >= 1)
        ):
            update_document_report(document, {"colorCode": "orange"})
            update_document_report(document, {"verdict": "review"})

        elif (
                (get_major_version(desired_version) == get_major_version(sw_version)) and
                ((get_minor_version(desired_version) - get_minor_version(sw_version)) <= 1)
        ):
            update_document_report(document, {"colorCode": "green"})
            update_document_report(document, {"verdict": "ok"})

    @staticmethod
    def get_private(vm_os, network_client):
        ip_addresses = []

        logger("Getting ip address...")

        for interface in vm_os.network_profile.network_interfaces:
            name = " ".join(interface.id.split('/')[-1:])
            sub = "".join(interface.id.split('/')[4])
            try:
                ip_configurations = network_client.network_interfaces.get(sub, name).ip_configurations
                for ip_configuration in ip_configurations:
                    ip_addresses.append(ip_configuration.private_ip_address)
            except Exception as e:
                logger("Error occurred getting vm ip address\n{}".format(e))

        return ip_addresses[0]

    @staticmethod
    def get_pan_software_version(xml_response):
        response = xmltodict.parse(xml_response)
        return response["response"]["result"]["system"]["sw-version"]

    @staticmethod
    def get_desired_software_version():
        return os.environ['DESIRED_SOFTWARE_VERSION']
