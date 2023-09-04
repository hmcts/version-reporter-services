import requests
import datefinder
import uuid
import json
import os
import pytz
from bs4 import BeautifulSoup
from datetime import date
from datetime import datetime
from urllib.parse import urljoin
from azure.cosmos import CosmosClient, exceptions

# Environment variables passed in via sds flux configuration
endpoint = os.environ.get("COSMOS_DB_URI", None)
key = os.environ.get("COSMOS_KEY", None)
database = os.environ.get("COSMOS_DB_NAME", "reports")
container_name = os.environ.get("COSMOS_DB_CONTAINER", "docsoutdated")


def get_document():
    document = {
        "id": f"{uuid.uuid4()}",
        "docName": None,
        "displayName": "HMCTS Documentation Review",
        "reportType": "card",
        "title": None,
        "lastReviewed": None,
        "pageExpiry": None,
        "daysLeft": None,
        "url": None,
        "colorCode": None,
        "verdict": None
    }
    return document


def get_now():
    return datetime.now(pytz.timezone('Europe/London'))


def get_formatted_datetime(strformat="%Y-%m-%d %H:%M:%S"):
    datetime_london = get_now()
    return datetime_london.strftime(strformat)


def remove_documents(container):
    try:
        current_time = get_formatted_datetime()
        print(f"Removing all document added before {current_time}")
        for item in container.query_items(
                query='SELECT * FROM c',
                enable_cross_partition_query=True):
            container.delete_item(item, partition_key=item["title"])

        print("Removing documents complete")
    except exceptions.CosmosHttpResponseError as remove_response_error:
        print(f"Removing items from db failed with: {remove_response_error}")


def save_document(container, document):
    resource_name = document.get('title')
    try:
        container.create_item(body=document)
    except exceptions.CosmosHttpResponseError as save_response_error:
        print(f"Saving to db for {resource_name} failed with CosmosHttpResponseError: {save_response_error}")
        raise


def add_documents(container, data):
    print("Adding all document.")
    try:
        for document in data:
            save_document(container, document)
    except exceptions.CosmosHttpResponseError as add_response_error:
        print(f"Adding document to db failed with CosmosHttpResponseError: {add_response_error}")


def extract_doc_details(name, web_url, webpage):
    document = None
    page = BeautifulSoup(webpage, "html.parser")
    title = page.find("title")
    section = page.find("div", {"class": "page-expiry--not-expired"})
    if section is None:
        section = page.find("div", {"class": "page-expiry--expired"})

    if section is not None:
        date_matches = datefinder.find_dates(section.text)
        if date_matches is not None:
            document = get_document()
            dates = []
            for item in date_matches:
                dates.append(item)

            document["docName"] = name
            document["url"] = web_url
            document["title"] = title.text
            document["pageExpiry"] = datetime.strftime(dates.pop(), "%Y-%m-%d")

            if len(dates) == 1:
                document["lastReviewed"] = datetime.strftime(dates.pop(), "%Y-%m-%d")

            date_today = datetime.strptime(date.today().strftime("%Y-%m-%d"), "%Y-%m-%d")
            date_expiry = datetime.strptime(document["pageExpiry"], "%Y-%m-%d")
            days_left = date_expiry - date_today
            document["daysLeft"] = days_left.days

        days_left = document["daysLeft"]

        if days_left >= 30:
            document["colorCode"] = "green"
            document["verdict"] = "ok"
        elif 14 < days_left < 30:
            document["colorCode"] = "orange"
            document["verdict"] = "review"
        elif days_left <= 14:
            document["colorCode"] = "red"
            document["verdict"] = "upgrade"
    else:
        print(f"No page-expiry element found: {web_url}")

    return document


def build_report():
    documents = []

    with open("documentation-urls") as file:
        lines = file.readlines()

    for line in lines:
        data = line.split("|")
        name = data[0].strip()
        url = data[1].strip()

        print(f"Parent url: {url}")
        parent_page = requests.get(url)
        parent_doc = BeautifulSoup(parent_page.text, "html.parser")
        parent_nav = parent_doc.find("nav", {"id": "toc", "aria-labelledby": "toc-heading"})

        if parent_nav is not None:
            nav_list = parent_nav.find_all('a', href=True)

            print(f"Following and processing: {len(nav_list)} links")
            for a in nav_list:
                full_url = urljoin(url, a['href'])

                child_page = requests.get(full_url)
                if child_page is not None:
                    doc = extract_doc_details(name, full_url, child_page.text)
                    if doc is not None:
                        documents.append(doc)

    return documents


# Establish connection to cosmos db
print("Connection to database...")
client = CosmosClient(endpoint, key)

# Save documents to cosmos db
try:
    print("Setting of connectivity to database")
    database = client.get_database_client(database)
    db_container = database.get_container_client(container_name)
    report_data = build_report()
    print(json.dumps(report_data, indent=4))
    print(f"Processing {len(report_data)} documents")

    if report_data is not None and len(report_data) > 0:
        remove_documents(db_container)  # Remove all existing items in container
        add_documents(container_name, report_data)  # Save all items to container
        print("Document save complete")
    else:
        print(f"Cannot process empty list. {len(report_data)} documents found")

except AttributeError as attribute_error:
    print(f"Saving to db failed with AttributeError error: {attribute_error}")
