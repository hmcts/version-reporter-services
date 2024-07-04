import pytest
import re
from unittest.mock import patch, MagicMock
from main import get_pod_logs, get_current_camunda_version, get_current_docmosis_version, get_current_flux_version
from version_utility import flux_latest_version, camunda_latest_version, docmosis_latest_version, compare_versions, get_semvar, get_major_version, get_minor_version, get_patch_version

# Replace k8s client with mocked object
@pytest.fixture
def mock_kube_client():
    with patch("main.kube_client") as mock_kube_client:
        yield mock_kube_client

# Test that get pod logs matches what's returned by reading a mocked namespaced pod
def test_get_pod_logs(mock_kube_client):
    mock_kube_client.list_namespaced_pod.return_value.items = [
        MagicMock(metadata=MagicMock(name="test-pod"))
    ]
    mock_kube_client.read_namespaced_pod_log.return_value = "Some very real pod logs"
    
    logs = get_pod_logs("test-deployment", "test-ns")
    assert logs == "Some very real pod logs"

# Test camunda version is able to be identified from an example version line in pod logs
# This is the real line we should be fetching from the pod, so tests the logic of getting the version
def test_get_camunda_version(mock_kube_client):
    mock_kube_client.list_namespaced_pod.return_value.items = [
        MagicMock(metadata=MagicMock(name="test-pod"))
    ]
    mock_kube_client.read_namespaced_pod_log.return_value = """
        This is a random test
        There would be many many more lines of very useful logs
        Camunda Platform: (v7.21.0-ee)
        More lines...
    """
    version = get_current_camunda_version()
    assert version == "v7.21.0-ee"

# Test Docmosis version is able to be identified from an example version line in pod logs
# This is the real line we should be fetching from the pod, so tests the logic of getting the version
def test_get_docmosis_version(mock_kube_client):
    mock_kube_client.list_namespaced_pod.return_value.items = [
        MagicMock(metadata=MagicMock(name="test-pod"))
    ]
    mock_kube_client.read_namespaced_pod_log.return_value = """
        These are my Docmosis pod logs
        03 Jul 2024 12:30:56,190 [localhost-startStop-1] INFO  SystemManager - Docmosis version [4.4.1_8366] initialising
        They are used for testing this function
    """
    
    version = get_current_docmosis_version()
    assert version == "4.4.1_8366"

# Test we can retrieve the version of flux from a namespace label
def test_get_flux_version(mock_kube_client):
    mock_namespace = MagicMock(metadata=MagicMock(labels={"app.kubernetes.io/version": "2.3.1"}))
    mock_kube_client.read_namespace.return_value = mock_namespace
    
    version = get_current_flux_version()
    assert version == "2.3.1"

# Test we can retrieve the version of flux from a namespace label
def test_get_flux_version(mock_kube_client):
    mock_namespace = MagicMock(metadata=MagicMock(labels={"app.kubernetes.io/version": "2.3.1"}))
    mock_kube_client.read_namespace.return_value = mock_namespace
    
    version = get_current_flux_version()
    assert version == "2.3.1"

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