#!/bin/bash
#############################################################################
# Helm ETL report
# ---------------------------------------------------------------------------
# This application aims to find out the installed version of chart in the helm
# repository running on the cluster.
#
# Chart information from the namespaces listed below would be extracted and processed.
# - admin
# - monitoring
# - flux-system
#
# Helm whatup would also be using in conjunction with some scripting functionality to
# archive the desired aim. Data would be transformed and stored in cosmosdb
# Steps/Flows
# ----------
# 1. Get list of charts in helmrepositories, read and extract chart name and url, filter by admin type namespace
#    and add charts to helm
# 2. Use helm whatup to get installed and current version the make a verdict. Update the document with additional data
# 3. Save document generated to cosmosdb with the aid of a python script
#############################################################################

# Suppressing Intellij specific IDE syntax warning
# -- PLEASE IGNORE BELOW --
# shellcheck disable=SC2004
# shellcheck disable=SC2028
# shellcheck disable=SC2046
# shellcheck disable=SC2059
# shellcheck disable=SC2153
# --

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

sharedServicesSubs=$(az account list --query "[?contains(name,'SHAREDSERVICES')].{SubscriptionName:name, SubscriptionID:id, TenantID:tenantId}" --output json | jq -r '.[].SubscriptionID')
[[ "$sharedServicesSubs" == "" ]] && echo "Error: cannot get a list of Shared Service subscriptions." && exit 1

for sub in $(echo "$sharedServicesSubs"); do
  subscriptions+=($sub)
done

cftSubs=$(az account list --query "[?contains(name,'CFT')].{SubscriptionName:name, SubscriptionID:id, TenantID:tenantId}" --output json | jq -r '.[].SubscriptionID')
[[ "$cftSubs" == "" ]] && echo "Error: cannot get a list of CFT subscriptions." && exit 1

for sub in $(echo "$cftSubs"); do
  subscriptions+=($sub)
done

echo "Subscriptions found:"
for sub in "${subscriptions[@]}"
do
  echo "$sub"
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
        color_code=yellow
        verdict="Not ready for update"
      fi
    fi

    echo "Creating json object for: $(echo $cluster | jq -r '.Name')"
    aksClusterInfo+=$(echo "$cluster" | jq -r '.' | jq --arg verdict "$verdict" \
                                                      --arg color_code "$color_code" \
                                                      --arg currentVersion "$currentVersion" \
                                                      --arg id "$(uuidgen)" \
                                                      --arg upgradeableVersion "$upgradeableVersion" '{id: $id, clusterName: .Name, powerState: .PowerState, currentVersion: $currentVersion, upgradeableVersion: $upgradeableVersion, colorCode: $color_code,  verdict: $verdict}')  
  done
  unset currentClusters
  echo "Completed subscription: $sub"
done

# # ---------------------------------------------------------------------------
# # STEP 3:
# # Store document
# # ---------------------------------------------------------------------------

aksClusterInfoOutput=$(echo "${aksClusterInfo[*]}" | jq -s)
aksClusterInfoTemp=$(jq -n '$ARGS.positional' --jsonargs "${aksClusterInfoOutput[@]}")
documents=$(echo "${aksClusterInfoTemp[*]}"| jq '.[]')

store_document "$documents"

echo "Job process completed"