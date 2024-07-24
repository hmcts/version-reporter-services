# Helm Reports Microservice

The Version Reporter Service MicroServices Project

## Helm Charts

This directory contains a script that fetches Helm objects from a Kubernetes cluster by running as a job. Using the `helm whatup` command to extract the latest information about the Helm charts.

Examples of applications that this includes are:

- Keda
- Flux-system
- Kured

## Scripts

### Running the Deployment Scripts

The Helm Charts reporting service uses two main scripts: `helm-chart-versions.sh` and `save-to-cosmos.py`.

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

Additionally, set the necessary environment variables for your cluster and environment:

- `CLUSTER_NAME`
- `ENVIRONMENT`

#### Running the Scripts

1. Run the `helm-chart-versions.sh` script to generate the Helm chart versions report:

    ```sh
    ./helm-chart-versions.sh
    ```

    If you want to run the script locally without sending data to Cosmos DB, set the `SAVE_TO_COSMOS` environment variable to `false`:

    ```sh
    export SAVE_TO_COSMOS=false
    ```

### How It Works

The Helm chart reports work as follows:

1. **helm-chart-versions.sh**:
    - This script scans specified Helm charts and extracts version information.
    - It filters the Helm charts by namespace to fetch only the relevant charts.
    - It generates a report containing the versions of all Helm charts in a directory.
    - Before generating a new report, it removes any existing reports to ensure that only the latest information is stored.

2. **save-to-cosmos.py**:
    - This script reads the generated Helm chart versions report.
    - It connects to Cosmos DB using the provided environment variables (`COSMOS_DB_URI` and `COSMOS_KEY`).
    - Before saving new data, it removes existing documents for the specified environment using the query:

        ```python
        query=f"SELECT * FROM c WHERE c.environment = '{environment}'",
        ```
