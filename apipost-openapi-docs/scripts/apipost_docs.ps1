param(
    [Parameter(Mandatory = $true)]
    [string]$SpecPath,

    [ValidateSet("summary", "operations", "documents", "request")]
    [string]$Action = "operations",

    [string]$OperationId,
    [string]$Method,
    [string]$Path,
    [string]$BodyPath,
    [string]$PathParamsJson,
    [string]$QueryJson,
    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $OutputEncoding

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "File is empty: $Path"
    }
    return $raw | ConvertFrom-Json
}

function Convert-JsonObjectToHashtable {
    param($Value)
    $result = @{}
    if ($null -eq $Value) {
        return $result
    }
    foreach ($property in $Value.PSObject.Properties) {
        $result[$property.Name] = $property.Value
    }
    return $result
}

function Get-Operations {
    param($Spec)
    $items = @()
    $httpMethods = @("get", "post", "put", "patch", "delete", "head", "options")
    foreach ($pathProperty in $Spec.paths.PSObject.Properties) {
        $apiPath = $pathProperty.Name
        foreach ($methodProperty in $pathProperty.Value.PSObject.Properties) {
            $methodName = $methodProperty.Name.ToLowerInvariant()
            if ($httpMethods -notcontains $methodName) {
                continue
            }
            $operation = $methodProperty.Value
            $tagText = ""
            if ($operation.PSObject.Properties.Name -contains "tags") {
                $tagText = ($operation.tags -join ",")
            }
            $items += [pscustomobject]@{
                method = $methodName.ToUpperInvariant()
                path = $apiPath
                operationId = if ($operation.PSObject.Properties.Name -contains "operationId") { $operation.operationId } else { "" }
                summary = if ($operation.PSObject.Properties.Name -contains "summary") { $operation.summary } else { "" }
                tags = $tagText
            }
        }
    }
    return $items
}

function Get-Documents {
    param($Spec)
    $items = @()
    $httpMethods = @("get", "post", "put", "patch", "delete", "head", "options")
    foreach ($pathProperty in $Spec.paths.PSObject.Properties) {
        $apiPath = $pathProperty.Name
        foreach ($methodProperty in $pathProperty.Value.PSObject.Properties) {
            $methodName = $methodProperty.Name.ToLowerInvariant()
            if ($httpMethods -contains $methodName) {
                continue
            }
            $doc = $methodProperty.Value
            if (($doc.PSObject.Properties.Name -contains "x-protocol") -and $doc."x-protocol" -eq "doc") {
                $items += [pscustomobject]@{
                    path = $apiPath
                    key = $methodProperty.Name
                    targetId = if ($doc.PSObject.Properties.Name -contains "x-target-id") { $doc."x-target-id" } else { "" }
                    summary = if ($doc.PSObject.Properties.Name -contains "summary") { $doc.summary } else { "" }
                    tags = if ($doc.PSObject.Properties.Name -contains "tags") { ($doc.tags -join ",") } else { "" }
                    updatedAt = if ($doc.PSObject.Properties.Name -contains "x-updated-at") { $doc."x-updated-at" } else { "" }
                }
            }
        }
    }
    return $items
}

function Get-SpecSummary {
    param($Spec)
    $operations = @(Get-Operations -Spec $Spec)
    $documents = @(Get-Documents -Spec $Spec)
    $pathCount = @($Spec.paths.PSObject.Properties).Count
    $tagCount = 0
    if ($Spec.PSObject.Properties.Name -contains "tags") {
        $tagCount = @($Spec.tags).Count
    }
    $serverText = ""
    if ($Spec.PSObject.Properties.Name -contains "servers") {
        $serverText = (($Spec.servers | ForEach-Object { $_.url }) -join ", ")
    }
    return [pscustomobject]@{
        title = $Spec.info.title
        projectId = $Spec.info."x-project-id"
        openapi = $Spec.openapi
        paths = $pathCount
        tags = $tagCount
        httpOperations = $operations.Count
        markdownDocs = $documents.Count
        servers = $serverText
    }
}

function Find-Operation {
    param($Spec, [string]$OperationId, [string]$Method, [string]$Path)
    $httpMethods = @("get", "post", "put", "patch", "delete", "head", "options")
    foreach ($pathProperty in $Spec.paths.PSObject.Properties) {
        $apiPath = $pathProperty.Name
        foreach ($methodProperty in $pathProperty.Value.PSObject.Properties) {
            $methodName = $methodProperty.Name.ToLowerInvariant()
            if ($httpMethods -notcontains $methodName) {
                continue
            }
            $operation = $methodProperty.Value
            $currentOperationId = ""
            if ($operation.PSObject.Properties.Name -contains "operationId") {
                $currentOperationId = [string]$operation.operationId
            }
            if ($OperationId -and $currentOperationId -eq $OperationId) {
                return [pscustomobject]@{ method = $methodName; path = $apiPath; operation = $operation }
            }
            if ($Method -and $Path -and $methodName -eq $Method.ToLowerInvariant() -and $apiPath -eq $Path) {
                return [pscustomobject]@{ method = $methodName; path = $apiPath; operation = $operation }
            }
        }
    }
    throw "Operation not found. Provide -OperationId, or both -Method and -Path."
}

