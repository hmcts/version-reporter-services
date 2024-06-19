# AKS Version Report

This report is designed to check the current version of all AKS clusters found in the listed subscriptions and then check if any updates are available for them.

The scripts goal is to find every AKS cluster within a set of subscriptions, find the available updates for those ASK clusters and then create a collection of information that gathers all of this together so it can be displayed on the Version Report Dashboard.

## Scripts

There are 2 scripts that make this report work:

- `aks-versions.sh` - This script does the search and json build
    - Searches for all subscriptions containining `SHAREDSERVICES` or `CFT` and addes the subscription Id into an array
    - Uses the list of subscriptions to then search for deployed AKS clusters and adds this information to another array
    - Checks the discovered AKS clusters for available updates
    - Builds an new json object containing all the relevant information so it can be added to a Cosmos container
- `save-to-cosmos.py` - This script is only used to interact with Cosmos DB
    - Will remove all documents from the chosen container
    - Will then add all new documents supplied to the script from the `aks-versions.sh` script

## Dockerfile

The Dockerfile will build an image that contains the scripts and will run the `aks-versions.sh` script when launched.
This container image will be run as a cronjob so that it runs on a schedule and when complete the pod will stop and eventually be removed.

The Dockerfile does not have any effect on the report process and is simply a way to make this deployable to AKS.

## Local dev

It is possible to run this script locally if you have:access to the Azure as you will need to:

- Log into Azure via the `azure cli` so the script can use your credentials/access to read the subscriptions and AKS cluster information.

and also set the following environment variables:

- COSMOS_DB_URI
- COSMOS_KEY

Both of these are values that can be found via the Azure Portal on the version reporter Cosmos DB instance.

When setup you can simply run the script locally by using `./aks-versions.sh` from the `reports/aksVersions` directory.

### Making it safer

Its also possible to completely ignore the Cosmos DB update when developing locally by commenting out the following line from the `aks-versions.sh` script:

```bash
store_document "$documents"
```

This line is a call to a function that runs the `save-to-cosmos.py` script and supplies the new documents json object.
<br>By commenting this line out and adding the following line you can see the output of the script in your terminal instead:

```bash
echo "${documents[*]}"|
```

This will output the complete object to your terminal and will remove the need to interact with CosmosDB.
