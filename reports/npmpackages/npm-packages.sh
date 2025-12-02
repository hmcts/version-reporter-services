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

# uncomment this for troubleshooting the script output
# logfile=$$.log
# exec > output.txt 2>&1
# set -x

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
echo "Fetching npm repos"
# Split the repo list into 10 separate requests to avoid rate limits
total_repos=3000
batch_size=300
npm_repos=''

for ((i=0; i<total_repos; i+=batch_size)); do
  retries=0
  max_retries=3
  success=0
  while [[ $retries -le $max_retries ]]; do
    batch=$(gh repo list hmcts -L $batch_size --json name,defaultBranchRef --skip $i 2>/dev/null | jq -c '.[]')
    if [[ -z "$batch" ]]; then
      ((retries++))
      echo "Received empty response (possible 502). Retrying ($retries/$max_retries)..."
      sleep 5
    else
      npm_repos="${npm_repos}"$'\n'"${batch}"
      success=1
      break
    fi
  done
  sleep 2
done

npm_repos=$(echo "$npm_repos" | sort -u)

[[ "$npm_repos" == "" ]] && echo "Job process existed: Cannot get npm repositories." && exit 0

all_dependencies='[]'

while IFS= read -r npm_repo; do
  [[ -z "$npm_repo" ]] && continue
  repo_name=$(jq -r '.name' <<< "$npm_repo")
  default_branch=$(jq -r '.defaultBranchRef.name' <<< "$npm_repo")
  
  echo "Processing $repo_name on branch $default_branch"

  filepaths=$(gh api \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Accept: application/vnd.github+json" \
    "repos/hmcts/${repo_name}/git/trees/$default_branch?recursive=true" \
    | jq -r '.tree[].path | select(test("(^|/)package(-lock)?\\.json$"))')

  # Convert filepaths to array
  readarray -t filepaths_array <<< "$filepaths"
  # Reset per-repo associative arrays and build maps of directories that contain package.json or package-lock.json
  unset has_lock has_pkg path_exists 2>/dev/null || true
  declare -A has_lock has_pkg path_exists
  for f in "${filepaths_array[@]}"; do
    [[ -z "$f" ]] && continue
    path_exists["$f"]=1
    d=$(dirname "$f")
    case "$f" in
      */package-lock.json|package-lock.json) has_lock["$d"]=1 ;;
      */package.json|package.json) has_pkg["$d"]=1 ;;
    esac
  done

  # Helper: process one chosen path (either package-lock.json or package.json)
  process_file() {
    chosen_path="$1"
    if [[ "$chosen_path" == *"package-lock.json" ]]; then
      file_type="package-lock.json"
    else
      file_type="package.json"
    fi

    encoded_filepath=$(jq -rn --arg p "$chosen_path" '$p|@uri')
    json_output=$(gh api \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "/repos/hmcts/${repo_name}/contents/${encoded_filepath}" 2>/dev/null \
      | jq -r '.content' | base64 --decode 2>/dev/null || echo '')

    [[ -z "$json_output" ]] && return

    current_file="$chosen_path"

    if [[ "$file_type" == "package.json" ]]; then
      dependencies=$(echo "$json_output" | jq '.dependencies // {}')
      dev_dependencies=$(echo "$json_output" | jq '.devDependencies // {}')
      peer_dependencies=$(echo "$json_output" | jq '.peerDependencies // {}')
      resolutions=$(echo "$json_output" | jq '.resolutions // {}')
    else
      lock_deps=$(echo "$json_output" | jq '.dependencies // {}')
      packages=$(echo "$json_output" | jq '.packages // {}')
      v3_deps=$(echo "$packages" | jq -c 'to_entries
        | map(select(.key|startswith("node_modules/"))
            | {name: (.key|sub("^node_modules/";"")),
                version: (.value.version // .value.resolved // (if (.value|type)=="string" then .value else null end))}
          )
        | map(select(.version!=null))
        | map({(.name): .version})
        | add' 2>/dev/null || echo '{}')
      lock_deps_simple=$(echo "$lock_deps" | jq -c 'to_entries
        | map({(.key): (if (.value|type)=="object" then .value.version else .value end)})
        | add' 2>/dev/null || echo '{}')
      dependencies=$(jq -n --argjson a "$lock_deps_simple" --argjson b "$v3_deps" '$a + $b' 2>/dev/null || echo '{}')
      dev_dependencies='{}'
      peer_dependencies='{}'
      resolutions='{}'
    fi

    # Build per-file entry and append
    repo_file_entry=$(jq -n \
      --arg repo "$repo_name" \
      --arg file "$current_file" \
      --arg fileType "$file_type" \
      --arg branch "$default_branch" \
      --argjson dependencies "$dependencies" \
      --argjson devDependencies "$dev_dependencies" \
      --argjson peerDependencies "$peer_dependencies" \
      --argjson resolutions "$resolutions" \
      '{repository: $repo, file: $file, fileType: $fileType, branch: $branch, dependencies: $dependencies, devDependencies: $devDependencies, peerDependencies: $peerDependencies, resolutions: $resolutions}')

    if [[ -z "$all_dependencies" || "$all_dependencies" == "null" ]]; then
      all_dependencies='[]'
    fi
    all_dependencies=$(printf '%s\n%s\n' "$all_dependencies" "$repo_file_entry" | jq -s '.[0] + [ .[1] ]')
  }

  # Process directories with lockfiles first (preferred)
  for d in "${!has_lock[@]}"; do
    if [[ "$d" == "." ]]; then
      chosen="package-lock.json"
    else
      chosen="${d}/package-lock.json"
    fi
    # Skip if this path does not actually exist in this repo's tree
    [[ -n "${path_exists[$chosen]}" ]] || continue
    process_file "$chosen"
  done

  # Then process package.json files for directories that don't have a lockfile
  for d in "${!has_pkg[@]}"; do
    [[ -n "${has_lock[$d]}" ]] && continue
    if [[ "$d" == "." ]]; then
      chosen="package.json"
    else
      chosen="${d}/package.json"
    fi
    # Skip if this path does not actually exist in this repo's tree
    [[ -n "${path_exists[$chosen]}" ]] || continue
    process_file "$chosen"
  done

  

done <<< "$npm_repos"

all_dependencies=$(echo $all_dependencies | jq 'map(.dependencies? |= with_entries(select(.value != "workspace:*")) | .devDependencies? |= with_entries(select(.value != "workspace:*")) | .peerDependencies? |= with_entries(select(.value != "workspace:*")) | .resolutions? |= with_entries(select(.value != "workspace:*")) )')
echo $all_dependencies

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

# Attach file URL and file path to each generated document
documents=$(echo "$documents" | jq -c 'map(. + {file: (.repository as $r | .file), fileUrl: (.repository as $r | "https://github.com/" + .repository + "/blob/" + (.branch) + "/" + (.file))})')

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
