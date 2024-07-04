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

def test_compare_versions_success():
    success = compare_versions("7.21.0", "7.21.5", "test")
    assert success == { 'reason': "Patch versions are different", 'colorCode': "orange", 'verdict': "review" }

def test_compare_versions_fail(caplog):
    with pytest.raises(SystemExit) as pytest_current_e:
        compare_versions("7.21.0", "7.21", "test")

    with pytest.raises(SystemExit) as pytest_latest_e:
        compare_versions("7.21", "7.21.1", "test")

    assert pytest_current_e.type == SystemExit
    assert pytest_current_e.value.code == 1

    assert pytest_latest_e.type == SystemExit
    assert pytest_latest_e.value.code == 1

    # Check the error message
    assert "One of current_version or latest_version is not a semantic version number" in caplog.text

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