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
  echo "$documents" | python3 ./save-to-cosmos.py
  wait $!
}

# ---------------------------------------------------------------------------
# Process npm repos
# ---------------------------------------------------------------------------
echo "Fetching npm repos. Maximum of ${max_repos}"

# Paginated search: gather all matching items (package.json OR package-lock.json) up to MAX_REPOS
echo "Fetching code search results with pagination"
per_page=100
page=1
collected='[]'
remaining=$max_repos
while true; do
  [[ $remaining -le 0 ]] && break
  page_size=$per_page
  if [[ $remaining -lt $per_page ]]; then
    page_size=$remaining
  fi
  response=$(gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/search/code?q=org:hmcts+filename:package.json+OR+filename:package-lock.json+OR+filename:yarn.lock&per_page=$page_size&page=$page" 2>/dev/null || echo '')
  count=$(echo "$response" | jq -r '.items | length // 0')
  [[ "$count" -eq 0 ]] && break
  # Append items to collected
  items=$(echo "$response" | jq -c '[.items[]]')
  if [[ "$items" != "[]" && "$items" != "" ]]; then
    collected=$(printf '%s\n%s\n' "$collected" "$items" | jq -s 'add')
  fi
  remaining=$((remaining - count))
  echo "  Page $page: retrieved $count items (remaining allowance $remaining)"
  [[ $count -lt $page_size ]] && break
  page=$((page + 1))
done

npm_repos=$(echo "$collected" | jq -r '[.[]]')

[[ "$npm_repos" == "" ]] && echo "Job process existed: Cannot get npm repositories." && exit 0

echo "Deriving unique repositories"
unique_repos=$(echo "$npm_repos" | jq -r '.[].repository.name' | sort -u)
all_dependencies='[]'

while IFS= read -r npm_repo; do
  [[ -z "$npm_repo" ]] && continue

  # Collect all paths for this repo (package.json or package-lock.json entries)
  mapfile -t filepaths < <(echo "$npm_repos" | jq -r --arg repo "$npm_repo" '.[] | select(.repository.name == $repo) | .path')
  echo "Processing $npm_repo"

  # Per-repo aggregators (distinct from global all_dependencies array)
  repo_dependencies='{}'
  repo_dev_dependencies='{}'
  repo_peer_dependencies='{}'
  repo_resolutions='{}'

  for filepath in "${filepaths[@]}"; do
    [[ -z "$filepath" ]] && continue
    echo "    Processing filepath $filepath"
    # URL-encode path (handles spaces or special characters)
    encoded_filepath=$(jq -rn --arg p "$filepath" '$p|@uri')
    json_output=$(gh api \
      -H "Accept: application/vnd.github.object" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      /repos/hmcts/${npm_repo}/contents/${encoded_filepath} 2>/dev/null | jq -r '.content' | base64 -d 2>/dev/null || echo '')

    [[ -z "$json_output" ]] && continue

    dependencies=$(echo "$json_output" | jq '.dependencies // {}')
    dev_dependencies=$(echo "$json_output" | jq '.devDependencies // {}')
    peer_dependencies=$(echo "$json_output" | jq '.peerDependencies // {}')
    resolutions=$(echo "$json_output" | jq '.resolutions // {}')

  repo_dependencies=$(printf '%s\n%s\n' "$dependencies" "$repo_dependencies" | jq -s 'add')
  repo_dev_dependencies=$(printf '%s\n%s\n' "$dev_dependencies" "$repo_dev_dependencies" | jq -s 'add')
  repo_peer_dependencies=$(printf '%s\n%s\n' "$peer_dependencies" "$repo_peer_dependencies" | jq -s 'add')
  repo_resolutions=$(printf '%s\n%s\n' "$resolutions" "$repo_resolutions" | jq -s 'add')
  done

  repo_entry=$(jq -n \
    --arg repo "$npm_repo" \
    --argjson dependencies "$repo_dependencies" \
    --argjson devDependencies "$repo_dev_dependencies" \
    --argjson peerDependencies "$repo_peer_dependencies" \
    --argjson resolutions "$repo_resolutions" \
    '{repository: $repo, dependencies: $dependencies, devDependencies: $devDependencies, peerDependencies: $peerDependencies, resolutions: $resolutions}')

  # Append repo_entry to all_dependencies without large argv expansion
  if [[ -z "$all_dependencies" || "$all_dependencies" == "null" ]]; then
    all_dependencies='[]'
  fi
  all_dependencies=$(printf '%s\n%s\n' "$all_dependencies" "$repo_entry" | jq -s '.[0] + [ .[1] ]')

done <<< "$unique_repos"

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
        ( .dependencies // {} | to_entries | map(
            ( .value as $val |
              [ {repository: $repo, package: .key, version: (if ($val | type)=="object" then $val.version else $val end), dependencyType: (if (($val|type)=="object" and ($val.dev==true)) then "devDependency" else "dependency" end)} ]
              + ( if (($val|type)=="object" and ($val.requires?!=null)) then
                    ( $val.requires | to_entries | map({repository: $repo, package: .key, version: .value, dependencyType: (if ($val.dev==true) then "transitiveDevDependency" else "transitiveDependency" end)}) )
                  else [] end )
            )
          ) | add ) +
        ( .devDependencies // {} | to_entries | map(
            ( .value as $val |
              [ {repository: $repo, package: .key, version: (if ($val | type)=="object" then $val.version else $val end), dependencyType: "devDependency"} ]
              + ( if (($val|type)=="object" and ($val.requires?!=null)) then
                    ( $val.requires | to_entries | map({repository: $repo, package: .key, version: .value, dependencyType: "transitiveDevDependency"}) )
                  else [] end )
            )
          ) | add ) +
        ( .peerDependencies // {} | to_entries | map(
            ( .value as $val |
              [ {repository: $repo, package: .key, version: (if ($val | type)=="object" then $val.version else $val end), dependencyType: "peerDependency"} ]
              + ( if (($val|type)=="object" and ($val.requires?!=null)) then
                    ( $val.requires | to_entries | map({repository: $repo, package: .key, version: .value, dependencyType: "transitivePeerDependency"}) )
                  else [] end )
            )
          ) | add ) +
        ( .resolutions // {} | to_entries | map(
            ( .value as $val |
              [ {repository: $repo, package: .key, version: (if ($val | type)=="object" then $val.version else $val end), dependencyType: "resolution"} ]
              + ( if (($val|type)=="object" and ($val.requires?!=null)) then
                    ( $val.requires | to_entries | map({repository: $repo, package: .key, version: .value, dependencyType: "transitiveDevDependency"}) )
                  else [] end )
            )
          ) | add )
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
