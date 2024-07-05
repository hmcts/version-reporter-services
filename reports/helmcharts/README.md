# Helm Reports Microservice

The Version Reporter Service MicroServices Project

## Helm Charts

This directory contains Helm charts used for deploying various services. Helm is a package manager for Kubernetes that allows you to define, install, and upgrade even the most complex Kubernetes applications.

## Scripts

### Running the Deployment Scripts

The Helm charts use two scripts: `helm-chart-versions.sh` and `save-to-cosmos.py`.

#### Prerequisites

1. Ensure you have Python installed. You can install Python using Homebrew:

    ```sh
    brew install python
    ```

2. Install the required Python dependencies. Navigate to the directory containing `requirements.txt` and run:

    ```sh
    pip install -r requirements.txt
    ```

#### Environment Variables

You will need to set the following environment variables before the scripts can connect to Cosmos DB:

- `COSMOS_DB_URI`
- `COSMOS_KEY`

Additionally, set the necessary environment variables for your cluster and environment:

- `CLUSTER_NAME`
- `ENVIRONMENT`

#### Running the Scripts

1. Run the `helm-chart-versions.sh` script to generate the Helm chart versions report:

    ```sh
    ./helm-chart-versions.sh
    ```

    This script will automatically remove old reports before adding any new contents to Cosmos DB.

2. Run the `save-to-cosmos.py` script to save the results to Cosmos DB:

    ```sh
    python save-to-cosmos.py
    ```

These steps should help you run the deployment scripts locally and manage your Helm chart versions effectively.