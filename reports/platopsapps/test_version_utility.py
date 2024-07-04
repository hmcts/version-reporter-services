import pytest
import re
from version_utility import flux_latest_version, camunda_latest_version, docmosis_latest_version, compare_versions, get_semvar, get_major_version, get_minor_version, get_patch_version

def test_get_semvar():
    version = get_semvar("v7.21.0-ee")
    assert version == "7.21.0"

def test_get_patch_version():
    version = get_patch_version("7.21.0")
    assert version == 0

def test_get_minor_version():
    version = get_minor_version("7.21.0")
    assert version == 21

def test_get_major_version():
    version = get_major_version("7.21.0")
    assert version == 7

def test_compare_versions():
    result = compare_versions("7.21.0", "7.21.5", "test")
    assert result == { 'reason': "Patch versions are different", 'colorCode': "orange", 'verdict': "review" }
    
def test_flux_latest_version():
    semver_regex = r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$"
    latest_version = flux_latest_version()

    assert latest_version is not None
    assert re.match(semver_regex, latest_version), "Returned value does not match semantic version regex"

def test_camunda_latest_version():
    semver_regex = r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$"
    latest_version = camunda_latest_version()

    assert latest_version is not None
    assert re.match(semver_regex, latest_version), "Returned value does not match semantic version regex"


def test_docmosis_latest_version():
    semver_regex = r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$"
    latest_version = docmosis_latest_version()

    assert latest_version is not None
    assert re.match(semver_regex, latest_version), "Returned value does not match semantic version regex"



# flux_latest_version, camunda_latest_version, docmosis_latest_version,