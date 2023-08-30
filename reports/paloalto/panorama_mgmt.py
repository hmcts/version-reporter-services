import xmltodict
from panos.panorama import Panorama
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from utility import update_document, get_document, \
    get_major_version, get_minor_version, logger, get_formatted_datetime, db_config


class PanoramaMgmt:
    """Utility for Panorama credentials"""

    def __init__(self, subscription_id, environment, server_ip, api_admin_key_name="api-admin-key"):
        self.environment = environment
        self.subscription_id = subscription_id
        self.server_ip = server_ip
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
        try:
            logger(f"Connecting to Panorama server: {host_detail.get('name')}")
            self.pano = Panorama(hostname=host_detail.get("ip"), api_key=api_key)
            logger(f"Connected to Panorama server: {host_detail.get('name')}")
        except Exception as e:
            logger(f"Connecting to Panorama server: {host_detail.get('name')} failed with: \n {e}")
            raise

        return True

    def get_system_info(self):
        xml_response = self.pano.op('show system info', xml=True)
        logger("Fetching system info completed")
        return xml_response

    def generate_server_document(self):
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
            resource_name = host_detail.get("name")

            update_document(document, {"lastUpdated": get_formatted_datetime("%d %b %Y at %H:%M:%S %p")})
            update_document(document, {"resource": resource_name})
            update_document(document, {"environment": self.environment})
            update_document(document, {"resourceType": "Panorama"})
            update_document(document, {"installed": sw_version})
            update_document(document, {"desired": desired_version})

            entry = self.get_latest_software_version()
            update_document(document, entry)
            logger(f"Server document update complete for {resource_name}")

            # color code
            latest_version = entry.get("latest")
            logger(f"Determine verdict for {resource_name}")
            self.update_document_verdict(desired_version, document, sw_version, latest_version)

            logger(f"Generating server document complete for {resource_name}")
        except Exception as e:
            document = None
            logger(f"Error occurred generating server document with error: \n{e}")

        return document

    def generate_device_documents(self):
        devices = self.get_connected_devices()
        desired_version = self.get_desired_software_version()
        entry = self.get_latest_software_version()
        latest_version = entry.get("latest")

        documents = []
        for device in devices:
            document = get_document()
            update_document(document, {"lastUpdated": get_formatted_datetime("%d %b %Y at %H:%M:%S %p")})
            update_document(document, {"resource": device.get("hostname")})
            update_document(document, {"environment": self.environment})
            update_document(document, {"resourceType": "Firewall"})
            update_document(document, {"installed": device.get("sw-version")})
            update_document(document, {"desired": desired_version})
            update_document(document, entry)

            self.update_document_verdict(desired_version, document, device.get("sw-version"), latest_version)
            documents.append(document)

        return documents

    def get_panos_api_key(self):
        try:
            panorama_keyvault_name = f"panorama-{self.environment}-uks-kv"
            kv_uri = f"https://{panorama_keyvault_name}.vault.azure.net"

            logger(f"Retrieving api key from {panorama_keyvault_name}.")
            keyvault = SecretClient(vault_url=kv_uri, credential=self.credential)
            panos_api_key = keyvault.get_secret(self.api_admin_key_name)

            logger(f"Api key retrieved from {panorama_keyvault_name}.")
        except Exception as e:
            logger(f"Error occurred generating panorama host details:\n{e}")
            raise

        return panos_api_key.value

    def get_host_detail(self):
        vm_rg = f"panorama-{self.environment}-uks-rg"
        vm_name = f"panorama-{self.environment}-uks-0"
        vm_ip = self.server_ip
        vm_environment = self.environment

        pano_vm = {
            "name": f"{vm_name}",
            "ip": f"{vm_ip}",
            "environment": f"{vm_environment}",
            "resource_group": f"{vm_rg}"
        }

        logger("Generating host detail completed")
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
                entry.update({"latest": version.get("version")})
                entry.update({"releaseNotes": version.get("release-notes")})
                entry.update({"releasedOn": version.get("released-on")})

            if f"{latest}-h" in version.get("version"):
                if version.get("current") == "no":
                    hot_fixes.append(version.get("version"))

        entry.update({"hotFixes": hot_fixes})

        logger("Generating system info detail completed")
        return entry

    def get_connected_devices(self):
        xml_response = self.pano.op('show devices connected', xml=True)
        response = xmltodict.parse(xml_response)
        return response["response"]["result"]["devices"]["entry"]

    # -------
    # Static methods
    # -------

    @staticmethod
    def update_document_verdict(desired_version, document, sw_version, latest_version):

        logger(f"desired_version is: {desired_version}")
        logger(f"sw_version is: {sw_version}")
        logger(f"latest is: {latest_version}")

        if (
                (get_major_version(latest_version) - get_major_version(sw_version)) >= 2 or
                (get_major_version(desired_version) - get_major_version(sw_version)) >= 2
        ):
            update_document(document, {"colorCode": "red"})
            update_document(document, {"verdict": "upgrade"})
            # A good place to send out a slack notice as well if verdict is to upgrade

        elif (
                (get_major_version(desired_version) == get_major_version(sw_version)) and
                ((get_minor_version(desired_version) - get_minor_version(sw_version)) >= 1)
        ):
            update_document(document, {"colorCode": "orange"})
            update_document(document, {"verdict": "review"})

        elif (
                (get_major_version(desired_version) == get_major_version(sw_version)) and
                ((get_minor_version(desired_version) - get_minor_version(sw_version)) <= 1)
        ):
            update_document(document, {"colorCode": "green"})
            update_document(document, {"verdict": "ok"})

    @staticmethod
    def get_pan_software_version(xml_response):
        response = xmltodict.parse(xml_response)
        version = response["response"]["result"]["system"]["sw-version"]
        logger(f"Retrieving software version, found: {version}")
        return version

    @staticmethod
    def get_desired_software_version():
        config = db_config()
        desired_version = config.get("desired_version")
        logger(f"Desired Version is: {desired_version}")
        return desired_version
