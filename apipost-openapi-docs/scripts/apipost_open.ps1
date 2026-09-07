param(
    [ValidateSet("list", "detail", "delete", "raw")]
    [string]$Action = "list",

    [string]$HostUrl,
    [string]$Token,
    [string]$ProjectId,
    [string[]]$TargetIds,
    [string]$Endpoint,
    [string]$BodyPath,
    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $OutputEncoding

function Get-RequiredValue {
    param([string]$Name, [string]$Value, [string]$EnvName)
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }
    $envValue = [Environment]::GetEnvironmentVariable($EnvName)
    if (-not [string]::IsNullOrWhiteSpace($envValue)) {
        return $envValue
    }
    throw "Missing $Name. Pass -$Name or set $EnvName."
}

function Read-Body {
    param([string]$Path, $Fallback)
    if ($Path) {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    }
    return ($Fallback | ConvertTo-Json -Depth 100)
}

function Resolve-TargetIds {
    param([string[]]$Ids)

    return @($Ids |
        ForEach-Object { [string]$_ -split "," } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" })
}

$resolvedHost = Get-RequiredValue -Name "HostUrl" -Value $HostUrl -EnvName "APIPOST_HOST"
$resolvedToken = Get-RequiredValue -Name "Token" -Value $Token -EnvName "APIPOST_TOKEN"
$resolvedHost = $resolvedHost.TrimEnd("/")

$method = "POST"
$path = ""
$payload = @{}

switch ($Action) {
    "list" {
        $resolvedProjectId = Get-RequiredValue -Name "ProjectId" -Value $ProjectId -EnvName "APIPOST_PROJECT_ID"
        $path = "/open/apis/list"
        $payload = @{ project_id = $resolvedProjectId }
    }
    "detail" {
        $resolvedProjectId = Get-RequiredValue -Name "ProjectId" -Value $ProjectId -EnvName "APIPOST_PROJECT_ID"
        $resolvedTargetIds = Resolve-TargetIds -Ids $TargetIds
        if (-not $resolvedTargetIds -or $resolvedTargetIds.Count -eq 0) {
            throw "Missing TargetIds. Pass -TargetIds id1,id2."
        }
        $path = "/open/apis/details"
        $payload = @{ project_id = $resolvedProjectId; target_ids = $resolvedTargetIds }
    }
    "delete" {
        $resolvedProjectId = Get-RequiredValue -Name "ProjectId" -Value $ProjectId -EnvName "APIPOST_PROJECT_ID"
        $resolvedTargetIds = Resolve-TargetIds -Ids $TargetIds
        if (-not $resolvedTargetIds -or $resolvedTargetIds.Count -eq 0) {
            throw "Missing TargetIds. Pass -TargetIds id1,id2."
        }
        $path = "/open/apis/delete"
        $payload = @{ project_id = $resolvedProjectId; target_ids = $resolvedTargetIds }
    }
    "raw" {
        if (-not $Endpoint) {
            throw "Missing Endpoint for raw action."
        }
        $path = if ($Endpoint.StartsWith("/")) { $Endpoint } else { "/" + $Endpoint }
    }
}

$url = $resolvedHost + $path
$body = Read-Body -Path $BodyPath -Fallback $payload

Write-Host "Method: $method"
Write-Host "URL: $url"
Write-Host "Headers:"
Write-Host "  Api-Token: ***"
Write-Host "  Content-Type: application/json"
Write-Host "Body:"
Write-Host $body

if (-not $Execute) {
    Write-Host "Dry run only. Add -Execute to send the request."
    exit 0
}

$headers = @{
    "Api-Token" = $resolvedToken
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

$response = Invoke-RestMethod -Method $method -Uri $url -Headers $headers -Body $body
$response | ConvertTo-Json -Depth 100
