#!/bin/sh
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

max_days_away=$MAX_DAYS_AWAY
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

[[ "$renovate_repos" == "" ]] && echo "Error: cannot get renovate repositories." && exit 1

echo "Reshaping renovate PRs. Maximum of ${max_repos}"
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

[[ "$updatecli_repos" == "" ]] && echo "Error: cannot get updatecli repositories." && exit 1

# Reshape response
echo "Reshaping renovate PR. Maximum of ${max_repos}"

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
documents=()
idx=1

echo "Generate documents with verdicts for storage"

# Loop through merged documents and enhance each
while [ "$idx" -lt "$count" ]
do
  repository=$(echo "$repositories" | jq -r ".[$idx]")

  # The document id
  uuid=$(uuidgen)

  # Get document date as array
  document_date=$(get_value "$repository" '.createdAt')
  document_date=$(jq --arg document_date "$document_date" -n '$document_date | fromdate | strftime("%-y-%-m-%-e")')
  # Get current date as array
  current_date=$(jq -n 'now | strflocaltime("%-y-%-m-%-e")')

  # ---------------------------------------------------------------------------
  # Determine verdict
  # ---------------------------------------------------------------------------

  # if year or month is less than that of current
  doc_year=$(get_date_value "$document_date" "year")
  cur_year=$(get_date_value "$current_date" "year")
  # ----
  doc_month=$(get_date_value "$document_date" "month")
  cur_month=$(get_date_value "$current_date" "month")
  # ----
  doc_day=$(get_date_value "$document_date" "day")
  cur_day=$(get_date_value "$current_date" "day")
  # ----
  days_between=$((cur_day - doc_day)) # e.g. today is 15th pr was opened 10th, days btw is 5

  if [[ $doc_year -lt $cur_year || $doc_month -lt $cur_month ]]; then # created over 1 year or month ago
    verdict="upgrade"
    color_code="red"
  elif [[ $days_between -gt $max_days_away ]]; then # same month but more than acceptable number of days
    verdict="review"
    color_code="orange"
  else # same month and within acceptable number of days
    verdict="ok"
    color_code="green"
  fi

  # Enhance document with additional information
  document=$(echo "$repository" | jq --arg id "$uuid" \
    --arg verdict "$verdict" \
    --arg report_type "table" \
    --arg display_name "Open Renovate Pull Requests" \
    --arg color_code "$color_code" '. + {id: $id, displayName: $display_name, verdict: $verdict, colorCode: $color_code, reportType: $report_type}')

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
