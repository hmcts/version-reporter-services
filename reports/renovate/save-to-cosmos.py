import os
import sys
import json
import pytz
from datetime import datetime
from azure.cosmos import CosmosClient, exceptions

# Environment variables passed in via sds flux configuration
endpoint = os.environ.get("COSMOS_DB_URI", None)
key = os.environ.get("COSMOS_KEY", None)
database = os.environ.get("COSMOS_DB_NAME", "reports")
container_name = os.environ.get("COSMOS_DB_CONTAINER", "renovate")


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

        print(f"Removing documents complete")
    except exceptions.CosmosHttpResponseError as exception:
        print(f"Removing items from db failed with: {exception}")


# Add new documents to database
def add_documents(container, data):
    print(f"Adding all document.")
    for document in data:
        update_days_between(document)
        save_document(container, document)


def update_days_between(document):
    today = datetime.today().strftime("%Y-%m-%dT%H:%M:%SZ")
    date_today = datetime.strptime(today, "%Y-%m-%dT%H:%M:%SZ")
    date_opened = datetime.strptime(document.get("createdAt"), "%Y-%m-%dT%H:%M:%SZ")
    # difference between dates in timedelta
    days_opened = date_today - date_opened
    document["daysOpened"] = days_opened.days


def save_document(container, document):
    resource_name = document.get('title')
    try:
        container.create_item(body=document)
    except exceptions.CosmosHttpResponseError:
        print(f"Saving to db for {resource_name} failed")
        raise


def get_now():
    return datetime.now(pytz.timezone('Europe/London'))


def get_formatted_datetime(strformat="%Y-%m-%d %H:%M:%S"):
    datetime_london = get_now()
    return datetime_london.strftime(strformat)


# Document passing in as arguments from bash script
documents = json.loads(sys.argv[1])

# Establish connection to cosmos db
print("Connection to database...")
client = CosmosClient(endpoint, key)

# Save documents to cosmos db
try:
    print("Setting of connectivity to database")
    database = client.get_database_client(database)
    db_container = database.get_container_client(container_name)

    print(f"Processing {len(documents)} documents")

    # Remove all existing items in container
    remove_documents(db_container)

    # Save all items to container
    add_documents(db_container, documents)
    print("Document save complete")

except exceptions.CosmosHttpResponseError:
    print(f"Saving to db failed")
    raise

print("Save to database completed.")
