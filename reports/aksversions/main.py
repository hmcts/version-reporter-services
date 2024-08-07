# Import relevant packages
import os
import uuid
import json
import logging
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import SubscriptionClient
from azure.mgmt.containerservice import ContainerServiceClient
from azure.cosmos import CosmosClient, exceptions
from cosmos_functions import remove_documents, add_documents

# Set up logging with a custom format
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
# Set the logging level for the Azure SDK to WARNING to suppress INFO and DEBUG logs
logging.getLogger('azure').setLevel(logging.WARNING)

# Define Functions
def get_minor_version(version_number_str):
    """Extracts the minor version from a version string."""
    return float(version_number_str[version_number_str.find('.') + 1: version_number_str.rfind('.')])

def main():
    """Main function to fetch information from Azure for AKS Clusters and store in a cosmosdb."""
    
    #Local Dev only
    save_to_cosmos = os.getenv("SAVE_TO_COSMOS", 'True').lower() in ('true', '1', 't')


    # Define Environment variables for Cosmos
    if save_to_cosmos: 
        endpoint = os.getenv("COSMOS_DB_URI", None)
        database = os.getenv("COSMOS_DB_NAME", "reports")
        container_name = os.getenv("COSMOS_DB_CONTAINER", "aksversions")

        if not all([endpoint]):
            logging.error("COSMOS_DB_URI environment variables must be set.")
            return

    # Authenticate to Azure
    logging.info("Logging into Azure...")
    credential = DefaultAzureCredential()

    # Initialize the SubscriptionClient
    subscription_client = SubscriptionClient(credential)

    # Get all subscriptions for the tenant
    subscriptions = subscription_client.subscriptions.list()

    # Initialize an empty list to hold all the cluster information
    clusters_info = []

    # Define your search terms
    search_terms = ['CFT', 'SHAREDSERVICES']

    # For each subscription, get all AKS clusters
    logging.info("Using available subscriptions to find AKS clusters...")

    # Use the list of subscriptions to find all AKS Clusters
    for sub in subscriptions:
        # Get the subscription details
        sub_details = subscription_client.subscriptions.get(sub.subscription_id)

        # Check if the subscription name contains any of the search terms
        if any(term in sub_details.display_name for term in search_terms):

            logging.info(f"Checking subscription: {sub_details.display_name}")

            # Initialize the ContainerServiceClient for the subscription
            container_client = ContainerServiceClient(credential, sub.subscription_id)

            # Get all AKS clusters in the subscription
            aks_clusters = container_client.managed_clusters.list()

            # For each AKS cluster, get its current Kubernetes version and available upgrade versions
            for cluster in aks_clusters:
                # Extract the resource group name from the cluster id
                resource_group_name = cluster.id.split('/')[4]

                logging.info(f"Found AKS cluster: {cluster.name}")

                # Get the upgrade profile for the cluster
                upgrade_profile = container_client.managed_clusters.get_upgrade_profile(resource_group_name, cluster.name)

                logging.info(f"Checking AKS cluster: {cluster.name} for updates...")

                # Get the current version and available updates from the upgrade profile
                current_version = upgrade_profile.control_plane_profile.kubernetes_version
                updates = upgrade_profile.control_plane_profile.upgrades

                if updates is None:
                    available_updates = "No updates available"
                    verdict = "No update required"
                    color_code = "green"
                else:
                    for upgrade in updates:
                        if upgrade.is_preview:
                            available_updates = upgrade.kubernetes_version
                            verdict = "Preview only, wait for general availability"
                            color_code = "green"
                        elif ((get_minor_version(upgrade.kubernetes_version) - get_minor_version(current_version)) < 1 ):
                            available_updates = upgrade.kubernetes_version
                            verdict = "Patch version update only"
                            color_code = "orange"
                        else:
                            available_updates = upgrade.kubernetes_version
                            verdict = "Update"
                            color_code = "red"

                logging.info(f"Creating output object for: {cluster.name}")

                # Create a dictionary with all the cluster information
                cluster = {
                    "id": str(uuid.uuid4()),
                    "subscription": sub_details.display_name,
                    "clusterName": cluster.name,
                    "currentVersion": current_version,
                    "upgradeableVersion": max(available_updates) if type(available_updates) is list else available_updates,
                    "colorCode": color_code,
                    "resourceType": "CFT Cluster" if "cft" in cluster.name else "SDS Cluster",
                    "powerState": cluster.power_state.code if cluster.power_state else "Unknown",
                    "verdict": verdict
                }

                # Add the dictionary to the list
                clusters_info.append(cluster)

    # Print the list of all cluster information as a JSON object
    logging.info(f"Number of AKS Clusters found: {len(clusters_info)}.")

    if not save_to_cosmos:
        logging.info(json.dumps(clusters_info, indent=4))

    # We have all the AKS clusters now saved in clusters_info
    # Now we need to store them in CosmosDB and the aksversions container
    if save_to_cosmos:
        # Establish connection to cosmos db
        credential = DefaultAzureCredential()
        cosmosClient = CosmosClient(endpoint, credential=credential)

        # Save documents to cosmos db
        try:
            database = cosmosClient.get_database_client(database)
            db_container = database.get_container_client(container_name)

            remove_documents(db_container)
            add_documents(db_container, clusters_info)

        except AttributeError as attribute_error:
            logging.error(f"Saving to db failed with AttributeError error: {attribute_error}")
            raise
        except exceptions.CosmosHttpResponseError as http_response_error:
            logging.error(f"Saving to db failed with CosmosHttpResponseError error: {http_response_error}")
            raise

        logging.info("Save to database completed.")

if __name__ == "__main__":
    main()
