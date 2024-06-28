import pytz
from datetime import datetime
from azure.cosmos import exceptions

# Checks to determine if the chart has already been processed
# If chart data has not changed i.e the chart name, namespace, latest version and cluster name, it will be the same
def remove_documents(container):
    try:
        current_time = get_formatted_datetime()
        print(f"Removing all document added before {current_time}")
        for item in container.query_items(
                query='SELECT * FROM c',
                enable_cross_partition_query=True):
            container.delete_item(item, partition_key=item["clusterName"])

        print("Removing documents complete")
    except exceptions.CosmosHttpResponseError as remove_response_error:
        print(f"Removing items from db failed with: {remove_response_error}")

# Add new documents to database
def add_documents(container, documents):
    print("Adding all documents.")
    try:
        for document in documents:
            save_document(container, document)
    except exceptions.CosmosHttpResponseError as add_response_error:
        print(f"Adding document to db failed with CosmosHttpResponseError: {add_response_error}")

def save_document(container, document):
    resource_name = document.get('cluster')
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