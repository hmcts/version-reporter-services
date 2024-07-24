from azure.cosmos import CosmosClient, exceptions
from azure.identity import DefaultAzureCredential
from utility import logger


class Storage:

    def __init__(self, config):
        self.db_uri = config.get("uri")
        self.db_database = config.get("database")
        self.db_container = config.get("container")
        self.client = None

        # Establish connection to db
        self.connect_to_db()

    def connect_to_db(self):
        logger("Establishing connection to cosmos db")
        credential = DefaultAzureCredential()
        self.client = CosmosClient(self.db_uri, credential=credential)
        logger("Connection established")

    def save_document(self, document):
        resource_name = document.get('resource')
        logger(f"Saving to db for: {resource_name}")
        try:
            database = self.client.get_database_client(self.db_database)
            container = database.get_container_client(self.db_container)
            container.upsert_item(body=document)
        except exceptions.CosmosHttpResponseError:
            logger(f"Saving to db for {resource_name} failed")
            raise

    def remove_documents(self, environment):
        try:
            database = self.client.get_database_client(self.db_database)
            container = database.get_container_client(self.db_container)

            print(f"Removing all existing documents")
            for item in container.query_items(
                    query='SELECT * FROM c WHERE c.environment = @environment',
                    parameters=[dict(name='@environment', value=environment)],
                    enable_cross_partition_query=True):
                container.delete_item(item, partition_key=item["resourceType"])

            print("Removing documents complete")
        except exceptions.CosmosHttpResponseError as remove_response_error:
            print(f"Removing items from db failed with: {remove_response_error}")
