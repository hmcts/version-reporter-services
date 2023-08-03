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
def clean_documents(container, data):
    db_result = False
    print('Got here: clean_documents')
    return db_result


# Add new documents to database
def adding_documents(container, data):
    # container.create_item(body=data)
    print(f"{documents}")
    return True


# def enhance_documents(data):
#     for document in data:
#


def get_now():
    return datetime.now(pytz.timezone('Europe/London'))


def get_formatted_datetime(strformat="%Y-%m-%d %H:%M:%S"):
    datetime_london = get_now()
    return datetime_london.strftime(strformat)


# Document passing in as arguments from bash script
# Convert to json object from string
documents = json.loads(sys.argv[1])
print(f"{documents}")

# # Establish connection to cosmos db
# client = CosmosClient(endpoint, key)
#
# # Save document to cosmos db
# try:
#     database = client.get_database_client(database)
#     db_container = database.get_container_client(container_name)
#     clean_documents = clean_documents(db_container, documents)
#
#     if clean_documents:
#         adding_documents(db_container, documents)
#     else:
#         print("Nothing to add")
#
# except exceptions.CosmosHttpResponseError:
#     print(f"Saving to db failed")
#     raise

print("Save to database completed.")
