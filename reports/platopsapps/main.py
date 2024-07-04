#!/usr/bin/env python3
from kubernetes import client, config
from azure.cosmos import CosmosClient, exceptions
from cosmos_functions import remove_documents, add_documents
from unittest.mock import patch, MagicMock
from version_utility import flux_latest_version, camunda_latest_version, docmosis_latest_version, compare_versions, get_semvar
import os
import sys
import uuid
import json
import logging
import re


# Function to create a mock Kubernetes client so that tests can pass in ADO. Overwritten later in script.
def get_mock_kube_client():
    mock_kube_client = MagicMock()
    return mock_kube_client
# Used for testing by setting this as the default
kube_client = get_mock_kube_client()

"""
    Function to return logs of a pod within a deployment.
    Args:
        - deployment_name: Should be the label given to the deployment you need to see logs of a pod for
        - namespace: The namespace the deployment lives in
"""
def get_pod_logs(deployment_name, namespace):
    try:
        # List pods in namespace matching deployment
        pods = kube_client.list_namespaced_pod(namespace, label_selector=f"app.kubernetes.io/name={deployment_name}")
        if pods.items:
            pod_name = pods.items[0].metadata.name
            # Fetch logs of first pod that matches
            pod_logs = kube_client.read_namespaced_pod_log(pod_name, namespace)
            return pod_logs
        return None
    except Exception as e:
        print(f"Error fetching logs from pod {pod_name} in namespace {namespace}: {e}", file=sys.stderr)
        return None

"""
    Function to fetch deployed version of camunda.
    Gets any pod from the deployment, and uses some string functions to get the version from the logs of the pod.
    Args:
        - deployment_name: Should be the label given to the deployment you need to see logs of a pod for
        - namespace: The namespace the deployment lives in
"""
def get_current_camunda_version():
    try:
        logs = get_pod_logs("camunda-api-java", "camunda")
        if logs:
            # Find camunda version in pod logs
            version_line = next((line for line in logs.splitlines() if "Camunda Platform:" in line), None)
            version = version_line.split(":")[1].strip().replace('(', '').replace(')', '')
            return version
        else:
            return None
    except Exception as e:
        print(f"Error retrieving Camunda version: {e}", file=sys.stderr)
        return None

"""
    Function to fetch deployed version of Docmosis.
    Gets any pod from the deployment, fetches the logs of this pod, and uses some regex in these logs to find
    the deployed version.
    Args:
        - deployment_name: Should be the label given to the deployment you need to see logs of a pod for
        - namespace: The namespace the deployment lives in
"""
def get_current_docmosis_version():
    try:
        logs = get_pod_logs("docmosis-base", "docmosis")
        if logs:
            version_line = next((line for line in logs.splitlines() if "Starting Tornado version:" in line), None)
            # Fetches docmosis version from a line in the logs using regex
            version = version_line.split("Starting Tornado version:")[-1].strip()
            return version
        else:
            return None
    except Exception as e:
        print(f"Error retrieving Docmosis version: {e}", file=sys.stderr)
        return None

"""
    Function to fetch deployed version of flux.
    Uses namespace labels of flux-system to verify the version
    Args:
        - namespace: Namespace to verify version in use
"""
def get_current_flux_version():
    try:
        namespace_obj = kube_client.read_namespace("flux-system")

        # Extract Flux version from labels
        if namespace_obj.metadata.labels and "app.kubernetes.io/version" in namespace_obj.metadata.labels:
            return namespace_obj.metadata.labels["app.kubernetes.io/version"]
        else:
            print(f"Version label 'app.kubernetes.io/version' not found in namespace flux-system", file=sys.stderr)
            return None
    except Exception as e:
        print(f"Error retrieving Flux version: {e}", file=sys.stderr)
        return None

if __name__ == "__main__":
    # Set necessary env vars
    save_to_cosmos = os.getenv("SAVE_TO_COSMOS", 'True').lower() in ('true', '1', 't')
    cluster_name = os.getenv("CLUSTER_NAME", None)
    environment = os.getenv("ENVIRONMENT", None)
    
    if not all([cluster_name, environment]):
        logging.error("CLUSTER_NAME and ENVIRONMENT env variables must be set.")
        sys.exit(1)

    # Load Kubernetes configuration for job
    try:
        # Local dev
        config.load_kube_config()
    except Exception as e:
        print(f"Error loading kube config: {e}", file=sys.stderr)
        try:
            # Uses service account given to pod by k8s to connect to cluster.
            config.load_incluster_config()
        except Exception as e:
            print(f"Error loading in-cluster config: {e}", file=sys.stderr)
            exit(1)
    # Create Kubernetes API clients
    kube_client = client.CoreV1Api()
    
    services = [
        "Camunda",
        "Docmosis",
        "Flux"
    ]

    documents = []
 
    for service in services:
        version_function = globals()[f'get_current_{service.lower()}_version']
        
        logging.info(f"Fetching {service} version information...")
        current_version = version_function()

        data = {}
        if current_version:
            current_version = get_semvar(f'{current_version}')
            latest_version = globals()[f'{service.lower()}_latest_version']
            
            latest_version = latest_version()

            status = compare_versions(current_version, latest_version, service)

            data = {
                "id": str(uuid.uuid4()) + "_" + cluster_name,
                "appName": service,
                "recordType": service,
                "currentVersion": current_version,
                "clusterName": cluster_name,
                "environment": environment,
                "requiredVersion": latest_version,
                "colorCode": status['colorCode'],
                "verdict": status['verdict'],
                "reason": status['reason'],
            }
        if data:
            # Add to list of documents to upload to cosmos
            documents.append(data)

    if save_to_cosmos:
        endpoint = os.getenv("COSMOS_DB_URI", None)
        key = os.getenv("COSMOS_KEY", None)
        database = os.getenv("COSMOS_DB_NAME", "reports")
        container_name = os.getenv("COSMOS_DB_CONTAINER", "platopsapps")
        

        if not all([endpoint, key, database, container_name]):
            logging.error("COSMOS_DB_URI, COSMOS_KEY, COSMOS_DB_NAME, and COSMOS_DB_CONTAINER environment variables must be set.")
            sys.exit(1)

        # Save documents to cosmos db
        try:
            cosmosClient = CosmosClient(endpoint, credential=key)
            database = cosmosClient.get_database_client(database)
            db_container = database.get_container_client(container_name)
            remove_documents(db_container, environment)
            add_documents(db_container, documents)
        except AttributeError as attribute_error:
            logging.error(f"Saving to db failed with AttributeError error: {attribute_error}")
            raise
        except exceptions.CosmosHttpResponseError as http_response_error:
            logging.error(f"Saving to db failed with CosmosHttpResponseError error: {http_response_error}")
            raise
        logging.info("Save to database completed.")
    else:
        logging.info(json.dumps(documents, indent=4))

