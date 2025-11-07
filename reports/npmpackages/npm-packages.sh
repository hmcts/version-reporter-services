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
  "/search/code?q=org:hmcts+filename:package.json+OR+filename:package-lock.json&per_page=$max_repos" | jq -r '[.items[].repository.name]')

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

  peer_dependencies=$(gh api \
    -H "Accept: application/vnd.github.object" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/hmcts/${npm_repo}/contents/package.json | jq -r '.content' | base64 -d | jq '.peerDependencies')
  
  repo_entry=$(jq -n \
    --arg repo "$npm_repo" \
    --argjson dependencies "$dependencies" \
    --argjson devDependencies "$dev_dependencies" \
    --argjson peerDependencies "$peer_dependencies" \
    '{repository: $repo, dependencies: $dependencies, devDependencies: $devDependencies, peerDependencies: $peerDependencies}')

  # Append to accumulator array
  all_dependencies=$(jq -n --argjson acc "$all_dependencies" --argjson item "$repo_entry" '$acc + [ $item ]')

  idx1=$((idx1 + 1))
done

  echo $all_dependencies | jq -r '.'

# ---------------------------------------------------------------------------
# Process Results
# ---------------------------------------------------------------------------

echo "Transforming to per-package documents"

# Build one document per package per repo (dependencies + devDependencies + peerDependencies)
documents=$(echo "$all_dependencies" | jq -c '
  map(
    ( .repository as $repo |
      (
        ( .dependencies // {} | to_entries | map({repository: $repo, package: .key, version: .value, dependencyType: "dependency"}) ) +
        ( .devDependencies // {} | to_entries | map({repository: $repo, package: .key, version: .value, dependencyType: "devDependency"}) ) +
        ( .peerDependencies // {} | to_entries | map({repository: $repo, package: .key, version: .value, dependencyType: "peerDependency"}) )
      )
    )
  ) | add
')

# Add a UUID per item
echo "Adding UUID to each item"
documents=$(echo "$documents" | jq -c '.[]' | while read -r item; do
  uuid=$(uuidgen)
  echo "$item" | jq --arg id "$uuid" '. + {id: $id}'
done | jq -s '.')

# ---------------------------------------------------------------------------
# Store results to database
# ---------------------------------------------------------------------------

# Pass documents to python for database storage
echo "Send documents for storage"
store_documents "$documents"

echo "Job process completed"
