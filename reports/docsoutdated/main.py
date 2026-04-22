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
database = os.environ.get("COSMOS_DB_NAME", "reports")
container_name = os.environ.get("COSMOS_DB_CONTAINER", "docsoutdated")


def get_document():
    document = {
        "id": f"{uuid.uuid4()}",
        "reportName": "docsoutdated",
        "reportTitle": "Documentation out-of-date",
        "displayName": "HMCTS Documentation Review",
        "document": None,
        "docTitle": None,
        "reportType": "card",
        "reviewed": None,
        "expiry": None,
        "days": None,
        "url": None,
        "colorCode": None,
        "verdict": None
    }
    return document


def get_now():
    return datetime.now(pytz.timezone('Europe/London'))


def get_info(line):
    data = line.split("|")
    return {
        "docName": data[0].strip(),
        "docUrl": data[1].strip()
    }


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
            container.delete_item(item, partition_key=item["docTitle"])

        print("Removing documents complete")
    except exceptions.CosmosHttpResponseError as remove_response_error:
        print(f"Removing items from db failed with: {remove_response_error}")


def save_document(container, document):
    resource_name = document.get('reportTitle')
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


def extract_doc_details(doc_name, web_url, webpage):
    document = None
    page = BeautifulSoup(webpage, "html.parser")

    title = page.find("title")
    if title is None:
        doc_title = f"{doc_name} - NoTitle"
    else:
        doc_title = title.text

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

            document["document"] = doc_name
            document["docTitle"] = doc_title.replace(" - HMCTS", '')
            document["url"] = web_url
            document["expiry"] = datetime.strftime(dates.pop(), "%Y-%m-%d")

            if len(dates) == 1:
                document["reviewed"] = datetime.strftime(dates.pop(), "%Y-%m-%d")

            date_today = datetime.strptime(date.today().strftime("%Y-%m-%d"), "%Y-%m-%d")
            date_expiry = datetime.strptime(document["expiry"], "%Y-%m-%d")
            days_left = date_expiry - date_today
            document["days"] = days_left.days

        days_left = document["days"]

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
        info = get_info(line)
        doc_name = info.get("docName")
        doc_url = info.get("docUrl")

        print(f"Parent url: {doc_url}")
        parent_page = requests.get(doc_url)
        parent_doc = BeautifulSoup(parent_page.text, "html.parser")
        parent_nav = parent_doc.find("nav", {"id": "toc", "aria-labelledby": "toc-heading"})

        if parent_nav is not None:
            nav_list = parent_nav.find_all('a', href=True)

            print(f"Following and processing: {len(nav_list)} links")
            for a in nav_list:
                full_url = urljoin(doc_url, a['href'])
                child_page = requests.get(full_url)
                if child_page is not None:
                    document = extract_doc_details(doc_name, full_url, child_page.text)
                    if document is not None:
                        documents.append(document)

    return documents


try:
    print("Connection to database...")
    credential = DefaultAzureCredential()
    client = CosmosClient(endpoint, credential=credential)

    print("Setting of connectivity to database")
    database = client.get_database_client(database)
    db_container = database.get_container_client(container_name)
    report_data = build_report()
    print(f"Processing {len(report_data)} documents")

    if report_data is not None and len(report_data) > 0:
        remove_documents(db_container)
        add_documents(db_container, report_data)
        print("Document save complete")
    else:
        print(f"Cannot process empty list. {len(report_data)} documents found")

except AttributeError as attribute_error:
    print(f"Saving to db failed with AttributeError error: {attribute_error}")
except exceptions.CosmosHttpResponseError as http_response_error:
    print(f"Saving to db failed with CosmosHttpResponseError error: {http_response_error}")