function Get-BaseUrl {
    param($Spec)
    if ($env:APIPOST_BASE_URL) {
        return $env:APIPOST_BASE_URL.TrimEnd("/")
    }
    if (($Spec.PSObject.Properties.Name -contains "servers") -and $Spec.servers.Count -gt 0) {
        return ([string]$Spec.servers[0].url).TrimEnd("/")
    }
    throw "No base URL found. Set APIPOST_BASE_URL or include servers[0].url in the spec."
}

function Apply-PathParams {
    param([string]$Template, [hashtable]$Params)
    $result = $Template
    $envIds = @{
        "project_id" = $env:APIPOST_PROJECT_ID
        "projectId" = $env:APIPOST_PROJECT_ID
        "team_id" = $env:APIPOST_TEAM_ID
        "teamId" = $env:APIPOST_TEAM_ID
    }
    foreach ($key in $envIds.Keys) {
        if ($envIds[$key] -and -not $Params.ContainsKey($key)) {
            $Params[$key] = $envIds[$key]
        }
    }
    foreach ($key in $Params.Keys) {
        $escaped = [System.Uri]::EscapeDataString([string]$Params[$key])
        $result = $result.Replace("{$key}", $escaped)
    }
    if ($result -match "\{[^}]+\}") {
        throw "Unresolved path parameter in: $result"
    }
    return $result
}

function Add-QueryString {
    param([string]$Url, [hashtable]$Query)
    if ($Query.Count -eq 0) {
        return $Url
    }
    $pairs = @()
    foreach ($key in $Query.Keys) {
        if ($null -eq $Query[$key]) {
            continue
        }
        $pairs += ([System.Uri]::EscapeDataString([string]$key) + "=" + [System.Uri]::EscapeDataString([string]$Query[$key]))
    }
    if ($pairs.Count -eq 0) {
        return $Url
    }
    $separator = if ($Url.Contains("?")) { "&" } else { "?" }
    return $Url + $separator + ($pairs -join "&")
}

function Get-AuthHeaders {
    $headers = @{
        "Accept" = "application/json"
        "Content-Type" = "application/json"
    }
    if ($env:APIPOST_TOKEN) {
        $headerName = if ($env:APIPOST_TOKEN_HEADER) { $env:APIPOST_TOKEN_HEADER } else { "Api-Token" }
        $prefix = if ($null -ne $env:APIPOST_TOKEN_PREFIX) { $env:APIPOST_TOKEN_PREFIX } else { "" }
        $headers[$headerName] = if ([string]::IsNullOrWhiteSpace($prefix)) { $env:APIPOST_TOKEN } else { "$prefix $env:APIPOST_TOKEN" }
    }
    return $headers
}

$spec = Read-JsonFile -Path $SpecPath

if ($Action -eq "summary") {
    Get-SpecSummary -Spec $spec | Format-List
    exit 0
}

if ($Action -eq "operations") {
    Get-Operations -Spec $spec | Sort-Object path, method | Format-Table -AutoSize
    exit 0
}

if ($Action -eq "documents") {
    Get-Documents -Spec $spec | Sort-Object tags, summary | Format-Table -AutoSize
    exit 0
}

$found = Find-Operation -Spec $spec -OperationId $OperationId -Method $Method -Path $Path
$pathParams = @{}
if ($PathParamsJson) {
    $pathParams = Convert-JsonObjectToHashtable -Value ($PathParamsJson | ConvertFrom-Json)
}
$query = @{}
if ($QueryJson) {
    $query = Convert-JsonObjectToHashtable -Value ($QueryJson | ConvertFrom-Json)
}

$relativePath = Apply-PathParams -Template $found.path -Params $pathParams
$url = (Get-BaseUrl -Spec $spec) + $relativePath
$url = Add-QueryString -Url $url -Query $query
$headers = Get-AuthHeaders

$body = $null
if ($BodyPath) {
    $body = Get-Content -LiteralPath $BodyPath -Raw
}

$redactedHeaders = @{}
foreach ($key in $headers.Keys) {
    $redactedHeaders[$key] = if ($key -eq "Authorization" -or $key -match "token|key|secret") { "***" } else { $headers[$key] }
}

Write-Host "Method: $($found.method.ToUpperInvariant())"
Write-Host "URL: $url"
Write-Host "Headers:"
$redactedHeaders.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host "  $($_.Key): $($_.Value)" }
if ($body) {
    Write-Host "Body:"
    Write-Host $body
}

if (-not $Execute) {
    Write-Host "Dry run only. Add -Execute to send the request."
    exit 0
}

$invokeParams = @{
    Method = $found.method.ToUpperInvariant()
    Uri = $url
    Headers = $headers
}
if ($body) {
    $invokeParams["Body"] = $body
}

$response = Invoke-RestMethod @invokeParams
$response | ConvertTo-Json -Depth 100
