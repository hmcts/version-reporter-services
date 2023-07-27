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
  uuid=$(uuidgen)
  created_on=$(date '+%Y-%m-%d %H:%M:%S')
  document=$(echo "$1" | jq --arg id "$uuid" --arg environment "$environment" --arg created_on "$created_on" '. + {id: $id, environment: $environment, createdOn: $created_on, lastUpdated: $created_on}')

  python3 ./save-to-cosmos.py "${document}"
  wait $!
}

# ---------------------------------------------------------------------------
# STEP 1:
# ---------------------------------------------------------------------------
# Get all helm repositories
# Result is filtered by these namespaces: admin, monitoring and flux-system
# This is iterated over and each chart is added to helm, making it available to helm whatup
# --------------------------------------------------------------------------

result=$(kubectl get helmrepositories.source.toolkit.fluxcd.io -A -o json | jq '.items[] | select(.metadata.namespace=="admin" or .metadata.namespace=="monitoring" or .metadata.namespace=="flux-system") | {name: .metadata.name, url: .spec.url, namespace: .metadata.namespace}' | jq -s)
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
charts=$(helm whatup -A -q -o json | jq '.releases[] | select(.namespace=="admin" or .namespace=="monitoring" or .namespace=="flux-system") | {chartName: .name, namespace: .namespace, installedVersion: .installed_version, latestVersion: .latest_version, appVersion: .app_version, chart: .chart, newestRepo: .newest_repo, updated: .updated, deprecated: .deprecated}' | jq -s)
[[ "$charts" == "" ]] && echo "Error: helm whatup failed." && exit 1

# Iterate through results and determine chart verdict
for chart in $(echo "$charts" | jq -c '.[]'); do
  latest=$(get_value "$chart" '.latestVersion')
  installed=$(get_value "$chart" '.installedVersion')

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

  # Enhance document with additional information
  document=$(echo "$chart" | jq --arg cluster_name "$cluster_name" \
                                --arg verdict $verdict \
                                --arg report_type "list" \
                                --arg display_name "HELM Repositories" \
                                --arg color_code $color_code '. + {displayName: $display_name, clusterName: $cluster_name, verdict: $verdict, colorCode: $color_code, reportType: $report_type}')
  # ---------------------------------------------------------------------------
  # STEP 3:
  # Store document
  # ---------------------------------------------------------------------------
  store_document "$document"
done
