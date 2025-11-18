import os
import sys
import json
import pytz
from datetime import datetime
from azure.cosmos import CosmosClient, exceptions
from azure.identity import DefaultAzureCredential

# Environment variables passed in via sds flux configuration
endpoint = os.environ.get("COSMOS_DB_URI", None)
database = os.environ.get("COSMOS_DB_NAME", "reports")
container_name = os.environ.get("COSMOS_DB_CONTAINER", "npmpackages")
max_days_away = int(os.environ.get("MAX_DAYS_AWAY", 3))

# Checks to determine if the chart has already been processed
# If chart data has not changed i.e the chart name, namespace, latest version and cluster name, it will be the same
def remove_documents(container):
    try:
        current_time = get_formatted_datetime()
        print(f"Removing all document added before {current_time}")
        for item in container.query_items(
                query='SELECT * FROM c',
                enable_cross_partition_query=True):
            container.delete_item(item, partition_key=item["repository"])

        print("Removing documents complete")
    except exceptions.CosmosHttpResponseError as remove_response_error:
        print(f"Removing items from db failed with: {remove_response_error}")


# Add new documents to database
def add_documents(container, data):
    print("Adding all document.")
    try:
        for document in data:
            save_document(container, document)
    except exceptions.CosmosHttpResponseError as add_response_error:
        print(f"Adding document to db failed with CosmosHttpResponseError: {add_response_error}")


def save_document(container, document):
    resource_name = document.get('title')
    try:
        container.create_item(body=document)
    except exceptions.CosmosHttpResponseError as save_response_error:
        print(f"Saving to db for {resource_name} failed with CosmosHttpResponseError: {save_response_error}")
        raise


def get_now():
    return datetime.now(pytz.timezone('Europe/London'))


def get_formatted_datetime(strformat="%Y-%m-%d %H:%M:%S"):
    datetime_london = get_now()
    return datetime_london.strftime(strformat)


# Document passing in as arguments from bash script
documents = json.load(sys.stdin)


# Save documents to cosmos db
try:
    print("Setting of connectivity to database")
    credential = DefaultAzureCredential()
    # Establish connection to cosmos db
    print("Connection to database...")
    client = CosmosClient(endpoint, credential=credential)
    database = client.get_database_client(database)
    db_container = database.get_container_client(container_name)

    print(f"Processing {len(documents)} documents")

    # Remove all existing items in container
    remove_documents(db_container)

    # Save all items to container
    add_documents(db_container, documents)
    print("Document save complete")

except AttributeError as attribute_error:
    print(f"Saving to db failed with AttributeError error: {attribute_error}")
    raise
except exceptions.CosmosHttpResponseError as http_response_error:
    print(f"Saving to db failed with CosmosHttpResponseError {http_response_error}")
    raise

print("Save to database completed.")
