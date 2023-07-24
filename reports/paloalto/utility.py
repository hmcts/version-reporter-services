import os
import pytz
import uuid
from datetime import datetime


def get_document():
    document = {
        "id": f"{uuid.uuid4()}",
        "displayName": "Palo Alto Resources",
        "reportType": "card",
        "lastUpdated": None,
        "resourceName": None,
        "latestVersion": None,
        "releasedOn": None,
        "installedVersion": None,
        "desiredVersion": None,
        "resourceType": None,
        "colorCode": None,
        "verdict": None,
        "environment": None,
        "releaseNotes": None,
        "hotFixes": []
    }
    return document


def update_document(doc, update):
    doc.update(update)


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


# Environment variables passed in via sds flux configuration
def db_config():
    return {
        "uri": os.environ.get("COSMOS_DB_URI", None),
        "key": os.environ.get("COSMOS_KEY", None),
        "database": os.environ.get("COSMOS_DB_NAME", "reports"),
        "container": os.environ.get("COSMOS_DB_CONTAINER", "paloalto"),
        "desired_version": os.environ.get("DESIRED_VERSION", None),
        "environment": os.environ.get("ENVIRONMENT", "sbox"),
        "server_ip": os.environ.get("SERVER_IP", "10.48.0.71"),
        "subscription_id": os.environ.get("HUB_SUBSCRIPTION_ID", "ea3a8c1e-af9d-4108-bc86-a7e2d267f49c")
    }
