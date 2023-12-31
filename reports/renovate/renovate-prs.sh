#!/bin/bash
#############################################################################
# Renovate ETL report
# ---------------------------------------------------------------------------
# This application aims to find out the open renovate PR in the HMCTS organisation
#
# Steps/Flows
# ----------
# 1. Get list of HMCTS organisation from GitHub via cli commands
# 2. Extract details from json response, transform and build a list
# 3. Save document generated to cosmosdb with the aid of a python script
# NOTE: The renovate table is emptied first the refreshed with new data
#############################################################################

max_repos=$MAX_REPOS

# Extracts a value from json object
get_value() {
  echo "${1}" | jq -r "${2}"
}

# Extracts a date value from a date array json format
get_date_value() {
  case "${2}" in
  'year')
    echo "${1}" | cut -d'-' -f 1 | tr -d '"' # year index
    ;;
  'month')
    echo "${1}" | cut -d'-' -f 2 | tr -d '"' # month index
    ;;
  'day')
    echo "${1}" | cut -d'-' -f 3 | tr -d '"' # day index
    ;;
  esac
}

# ---------------------------------------------------------------------------
# Make a REST call to cosmos
# Document is handed over to a python process. Much easier using python that bash
# for connecting and saving to cosmos.
# ---------------------------------------------------------------------------
store_documents() {
  python3 ./save-to-cosmos.py "${1}"
  wait $!
}

# ---------------------------------------------------------------------------
# Process Renovate PRs
# ---------------------------------------------------------------------------
echo "Fetching renovate PRs. Maximum of ${max_repos}"

# Get PRs opened by renovate
renovate_repos=$(gh search prs \
  --owner hmcts \
  --author app/renovate \
  --state=open \
  --sort=created \
  --json title,repository,createdAt,url,state -L "$max_repos" | jq -r '. | unique_by(.title)')

[[ "$renovate_repos" == "" ]] && echo "Job process existed: Cannot get renovate repositories." && exit 0

echo "Reshaping renovate PRs. Maximum of $(echo "$renovate_repos" | jq '. | length')"
# Reshape response
renovate_result=$(echo "$renovate_repos" | jq '[.[] | {repository: .repository.name, repositoryWithOwner: .repository.nameWithOwner, title: .title, state: .state, url: .url, createdAt: .createdAt}]')
renovate_result=$(echo "$renovate_result" | jq --arg createdBy "renovate" '[.[] + {createdBy: $createdBy}]')

# ---------------------------------------------------------------------------
# Process Updatecli PRs
# ---------------------------------------------------------------------------

# Get PRs opened by updatecli
echo "Fetching updatcli PRs. Maximum of ${max_repos}"

updatecli_repos=$(gh search prs "[updatecli]" \
  --owner hmcts \
  --state=open \
  --sort=created \
  --json title,repository,createdAt,url,state -L "$max_repos" | jq -r '. | unique_by(.title)')

[[ "$updatecli_repos" == "" ]] && echo "Job process exited: Cannot get updatecli repositories." && exit 0

echo "Reshaping updatecli PR. Total of $(echo "$updatecli_repos" | jq '. | length')"
# Reshape response
updatecli_result=$(echo "$updatecli_repos" | jq '[.[] | {repository: .repository.name, repositoryWithOwner: .repository.nameWithOwner, title: .title, state: .state, url: .url, createdAt: .createdAt}]')
updatecli_result=$(echo "$updatecli_result" | jq --arg createdBy "updatecli" '[.[] + {createdBy: $createdBy}]')
# ---------------------------------------------------------------------------
# Process Results
# ---------------------------------------------------------------------------

# Merge results
echo "Merging results..."
repositories=$(jq --argjson renovate "$renovate_result" --argjson updatecli "$updatecli_result" -n '$renovate + $updatecli')

count=$(echo "$repositories" | jq '. | length')
echo "Merged results, ${count} in total"

# Define an array variable to hold all documents
idx=0
declare -a documents=()

# Loop through merged documents and enhance each
while [ "$idx" -lt "$count" ]
do
  repository=$(echo "$repositories" | jq -r ".[$idx]")

  # The document id
  uuid=$(uuidgen)

  # Enhance document with additional information
  document=$(echo "$repository" | jq --arg id "$uuid" \
    --arg report_type "table" \
    --arg display_name "Open Renovate Pull Requests" '. + {id: $id, displayName: $display_name,  reportType: $report_type}')

  documents+=("$document")
  idx=$((idx + 1))
done

# ---------------------------------------------------------------------------
# Store results to database
# ---------------------------------------------------------------------------

# Convert bash array to json array
documents=$(jq -c -n '$ARGS.positional' --jsonargs "${documents[@]}")

# Pass documents to python for database storage
echo "Send documents for storage"
store_documents "$documents"

echo "Job process completed"
