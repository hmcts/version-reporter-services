#!/bin/bash
#############################################################################
# NPM Packages ETL report
# ---------------------------------------------------------------------------
# This application aims to find out the NPM packages used in the HMCTS organisation
#
# Steps/Flows
# ----------
# 1. Get list of HMCTS repos containing package.json from GitHub via cli commands
# 2. Extract details from json response, transform and build a list
# 3. Save document generated to cosmosdb with the aid of a python script
# NOTE: The table is emptied first the refreshed with new data
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
# Process npm repos
# ---------------------------------------------------------------------------
echo "Fetching npm repos. Maximum of ${max_repos}"

# Get PRs opened by renovate
npm_repos=$(gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/search/code?q=org:hmcts+filename:package.json&per_page=$max_repos" | jq -r '[.items[].repository.name]')

[[ "$npm_repos" == "" ]] && echo "Job process existed: Cannot get npm repositories." && exit 0

echo "Getting dependencies"
count1=$(echo "$npm_repos" | jq '. | length')
idx1=0
# Accumulator for all repositories' dependencies
all_dependencies='[]'

while [ "$idx1" -lt "$count1" ]
do
  npm_repo=$(echo "$npm_repos" | jq -r ".[$idx1]")
  echo "Processing $npm_repo"
  
  dependencies=$(gh api \
    -H "Accept: application/vnd.github.object" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/hmcts/${npm_repo}/contents/package.json | jq -r '.content' | base64 -d | jq '.dependencies')

  dev_dependencies=$(gh api \
    -H "Accept: application/vnd.github.object" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/hmcts/${npm_repo}/contents/package.json | jq -r '.content' | base64 -d | jq '.devDependencies')
  
  repo_entry=$(jq -n \
    --arg repo "$npm_repo" \
    --argjson dependencies "$dependencies" \
    --argjson devDependencies "$dev_dependencies" \
    '{repository: $repo, dependencies: $dependencies, devDependencies: $devDependencies}')

  # Append to accumulator array
  all_dependencies=$(jq -n --argjson acc "$all_dependencies" --argjson item "$repo_entry" '$acc + [ $item ]')

  idx1=$((idx1 + 1))
done

  echo $all_dependencies | jq -r '.'

# ---------------------------------------------------------------------------
# Process Results
# ---------------------------------------------------------------------------

count=$(echo "$npm_repos" | jq '. | length')

# Define an array variable to hold all documents
idx=0
declare -a documents=()

# Loop through merged documents and enhance each
while [ "$idx" -lt "$count" ]
do
  npm_repo=$(echo "$npm_repos" | jq -r ".[$idx]")
  echo "npm_repo is $npm_repo"

  # The document id
  uuid=$(uuidgen)

  repo_dependencies=$(echo $all_dependencies | jq -c '.[].dependencies')
  repo_devDependencies=$(echo $all_dependencies | jq -c '.[].devDependencies')

  # Enhance document with additional information
  document=$(jq -n \
    --arg repo "$npm_repo" \
    --arg dependencies "$repo_dependencies" \
    --arg devDependencies "$repo_devDependencies" \
    --arg id "$uuid" \
    --arg report_type "table" \
    --arg display_name "NPM packages and dependencies" \
    '{repository: $repo, dependencies: $dependencies, devDependencies: $devDependencies, id: $id, displayName: $display_name, reportType: $report_type}')

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
