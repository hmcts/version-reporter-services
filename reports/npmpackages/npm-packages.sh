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
# exec > output/output.txt 2>&1
# set -x

if [ -z $GH_TOKEN ]; then
  echo "No GitHub token set. Exiting..."
  exit 1
fi

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
npm_repos=$(gh api -H "Accept: application/vnd.github+json" /orgs/hmcts/repos --paginate --jq '.[] | {name: .name, default_branch: .default_branch}' | jq -c '.' | sort -u)
npm_repos=$(echo "$npm_repos" | sort -u)

[[ "$npm_repos" == "" ]] && echo "Job process existed: Cannot get npm repositories." && exit 0

# Parallelism settings: change PARALLELISM to tune concurrency
PARALLELISM=${PARALLELISM:-4}
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

all_dependencies='[]'

process_repo() {
  npm_repo="$1"
  [[ -z "$npm_repo" ]] && return
  repo_name=$(jq -r '.name' <<< "$npm_repo")
  default_branch=$(jq -r '.default_branch' <<< "$npm_repo")
  out_file="$tmpdir/${repo_name}.json"
  
  echo "Processing $repo_name on branch $default_branch"

  filepaths=$(curl -sS -H "Authorization: bearer $GH_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Accept: application/vnd.github+json" \
    -w "\n%{http_code}" \
    "https://api.github.com/repos/hmcts/${repo_name}/git/trees/$default_branch?recursive=true") 
    
  status_code=$(printf '%s' "$filepaths" | tail -n1)
  
  if [[ "$status_code" != "200" ]]; then
    echo "Skipping $repo_name: HTTP status $status_code"
    echo '[]' > "$out_file"
    return
  fi
  
  body=$(printf '%s' "$filepaths" | sed '$d' | jq -r '.tree[].path | select(test("(^|/)package(-lock)?\\.json$") and (test("(^|/)node_modules(/|$)") | not))')

  # Convert filepaths to array
  readarray -t filepaths_array <<< "$body"
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

    if [[ -z "$per_repo_deps" || "$per_repo_deps" == "null" ]]; then
      per_repo_deps='[]'
    fi
    per_repo_deps=$(printf '%s\n%s\n' "$per_repo_deps" "$repo_file_entry" | jq -s '.[0] + [ .[1] ]')
  }

  # Initialize per-repo dependencies
  per_repo_deps='[]'
  
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

  # Write per-repo results to temp file
  echo "$per_repo_deps" > "$out_file"
}

# Run repos in parallel with a semaphore
sem() { local max=$1; shift; while (( $(jobs -rp | wc -l) >= max )); do sleep 0.1; done; }

while IFS= read -r npm_repo; do
  [[ -z "$npm_repo" ]] && continue
  sem "$PARALLELISM"
  ( process_repo "$npm_repo" ) &
done <<< "$npm_repos"

# Wait for all background jobs to finish
wait

# Aggregate per-repo files into all_dependencies
all_dependencies='[]'
for f in "$tmpdir"/*.json; do
  [[ ! -f "$f" ]] && continue
  repo_json=$(cat "$f")
  all_dependencies=$(printf '%s\n%s\n' "$all_dependencies" "$repo_json" | jq -s '.[0] + .[1]')
done

all_dependencies=$(echo "$all_dependencies" | jq 'map(
  .dependencies = (.dependencies // {} | with_entries(select(.value != "workspace:*")))
  | .devDependencies = (.devDependencies // {} | with_entries(select(.value != "workspace:*")))
  | .peerDependencies = (.peerDependencies // {} | with_entries(select(.value != "workspace:*")))
  | .resolutions = (.resolutions // {} | with_entries(select(.value != "workspace:*")))
)')
echo $all_dependencies

# ---------------------------------------------------------------------------
# Process Results
# ---------------------------------------------------------------------------

echo "Transforming to per-package documents"

# Build one document per package per repo (dependencies + devDependencies + peerDependencies)
documents=$(echo "$all_dependencies" | jq -c '
  map(
    ( .repository as $repo | .file as $file | .branch as $branch |
      (
      ( .dependencies // {} | to_entries | map(
      ( .value as $val |
        [ {repository: $repo, file: $file, branch: $branch, package: .key, version: (if ($val | type)=="object" then $val.version else $val end), dependencyType: (if (($val|type)=="object" and ($val.dev==true)) then "devDependency" else "dependency" end)} ]
        + ( if (($val|type)=="object" and ($val.requires?!=null)) then
        ( $val.requires | to_entries | map({repository: $repo, file: $file, branch: $branch, package: .key, version: .value, dependencyType: (if ($val.dev==true) then "transitiveDevDependency" else "transitiveDependency" end)}) )
        else [] end )
      )
      ) | add ) +
      ( .devDependencies // {} | to_entries | map(
      ( .value as $val |
        [ {repository: $repo, file: $file, branch: $branch, package: .key, version: (if ($val | type)=="object" then $val.version else $val end), dependencyType: "devDependency"} ]
        + ( if (($val|type)=="object" and ($val.requires?!=null)) then
        ( $val.requires | to_entries | map({repository: $repo, file: $file, branch: $branch, package: .key, version: .value, dependencyType: "transitiveDevDependency"}) )
        else [] end )
      )
      ) | add ) +
      ( .peerDependencies // {} | to_entries | map(
      ( .value as $val |
        [ {repository: $repo, file: $file, branch: $branch, package: .key, version: (if ($val | type)=="object" then $val.version else $val end), dependencyType: "peerDependency"} ]
        + ( if (($val|type)=="object" and ($val.requires?!=null)) then
        ( $val.requires | to_entries | map({repository: $repo, file: $file, branch: $branch, package: .key, version: .value, dependencyType: "transitivePeerDependency"}) )
        else [] end )
      )
      ) | add ) +
      ( .resolutions // {} | to_entries | map(
      ( .value as $val |
        [ {repository: $repo, file: $file, branch: $branch, package: .key, version: (if ($val | type)=="object" then $val.version else $val end), dependencyType: "resolution"} ]
        + ( if (($val|type)=="object" and ($val.requires?!=null)) then
        ( $val.requires | to_entries | map({repository: $repo, file: $file, branch: $branch, package: .key, version: .value, dependencyType: "transitiveDevDependency"}) )
        else [] end )
      )
      ) | add )
      )
    )
  ) | add // []
')

# Add a UUID per item
echo "Adding UUID to each item"
documents=$(echo "${documents:-[]}" | jq -c '(. // []) | map( .file = (.file // "") | .branch = (.branch // "main") | .fileUrl = ("https://github.com/hmcts/" + .repository + "/blob/" + .branch + "/" + .file) )')


# ---------------------------------------------------------------------------
# Store results to database
# ---------------------------------------------------------------------------

# Pass documents to python for database storage
echo "Send documents for storage"
store_documents "$documents"

echo "Job process completed"
