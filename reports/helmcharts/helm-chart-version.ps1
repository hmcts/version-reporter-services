# Define environment variables
$cluster_name = $env:CLUSTER_NAME
$environment = $env:ENVIRONMENT
$max_versions_away = $env:MAX_VERSIONS_AWAY

# Covnert to JSON String
function Get-Value {
    param (
        [string]$Json,
        [string]$Key
    )
    $object = $Json | ConvertFrom-Json
    return $object.$Key
}
function get_major_Version {
    param (
        [string]$version 
    )
    $splitVersion = $version.Split('.')
    return $splitVersion[0]
}
function get_minor_version {
    param (
        [string]$version
    )
    $splitVersion = $version.Split('.')
    return $splitVersion[1]
}

$document = "This is the document content or a file path"
& python3 ./save-to-cosmos.py $document

Write-Output "Job process start"

# Get helm repo
$result = kubectl get helmrepositories -A -o json | ConvertFrom-Json
# Filter based on namespace properties
$filteredRepos = $result.items | Where-Object {
    $_.metadata.namespace -in @('admin', 'monitoring', 'flux-system', 'keda', 'kured', 'dynatrace', 'neuvector-crds', 'pact-broker')
} | ForEach-Object {
    [PSCustomObject]@{
        name = $_.metadata.name
        url = $_.spec.url
        namespace = $_.metadata.namespace
    }
}
# Convert list back to JSON
$result = $filteredRepos | ConvertTo-Json

helm repo update

$charts = helm whatup -A -q -o json | ConvertFrom-Json
# Filter based on namespace properties
$filteredReleases = $releases.releases | Where-Object {
    $_.namespace -in @('admin', 'monitoring', 'flux-system', 'keda', 'kured', 'dynatrace', 'neuvector-crds', 'pact-broker')
} | ForEach-Object {
    [PSCustomObject]@{
        chart = $_.name
        namespace = $_.namespace
        installed = $_.installed_version
        latest = $_.latest_version
        appVersion = $_.app_version
        newestRepo = $_.newest_repo
        updated = $_.updated
        deprecated = $_.deprecated
    }
}
# Convert list back to JSON
$charts = $filteredReleases | ConvertTo-Json

if (-not $charts) {
    Write-Host "Error: helm whatup failed."
    exit 1
}

Write-Host "$($charts.Count) charts in total to be processed"

$documents = @()
# Iterate through results and determine chart verdict
$charts | ConvertFrom-Json | ForEach-Object {
    $chart = $_
    $latest = Get-Value $chart 'latest'
    $installed = Get-Value $chart 'installed'

    $latest_major = get_major_Version $latest
    $installed_major = get_major_Version $installed

    $latest_minor = get_minor_version $latest
    $installed_minor = get_minor_version $installed
    $minor_distance = $latest_minor - $installed_minor

    if ($latest_major -gt $installed_major) {
        $verdict = "upgrade"
        $color_code = "red"
    }
    elseif ($minor_distance -gt $max_versions_away) {
        $verdict = "review"
        $color_code = "orange"
    }
    else {
        $verdict = "ok"
        $color_code = "green"
    }
}

cosmosdb_account_name=$COSMOSDB_ACCOUNT_NAME
cosmosdb_database_name=$COSMOS_DB_NAME
cosmosdb_container_name=$COSMOS_DB_CONTAINER
id_to_check=$id
new_verdict="approved"

$charts | ConvertFrom-Json | ForEach-Object {
    $helm_chart_name = $_.name
    $created_on = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $id = "${cluster_name}-$helm_chart_name"
}

$chartObject = $chart | ConvertFrom-Json
$chartObject.cluster = $cluster_name
$chartObject.verdict = $verdict
$chartObject.id = $id
$chartObject.environment = $environment
$chartObject.createdOn = $created_on
$chartObject.reportType = "table"
$chartObject.displayName = "HELM Repositories"
$chartObject.colorCode = $color_code

$document = $chartObject | ConvertTo-Json

//need to fix this
# $query_result = az cosmosdb sql query `
#   --account-name $env:cosmosdb_account_name `
#   --database-name $env:cosmosdb_database_name `
#   --container-name $env:cosmosdb_container_name `
#   --query "SELECT * FROM c WHERE c.id = '$($env:id)'" `
#   --output json

    if ($query_result -eq "[]") {
        store_document $document
        Write-Host "Document stored successfully."
    }
    else {
        $existing_verdict = ($query_result | ConvertFrom-Json | Select-Object -ExpandProperty verdict)

        if ($existing_verdict -ne $new_verdict) {
            Write-Host "Updating document with ID $id due to verdict change."
        }
        else {
            Write-Host "Document with ID $id already exists with the same verdict."
        }
    }
    Write-Host "Job process completed"

    # ---------------------------------------------------------------------------
    # STEP 3:
    # Store document
    # ---------------------------------------------------------------------------
    $documentsJson = $documents | ConvertTo-Json -Compress
    Store-Document $documentsJson

    Write-Host "Job process completed"