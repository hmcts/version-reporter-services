# AKS Version Report

This report is designed to check the current version of all AKS clusters found in the listed subscriptions and then check if any updates are available for them.

The scripts goal is to find every AKS cluster within a set of subscriptions, find the available updates for those ASK clusters and then create a collection of information that gathers all of this together so it can be displayed on the Version Report Dashboard.

## Scripts

There are 2 scripts that make this report work:

- `main.py` - This script searches Azure for AKS clusters and creates a JSON object of relevant information.
    - Searches for all subscriptions containining `SHAREDSERVICES` or `CFT` and addes the subscription Id into an array
    - Uses the list of subscriptions to then search for deployed AKS clusters and adds this information to another array
    - Checks the discovered AKS clusters for available updates
    - Builds an new json object containing all the relevant information so it can be added to a Cosmos container
- `cosmos_functions.py` - This script is only used to interact with Cosmos DB and provides functions to do so that are imported to main.py

## Dockerfile

The Dockerfile will build an image that contains the scripts and will run the `main.py` script when launched.
This container image will be run as a cronjob so that it runs on a schedule and when complete the pod will stop and eventually be removed.

The Dockerfile does not have any effect on the report process and is simply a way to make this deployable to AKS.

## Local dev

As this report utilises Python you will need to have it installed, development was carried out using `Python 3.11.7` so a version greater than `3.11.x` is recommended.

The script utilises `DefaultAzureCredential` to access Azure.
<br>Locally you simply need to log into Azure with the `azure-cli` using `az login` and the script will use your local permissions to access Azure.

For access to Cosmos however you will need to set the following environment variables for a successful connection to be made. This values are looked up within `main.py`:

- COSMOS_DB_URI
- COSMOS_KEY

These values can be found via the Azure Portal on the version reporter Cosmos DB instance.

When setup you can run the script locally by using `python main.py` from the `reports/aksversions` directory.

### Azure Python SDK

The following links may be useful if changes to the script are required:

[AKS Managed Cluster API (includes examples for Python)](https://learn.microsoft.com/en-us/rest/api/aks/managed-clusters?view=rest-aks-2024-02-01)
[AKS Managed Cluster class](https://learn.microsoft.com/en-us/python/api/azure-mgmt-containerservice/azure.mgmt.containerservice.v2022_01_01.models.managedcluster?view=azure-python)

### Making it safer

Its also possible to completely ignore the Cosmos DB update when developing locally by setting an environment variable:

```python
save_to_cosmos = os.environ.get("SAVE_TO_COSMOS", True)
```

Setting `SAVE_TO_COSMOS=False` will disable the interactions with Cosmos DB completely.

```python
# Save documents to cosmos db
if save_to_cosmos:
# Establish connection to cosmos db
    cosmosClient = CosmosClient(endpoint, credential=key)

# Save documents to cosmos db
    try:
        database = cosmosClient.get_database_client(database)
        db_container = database.get_container_client(container_name)

        remove_documents(db_container)
        add_documents(db_container, clusters_info)

```

If you disable the save to cosmos features this automatically enables output of the discovered AKS information to the terminal.
<br>This will aid local development and show all the relevant information as it would have been saved to Cosmos.
