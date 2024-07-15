import requests
import logging
import re
import sys
from bs4 import BeautifulSoup

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

def get_semvar(version_number_str):
    version = re.search(r'(\d+\.\d+\.\d+)', version_number_str)
    return version.group(1)

def get_patch_version(version_number_str):
    return int(version_number_str[version_number_str.rfind('.') + 1:])

def get_minor_version(version_number_str):
    return int(version_number_str.split('.')[1])

def get_major_version(version_number_str):
    return int(version_number_str[0: version_number_str.find('.')])

def compare_versions(current_version, latest_version, service_name):
    """
    This function will compare to semantic versions to check if the current version is older than the latest and return a status based on the outcome.
    The function expects 3 values to be supplied in string format:
        - current version -  a semvar formatted version string (e.g. 1.2.3).
        - latest version -  a semvar formatted version string (e.g. 1.2.3).
        - service_name - a string containing the name of the service for which the versions are being checked, used in log output only.
    """

    semver_regex = r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$"

    if not all([re.match(semver_regex, version) for version in [current_version, latest_version]]):
        logging.error("One of current_version or latest_version is not a semantic version number.")
        sys.exit(1)

    try:
        logging.info(f"{service_name} current version: {current_version}")
        logging.info(f"{service_name} latest version: {latest_version}\n")

        latest_major = get_major_version(latest_version)
        current_major = get_major_version(current_version)
        latest_minor = get_minor_version(latest_version)
        current_minor = get_minor_version(current_version)
        latest_patch = get_patch_version(latest_version)
        current_patch = get_patch_version(current_version)

        if not all([[latest_major, latest_minor, latest_patch, current_major, current_minor, current_patch]]):
            logging.error("It was not possible to set the major, minor or patch version from the inputs supplied.")
            sys.exit(1)

        if latest_major != current_major:
            reason = "Major versions are different" if latest_major > current_major else "Current major version is higher than the latest major version, something went wrong!"
            colorCode = "red"
            verdict = "Upgrade" if latest_major > current_major else "error during evaluation"
        elif latest_minor != current_minor:
            reason = "Minor versions are different" if latest_minor > current_minor else "Current minor version is higher than the latest minor version, something went wrong!"
            colorCode = "orange"
            verdict = "review" if latest_minor > current_minor else "error during evaluation"
        elif latest_patch != current_patch:
            reason = "Patch versions are different" if latest_patch > current_patch else "Current patch version is higher than the latest patch version, something went wrong!"
            colorCode = "orange" if latest_patch > current_patch else "red"
            verdict = "review" if latest_patch > current_patch else "error during evaluation"
        else:
            reason = "Versions are the same"
            colorCode = "green"
            verdict = "ok"

        if verdict == "error during evaluation":
            raise ValueError(reason)

    except ValueError as e:
        reason = str(e)
        colorCode = "red"
        verdict = "error during evaluation"

            
    return { 'reason':reason, 'colorCode':colorCode, 'verdict':verdict }
            
def flux_latest_version():
    """
    This function sends a request to the Github API endpoint for the FluxCD Flux repository whichs returns all tags.
    The tags are then checked for alpha versions, those without are then compared and the most recent is found and returned.
    """
    url = "https://api.github.com/repos/fluxcd/flux2/tags"
    response = requests.get(url)
    data = response.json()

    # Filter out alpha versions and get the latest version
    latest_non_alpha_versions = [item for item in data if 'alpha' not in item['name'].lower()]
    if latest_non_alpha_versions:
        latest_version = latest_non_alpha_versions[0]['name']  # The first item is the latest version
        latest_version = latest_version.lstrip('v')
        return latest_version
    else:
        return None

def camunda_latest_version():
    """
    This function sends a GET request to the given Camunda enterprise download page containing the different versions available.
    Using a regex pattern search the latest GA version is found and returned.    
    """
    # Send a GET request to the URL
    response = requests.get("https://docs.camunda.org/enterprise/download/")

    # Extract the content of the response
    content = response.text

    # Define the regular expression pattern to extract the version
    pattern = r"version: '(\d+\.\d+\.\d+)'"

    # Use the re module to find the version
    match = re.search(pattern, content)

    # If a match is found
    if match:
        # Extract the version
        version = match.group(1)
        return version
    else:
        return None
    
def docmosis_latest_version():
    """
    This function sends a GET request to the Docmosis sitemap URL and parses the returned XML.
    It then extracts all URLS specific to Tornado downloads and finds the latest version available.
    """
    # Send a GET request to the sitemap URL
    response = requests.get("https://resources.docmosis.com/index.php?option=com_jmap&view=sitemap&format=xml")

    # Parse the sitemap XML using BeautifulSoup
    soup = BeautifulSoup(response.content, 'xml')

    # Find all the URLs in the sitemap
    urls = soup.find_all('loc')

    # Initialize the latest version and its URL
    latest_version = None

    # Iterate over each URL
    for url in urls:
        # If the URL is for a tornado software download
        if 'software-downloads/tornado' in url.text:
            # Extract the version from the URL
            version = url.text.split('tornado-v')[-1].split('-the-software')[0]
            # Convert the version to a format without 'v' and hyphens
            version = version.lstrip('v').replace('-', '.')
            # If this is the first version or it's later than the latest version
            if latest_version is None or version > latest_version:
                # Update the latest version and its URL
                latest_version = version

    # Return the latest version
    return latest_version
