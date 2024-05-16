import re
from datetime import datetime, timezone
from pathlib import Path


def get_headers_file():
    return "./queries/headers.csv"


def read_query_file(query):
    argQuery = Path(query).read_text()
    argQuery = re.sub("\s{2,}", ' ', argQuery)
    return argQuery


def get_query(query):
    return read_query_file(f"./queries/{query}.query")


def remove_moj_subscriptions(result_data, property_name):
    result = filter(lambda data: not data[property_name].lower().startswith("moj"), result_data)
    return list(result)


def get_current_date_time():
    now = datetime.now(timezone.utc)
    return now.strftime("%Y-%m-%d %H:%M:%S")
