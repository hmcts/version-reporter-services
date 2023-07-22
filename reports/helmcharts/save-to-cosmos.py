import os
import sys
import json
from azure.cosmos import CosmosClient, exceptions

# Environment variables passed in via sds flux configuration
endpoint = os.environ.get("COSMOS_DB_URI", None)
key = os.environ.get("COSMOS_KEY", None)
database = os.environ.get("COSMOS_DB_NAME", "reports")
container = os.environ.get("COSMOS_DB_CONTAINER", "helmcharts")

# Document passing in as arguments from bash script
# Convert to json object from string
document = json.loads(sys.argv[1])

# Establish connection to cosmos db
client = CosmosClient(endpoint, key)

# Save document to cosmos db
try:
    print("Saving '{}' chart to database".format(document.get("chartName")))
    database = client.get_database_client(database)
    container = database.get_container_client(container)
    container.create_item(body=document)
except exceptions.CosmosHttpResponseError:
    print(f"Saving to db failed")
    raise

print("Document successfully sent to Cosmos")
