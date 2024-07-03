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
cluster_name=$CLUSTER_NAME
environment=$ENVIRONMENT
max_versions_away=$MAX_VERSIONS_AWAY

# ---------------------------------------------------------------------------
# Define functions
# ---------------------------------------------------------------------------

# Extracts a value from json object
get_value() {
  echo "${1}" | jq -r "${2}"
}

# Extracts the first digit in the version number x.x.x
major_version() {
  echo "${1}" | cut -d'.' -f1
}

# Extracts the second digit in the version number x.x.x
minor_version() {
  echo "${1}" | cut -d'.' -f2
}

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
# Get all helm repositories
# Result is filtered by these namespaces: admin, monitoring and flux-system
# This is iterated over and each chart is added to helm, making it available to helm whatup
  
result=$(kubectl get helmrepositories -A -o json | jq '.items[] | select(.metadata.namespace=="admin" or .metadata.namespace=="monitoring" or .metadata.namespace=="flux-system" or .metadata.namespace=="keda" or .metadata.namespace=="kured" or .metadata.namespace=="dynatrace" or .metadata.namespace=="neuvector-crds" or .metadata.namespace=="pact-broker") | {name: .metadata.name, url: .spec.url, namespace: .metadata.namespace}' | jq -s)
[[ "$result" == "" ]] && echo "Error: cannot get helm repositories." && exit 1

# Iterate through helm repositories and add them to helm
for row in $(echo "$result" | jq -c '.[]'); do
  name=$(get_value "$row" '.name')
  url=$(get_value "$row" '.url')

  echo "Adding the chart '${name}' at ${url} to helm"
  helm repo add "$name" "$url"


done
# Update helm repository to get latest versions
helm repo update

# ---------------------------------------------------------------------------
# STEP 2:
# ---------------------------------------------------------------------------
# Use helm whatup to extract installed chart information
# --------------------------------------------------------------------------
charts=$(helm whatup -A -q -o json | jq '.releases[] | select(.namespace=="admin" or .namespace=="monitoring" or .namespace=="flux-system" or .namespace=="keda" or .namespace=="kured" or .namespace=="dynatrace" or .namespace=="neuvector-crds" or .namespace=="pact-broker") | {chart: .name, namespace: .namespace, installed: .installed_version, latest: .latest_version, appVersion: .app_version, newestRepo: .newest_repo, updated: .updated, deprecated: .deprecated}' | jq -s)
[[ "$charts" == "" ]] && echo "Error: helm whatup failed." && exit 1

count=$(echo "$charts" | jq '. | length')
echo "${count} charts in total to be processed"

declare -a documents=()
# Iterate through results and determine chart verdict
for chart in $(echo "$charts" | jq -c '.[]'); do
  latest=$(get_value "$chart" '.latest')
  installed=$(get_value "$chart" '.installed')

  latest_major=$(major_version "$latest")
  installed_major=$(major_version "$installed")

  latest_minor=$(minor_version "$latest")
  installed_minor=$(minor_version "$installed")
  minor_distance=$(($latest_minor - $installed_minor))

  if [[ $latest_major -gt $installed_major ]]; then
    # major version ahead, flag as needing upgrade
    verdict=upgrade
    color_code=red
  elif [[ $minor_distance -gt $max_versions_away ]]; then
    # x minor versions away, flag as needing review
    verdict=review
    color_code=orange
  else
    # Happy days
    verdict=ok
    color_code=green
  fi


  cosmosdb_account_name="$COSMOSDB_ACCOUNT_NAME"
  cosmosdb_database_name="$COSMOS_DB_NAME"
  cosmosdb_container_name="$COSMOS_DB_CONTAINER"
  id_to_check="$id"
  new_verdict="approved"

  for chart in $(echo "$charts" | jq -c '.[]'); do
  helm_chart_name=$(echo "$chart" | jq -r '.name')
  created_on=$(date '+%Y-%m-%d %H:%M:%S')
  id="${cluster_name}-${helm_chart_name}"
  
  document=$(echo "$chart" | jq --arg cluster_name "$cluster_name" \
                                --arg verdict $verdict \
                                --arg id "$id" \
                                --arg environment "$environment" \
                                --arg created_on "$created_on" \
                                --arg report_type "table" \
                                --arg display_name "HELM Repositories" \
                                --arg color_code $color_code '. + {id: $id, environment: $environment, createdOn: $created_on, lastUpdated: $created_on, displayName: $display_name, cluster: $cluster_name, verdict: $verdict, colorCode: $color_code, reportType: $report_type}')

  query_result=$(az cosmosdb sql query  \ #command do not exist need fixing 
  --account-name "$cosmosdb_account_name" \
  --database-name "$cosmosdb_database_name" \
  --name "$cosmosdb_container_name" \
  --query "SELECT * FROM c WHERE c.id = '$id'" \
  --output json)

  if [[ $query_result == "[]" ]]; then
      store_document "$document"
      echo "Document stored successfully."
  else
      existing_verdict=$(echo $query_result | jq -r '.[].verdict')

      if [[ "$existing_verdict" != "$new_verdict" ]]; then
          echo "Updating document with ID $id due to verdict change."
      else
          echo "Document with ID $id already exists with the same verdict."
      fi
  fi
  done
done
echo "Job process completed"


# ---------------------------------------------------------------------------
# STEP 3:
# Store document
# ---------------------------------------------------------------------------
documents=$(jq -c -n '$ARGS.positional' --jsonargs "${documents[@]}")
store_document "$documents"

echo "Job process completed"