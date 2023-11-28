import re
from pathlib import Path
from datetime import datetime, timezone


def get_headers_file():
    return "./queries/headers.csv"


def get_query(query):
    argQuery = Path(query).read_text()
    argQuery = re.sub("\s{2,}", ' ', argQuery)
    return argQuery


def get_vm_query():
    return get_query("./queries/vm.query")


def get_vmss_query():
    return get_query("./queries/vmss.query")


def remove_moj_subscriptions(result_data, property_name):
    result = filter(lambda data: not data[property_name].lower().startswith("moj"), result_data)
    return list(result)


def get_current_date_time():
    now = datetime.now(timezone.utc)
    return now.strftime("%Y:%m:%d %H:%M:%S")
