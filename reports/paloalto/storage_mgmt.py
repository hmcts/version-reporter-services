from azure.cosmos import CosmosClient, exceptions
from utility import logger


class Storage:

    def __init__(self, config):
        self.db_uri = config.get("uri")
        self.db_key = config.get("key")
        self.db_database = config.get("database")
        self.db_container = config.get("container")
        self.client = None

        # Establish connection to db
        self.connect_to_db()

    def connect_to_db(self):
        logger("Establishing connection to cosmos db")
        self.client = CosmosClient(self.db_uri, self.db_key)
        logger("Connection established")

    def save_document(self, document):
        resource_name = document.get('resourceName')
        logger(f"Saving to db for: {resource_name}")
        try:
            database = self.client.get_database_client(self.db_database)
            container = database.get_container_client(self.db_container)
            container.upsert_item(body=document)
        except exceptions.CosmosHttpResponseError:
            logger(f"Saving to db for {resource_name} failed")
            raise
