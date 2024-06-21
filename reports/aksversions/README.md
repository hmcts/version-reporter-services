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
- `save-to-cosmos.py` - This script is only used to interact with Cosmos DB
    - Will remove all documents from the chosen container
    - Will then add all new documents supplied to the script from the `main.py` script

## Dockerfile

The Dockerfile will build an image that contains the scripts and will run the `main.py` script when launched.
This container image will be run as a cronjob so that it runs on a schedule and when complete the pod will stop and eventually be removed.

The Dockerfile does not have any effect on the report process and is simply a way to make this deployable to AKS.

## Local dev

As this report utilises Python you will need to have it installed, development was carried out using `Python 3.11.7` so a version greater than `3.11.x` is recommened.

The main python script requires a service principal to run with the values supplied as environment variables:

- AZURE_CLIENT_ID
- AZURE_CLIENT_SECRET
- AZURE_TENANT_ID

The service principal used within AKS can be found as secrets in the `monitoring namespace` and there are documented methods to decrypt these kinds of [secrets](https://stackoverflow.com/questions/56909180/decoding-kubernetes-secret).

The `save-to-cosmos.py` script will also require access to the Cosmos DB account and these should be supplied as environment variables as well:

- COSMOS_DB_URI
- COSMOS_KEY

These values can be found via the Azure Portal on the version reporter Cosmos DB instance.

When setup you can simply run the script locally by using `python main.py` from the `reports/aksversions` directory.

### Making it safer

Its also possible to completely ignore the Cosmos DB update when developing locally by commenting out the following line from the `main.py` script:

```python
try:
    result = subprocess.run(["python", script] + args, check=True)
except subprocess.CalledProcessError as e:
    print(f"Script {script} failed with error: {e}")
```

This code runs the `save-to-cosmos.py` script and supplies the new documents json object as the argument.

By commenting these lines out and uncommenting the following line you can see the output of the script in your terminal instead:

```python
print(json.dumps(clusters_info, indent=4))
```

This will output the complete object to your terminal and will remove the need to interact with CosmosDB.
