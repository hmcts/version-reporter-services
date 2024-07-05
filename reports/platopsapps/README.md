# PlatOps Owned Applications

This report is designed to check the deployed versions where applicable of:
  - Camunda
  - Docmosis
  - Flux


## Scripts

There are 2 scripts that make this report work:

- `main.py` - This script has 3 main functions, to fetch the versions of camunda, docmosis and flux. It does this by using the kubernetes client for Python to query a deployment on the cluster the job is running on, based off deployment labels. It then takes the first pod and, depending on the situation, finds the version of the app. When looking for flux version, this is done on the namespace instead.
- `cosmos_functions.py` - This script is only used to interact with Cosmos DB and provides functions to do so that are imported to main.py
- `version_utility.py` - A script containing functions that find the latest version of each application for specific sources, also includes functions to find short form semantic version number, patch number, minor number and major number and uses these as part of the comparison function which takes the current and latest version for an application and returns the status e.g. ok, review, upgrade + some additional output

## Dockerfile

The Dockerfile will build an image that contains the scripts and will run the `main.py` script when launched.
This container image will be run as a cronjob so that it runs on a schedule and when complete the pod will stop and eventually be removed.

The Dockerfile does not have any effect on the report process and is simply a way to make this deployable to AKS.

## Local dev

As this report utilises Python you will need to have it installed, development was carried out using `Python 3.11.7` so a version greater than `3.11.x` is recommended.

For access to Cosmos however you will need to set the following environment variables for a successful connection to be made. This values are looked up within `main.py`:

- COSMOS_DB_URI
- COSMOS_KEY

These values can be found via the Azure Portal on the version reporter Cosmos DB instance.

When setup you can run the script locally by using `python main.py` from the `reports/platopsapps` directory.

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
        add_documents(db_container, documents)

```

If you disable the save to cosmos features this automatically enables output of the discovered version information to the terminal.
<br>This will aid local development and show all the relevant information as it would have been saved to Cosmos.

## Tests

The report includes test files to test the different Python functions within the main and version_utility scripts.

These tests have been written with PyTest which can be installed using pip `pip install pytest`.

To run the test script you simply need to be inside the same folder as the test file(s) `reports/platopsapps` and trigger PyTest `pytest -v` (adding -v gives verbose output for each test in the file).
