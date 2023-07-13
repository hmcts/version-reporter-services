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

data_source = db_config()
try:
    subscription_id = data_source.get("subscription_id")
    environment = data_source.get("environment")
    private_ip = data_source.get("ip")

    logger(f"Processing environment {environment}")

    # Connect to cosmosdb server
    storage = Storage(data_source)

    # Connect to panorama server in environment
    panorama_mgmt = PanoramaMgmt(
        subscription_id=subscription_id,
        environment=environment,
        private_ip=private_ip
    )

    # Ask management server for installed software information
    logger("Fetching Panorama management info")
    panorama_document = panorama_mgmt.generate_server_document()

    if panorama_document is not None:
        logger("Saving Panorama management info")
        storage.save_document(panorama_document)

        # Ask management server for installed software information for managed devices
        logger("Fetching ngfw server info")
        device_documents = panorama_mgmt.generate_device_documents()

        for idx, device_document in enumerate(device_documents, start=1):
            logger(f"Saving ngfw server info, document: {idx}")
            storage.save_document(device_document)

        logger(f"Process complete in {environment}.")
    else:
        logger(f"Empty document returned. Nothing as saved to db for {environment}.")

except PanConnectionTimeout as timeout_error:
    logger(f"Process not complete in {environment} \n Timeout error: {timeout_error}")
except PanXapiError as api_error:
    logger(f"Process not complete in {environment} \n APi error error: {api_error}")
except BaseException as error:
    logger(f"Process not complete in {environment}.")
    logger(f"An exception occurred: {error}")
