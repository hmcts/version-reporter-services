import pytz
from datetime import datetime
from azure.cosmos import exceptions

"""
Removes all documents from the specified container that match the given environment.

Parameters:
- container: The database container from which documents will be removed.
- environment: The environment to match for document removal.
"""
def remove_documents(container, environment):
    try:
        current_time = get_formatted_datetime()
        print(f"Removing all document added before {current_time}")
        # Only remove data from env where job is currently running
        query = f"SELECT * FROM c WHERE c.environment = '{environment}'"
        for item in container.query_items(
                query=query,
                enable_cross_partition_query=True):
            container.delete_item(item, partition_key=item["appName"])

        print("Removing documents complete")
    except exceptions.CosmosHttpResponseError as remove_response_error:
        print(f"Removing items from db failed with: {remove_response_error}")


"""
Adds a list of documents to the specified container.

Parameters:
- container: The database container to which documents will be added.
- documents: A list of documents to be added to the container.
"""
def add_documents(container, documents):
    print("Adding all documents.")
    try:
        for document in documents:
            save_document(container, document)
    except exceptions.CosmosHttpResponseError as add_response_error:
        print(f"Adding document to db failed with CosmosHttpResponseError: {add_response_error}")

"""
Saves a single document to the specified container.

Parameters:
- container: The database container to which the document will be saved.
- document: The document to be saved.
"""
def save_document(container, document):
    resource_name = document.get('data')
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