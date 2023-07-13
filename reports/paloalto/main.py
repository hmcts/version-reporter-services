"""
Module providing functionality to fetch information
from Panorama servers and store in a cosmosdb.
"""
# --------
# Import relevant packages
# --------
from pan.xapi import PanXapiError
from panos.errors import PanConnectionTimeout

from panorama_mgmt import PanoramaMgmt
from storage_mgmt import Storage
from utility import db_config, logger

# --------
# Data sources, where the Panorama management servers resided
# --------

# May need re-homing
data_sources = [
    {
        "environment": "sbox",
        "ip": "10.48.0.71",
        "subscription_id": "ea3a8c1e-af9d-4108-bc86-a7e2d267f49c"
    },
    {
        "environment": "prod",
        "ip": "10.50.10.132",
        "subscription_id": "0978315c-75fe-4ada-9d11-1eb5e0e0b214"
    }
]

for data_source in data_sources:
    try:
        subscription_id = data_source.get("subscription_id")
        environment = data_source.get("environment")
        private_ip = data_source.get("ip")

        logger(f"Processing environment {environment}")

        # Connect to cosmosdb server
        storage = Storage(db_config())

        # Connect to panorama server in environment
        panorama_mgmt = PanoramaMgmt(
            subscription_id=subscription_id,
            environment=environment,
            private_ip=private_ip
        )

        # Ask management server for installed software information
        logger("Fetching Panorama management info")
        panorama_document = panorama_mgmt.generate_mgmt_server_document()

        logger("Saving Panorama management info")
        storage.save_document(panorama_document)

        # Ask management server for installed software information for managed devices
        logger("Fetching ngfw server info")
        device_documents = panorama_mgmt.generate_connected_device_documents()

        for idx, device_document in enumerate(device_documents, start=1):
            logger(f"Saving ngfw server info, document: {idx}")
            storage.save_document(device_document)

        logger(f"Process complete in {environment}.")

    except PanConnectionTimeout as timeout_error:
        logger(f"Process not complete in {environment} \n With error {timeout_error}")
    except PanXapiError as api_error:
        logger(f"Process not complete in {environment} \n With error {api_error}")
    except BaseException as error:
        logger(f"Process not complete in {environment}.")
        logger(f"An exception occurred: {error}")
