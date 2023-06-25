import os
import pytz
import uuid
from datetime import datetime


def get_document():
    document = {
        "id": f"{uuid.uuid4()}",
        "name": "paloalto",
        "displayName": "Palo Alto Resources",
        "reportType": "card",
        "lastUpdated": None,
        "report": {
            "name": None,
            "sw_version_latest": None,
            "sw_version_released_on": None,
            "sw_version_installed": None,
            "sw_version_desired": None,
            "resourceType": None,
            "colorCode": None,
            "verdict": None,
            "environment": None,
            "releaseNotes": None,
            "hot_fixes": []
        }
    }
    return document


def update_document(doc, update):
    doc.update(update)


def update_document_report(doc, update):
    doc["report"].update(update)


def get_now():
    return datetime.now(pytz.timezone('Europe/London'))


def get_formatted_datetime(strformat="%m/%d/%Y, %H:%M:%S"):
    datetime_london = get_now()
    return datetime_london.strftime(strformat)


def get_minor_version(version_number_str):
    return float(version_number_str[version_number_str.find('.') + 1: version_number_str.rfind('.')])


def get_major_version(version_number_str):
    return int(version_number_str[0: version_number_str.find('.')])


def logger(message):
    print("{}: {}".format(get_formatted_datetime(), message))


def db_config():
    return {
        "uri": os.environ.get('COSMOS_ENDPOINT', None),
        "key": os.environ.get('COSMOS_KEY', None),
        "database": os.environ.get('COSMOSDB_DATABASE', 'reports'),
        "container": os.environ.get('COSMOSDB_CONTAINER', 'paloalto')
    }
