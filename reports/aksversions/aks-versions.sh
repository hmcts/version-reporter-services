#!/bin/bash
#############################################################################
# AKS Version report
# ---------------------------------------------------------------------------
# This application aims to find out the deployed version of each AKS Cluster and 
# any available upgrades and set the status for each AKS cluster based on that information.
#
# Subscriptions used are limited to any containing
# - SHAREDSERVICES
# - CFT
#
# ----------
# 1. Get list of subscriptions matching naming convention above 
# 2. Use subscriptions to find deployed AKS clusters
# 3. Find available updates for AKS clusters and build new object with all the available information into a document (json)
# 3. Save document(s) generated to cosmosdb with the aid of a python script `save-to-cosmos.py`
#############################################################################

# ---------------------------------------------------------------------------
# Define environment variables
# ---------------------------------------------------------------------------
clientId=$AZURE_CLIENT_ID
clientSecret=$AZURE_CLIENT_SECRET
tenantId=$AZURE_TENANT_ID

# ---------------------------------------------------------------------------
# Define functions
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Make a REST call to cosmos
# Document is handed over to a python process. Much easier using python that bash
# for connecting and saving to cosmos.
# ---------------------------------------------------------------------------
store_document() {
  # Add uuid, created date and environment info
  python3 ./save-to-cosmos.py "${1}"
  wait $!
}

echo "Job process start"
# ---------------------------------------------------------------------------
# STEP 1:
# ---------------------------------------------------------------------------
# Get a list of subscriptions
# --------------------------------------------------------------------------
declare -a subscriptions

subs=$(az account list --query "[?contains(name,'SHAREDSERVICES') || contains(name,'CFT')].{SubscriptionName:name, SubscriptionID:id, TenantID:tenantId}" --output json | jq -r '.[].SubscriptionID')
[[ "$subs" == "" ]] && echo "Error: cannot get a list of subscriptions." && exit 1

echo "Subscriptions found:"
for sub in $(echo "$subs"); do
  echo "$sub"
  subscriptions+=($sub)
done

# # ---------------------------------------------------------------------------
# # STEP 2:
# # ---------------------------------------------------------------------------
# # Use subscription list to search for AKS Clusters and add to aksClusterInfo array
# # Use the aksClusterInfo array to find available upgrades and build a new object for each cluster containing the version information and status 
# # --------------------------------------------------------------------------

declare -a aksClusterInfo

for sub in "${subscriptions[@]}"; do
  
  declare -a currentClusters

  echo "Setting subscription: $sub"
  az account set --subscription "$sub"
  echo "Searching for AKS clusters..."
  currentClusters+=$(az aks list --query '[*].{"Name":name,"ResourceGroup":resourceGroup, "kubernetesVersion":kubernetesVersion, "PowerState":powerState.code}' | jq .)
  echo "Done searching!"

  for cluster in $(echo "$currentClusters" | jq -c '.[]'); do
    resourceGroup=$(echo "$cluster" | jq -r '.ResourceGroup')   
    aksName=$(echo "$cluster" | jq -r '.Name')

    echo "Checking for upgrades to: $(echo $cluster | jq -r '.Name')"
    currentVersion=$(az aks get-upgrades --resource-group $resourceGroup --name $aksName | jq -r '.controlPlaneProfile.kubernetesVersion')
    upgradeAvailable=$(az aks get-upgrades --resource-group $resourceGroup --name $aksName | jq -r '.controlPlaneProfile.upgrades')

    if [[ $upgradeAvailable == 'null' ]]; then
      verdict="No Update Required"
      color_code=green
      upgradeableVersion="None"
    else
      upgradesIsPreview=$(az aks get-upgrades --resource-group $resourceGroup --name $aksName | jq -r '.controlPlaneProfile.upgrades[].isPreview')
      if [[ $upgradesIsPreview == 'null' ]]; then
        upgradeableVersion=$(az aks get-upgrades --resource-group $resourceGroup --name $aksName | jq -r '.controlPlaneProfile.upgrades[].kubernetesVersion')
        color_code=red
        verdict="Update required"
      else
        upgradeableVersion="Preview Only"
        color_code=orange
        verdict="Not ready for update"
      fi
    fi

    echo "Creating json object for: $(echo $cluster | jq -r '.Name')"
    aksClusterInfo+=$(echo "$cluster" | jq -r '.' | jq --arg verdict "$verdict" \
                                                      --arg color_code "$color_code" \
                                                      --arg currentVersion "$currentVersion" \
                                                      --arg id "$(uuidgen)" \
                                                      --arg upgradeableVersion "$upgradeableVersion" '{id: $id, clusterName: .Name, powerState: .PowerState, currentVersion: $currentVersion, upgradeableVersion: $upgradeableVersion, colorCode: $color_code,  verdict: $verdict, resourceType: "AKS Cluster"}')  
  done
  unset currentClusters
  echo "Completed subscription: $sub"
done

[[ "$aksClusterInfo" == "" ]] && echo "Error: no clusters added." && exit 1

# # ---------------------------------------------------------------------------
# # STEP 3:
# # Store document
# # ---------------------------------------------------------------------------

aksClusterInfoOutput=$(echo "${aksClusterInfo[*]}" | jq -s)
aksClusterInfoTemp=$(jq -n '$ARGS.positional' --jsonargs "${aksClusterInfoOutput[@]}")

documents=$(echo "${aksClusterInfoTemp[*]}"| jq '.[]')
[[ "$documents" == "" ]] && echo "Error: no documents ready to save." && exit 1

# Uncomment to view the output before saving to Cosmos.
# echo "${documents[*]}" | jq

# Comment this out when working locally to avoid saving to Cosmos.
store_document "$documents"

echo "Job process completed"