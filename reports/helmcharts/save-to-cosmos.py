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
container_name = os.environ.get("COSMOS_DB_CONTAINER", "helmcharts")


# Checks to determine if the chart has already been processed
# If chart data has not changed i.e the chart name, namespace, latest version and cluster name, it will be the same
def document_exists(container, data):
    db_result = None
    chart_name = data.get("chart")
    namespace = data.get("namespace")
    latest_version = data.get("latest")
    cluster_name = data.get("cluster")

    print(f"Querying for existing document by chart: {chart_name}")

    items = list(container.query_items(
        query="SELECT * FROM helmcharts r WHERE r.chart=@chart_name and r.namespace=@namespace and r.latest=@latest_version and r.cluster=@cluster_name",
        parameters=[
            dict(name='@chart_name', value=chart_name),
            dict(name='@namespace', value=namespace),
            dict(name='@latest_version', value=latest_version),
            dict(name='@cluster_name', value=cluster_name)
        ],
        enable_cross_partition_query=True
    ))

    if not items:
        print(f"No items returned")
        print(f"{chart_name} chart has not changed")
    else:
        total = len(items)
        if total > 1:
            print(f"Expected {chart_name} to return only 1 item, it returned {total}")

        db_result = items[0]  # Should be only one match

    return db_result


# If the chart is still at the same version then we'll update only the installed version
# which is whats likely to have changed due to an update
def update_document(container, current_doc, new_doc):
    installed_version = new_doc.get("installed")
    last_updated = get_formatted_datetime()

    current_doc["installed"] = installed_version
    current_doc["lastUpdated"] = last_updated

    response = container.upsert_item(body=current_doc)
    print('Upserted Item: Id: {0}, chart: {1}'.format(response['id'], response['chart']))


# Add new documents to database
def add_document(container, data):
    container.create_item(body=data)


def get_now():
    return datetime.now(pytz.timezone('Europe/London'))


def get_formatted_datetime(strformat="%Y-%m-%d %H:%M:%S"):
    datetime_london = get_now()
    return datetime_london.strftime(strformat)


# Document passing in as arguments from bash script
# Convert to json object from string
document = json.loads(sys.argv[1])

# Establish connection to cosmos db
client = CosmosClient(endpoint, key)

# Save document to cosmos db
try:
    database = client.get_database_client(database)
    db_container = database.get_container_client(container_name)
    current_document = document_exists(db_container, document)

    if current_document is not None:
        name = current_document.get("chart")
        print(f"Updating '{name}' chart to database")
        update_document(db_container, current_document, document)
        print(f"'{name}' document successfully updated")
    else:
        name = document.get("chart")
        print(f"Adding '{name}' chart to database")
        add_document(db_container, document)
        print(f"'{name}' document successfully saved")

except AttributeError as attribute_error:
    print(f"Saving to db failed with AttributeError error: {attribute_error}")
    raise
except exceptions.CosmosHttpResponseError as http_response_error:
    print(f"Saving to db failed with CosmosHttpResponseError error: {http_response_error}")
    raise

print("Save to database completed.")
