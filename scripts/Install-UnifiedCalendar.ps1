<#
.SYNOPSIS
    Installs the Unified calendar web part in a SharePoint Online app catalog and
    approves the Microsoft Graph permissions it needs.

.DESCRIPTION
    Uploads package/spfx-unified-calendar.sppkg to the tenant app catalog (default)
    or to a site collection app catalog, publishes it, and then tries to approve the
    two delegated Graph permissions the package requests (Calendars.Read, Tasks.Read).

    Requires PnP PowerShell 2.x or 3.x (Install-Module PnP.PowerShell) and an Entra ID
    app registration for the interactive login, which PnP PowerShell 3 needs:
        Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP PowerShell" -Tenant contoso.onmicrosoft.com
    Run it as a SharePoint Administrator. Approving API permissions needs a Global
    Administrator or a SharePoint Administrator with the right consent; when the
    approval fails, the script tells you where to do it in the SharePoint admin center.

.PARAMETER AppCatalogUrl
    Tenant app catalog, e.g. https://contoso.sharepoint.com/sites/appcatalog, or the
    site collection that has its own app catalog when -Scope Site is used.

.PARAMETER ClientId
    Application (client) id of the Entra ID app used for PnP PowerShell interactive login.

.PARAMETER Scope
    Tenant (default) or Site.

.PARAMETER PackagePath
    Path to the .sppkg. Defaults to ../package/spfx-unified-calendar.sppkg next to this script.

.PARAMETER SkipPermissionApproval
    Upload and publish only; approve the Graph permissions yourself afterwards.

.EXAMPLE
    .\Install-UnifiedCalendar.ps1 -AppCatalogUrl https://contoso.sharepoint.com/sites/appcatalog -ClientId 00000000-0000-0000-0000-000000000000

.EXAMPLE
    .\Install-UnifiedCalendar.ps1 -AppCatalogUrl https://contoso.sharepoint.com/sites/intranet -Scope Site -ClientId 00000000-0000-0000-0000-000000000000
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $AppCatalogUrl,
    [Parameter(Mandatory = $true)] [string] $ClientId,
    [ValidateSet('Tenant', 'Site')] [string] $Scope = 'Tenant',
    [string] $PackagePath = (Join-Path $PSScriptRoot '..\package\spfx-unified-calendar.sppkg'),
    [switch] $SkipPermissionApproval
)

$ErrorActionPreference = 'Stop'
$packageName = 'spfx-unified-calendar'

if (-not (Test-Path $PackagePath)) {
    throw "Package not found: $PackagePath"
}

Write-Host "Connecting to $AppCatalogUrl ..."
Connect-PnPOnline -Url $AppCatalogUrl -ClientId $ClientId -Interactive

Write-Host "Uploading and publishing $packageName ($Scope app catalog) ..."
$app = Add-PnPApp -Path $PackagePath -Scope $Scope -Publish -Overwrite -SkipFeatureDeployment
Write-Host "Published: $($app.Title) $($app.AppCatalogVersion) (deployed: $($app.Deployed))"

if ($SkipPermissionApproval) {
    Write-Host 'Skipping permission approval as requested.'
    return
}

# Permission requests live at tenant level whatever the catalog scope.
$adminUrl = ([uri]$AppCatalogUrl).Host -replace '\.sharepoint\.com$', '-admin.sharepoint.com'
$adminUrl = "https://$adminUrl"

try {
    Write-Host "Connecting to $adminUrl to approve the Graph permissions ..."
    Connect-PnPOnline -Url $adminUrl -ClientId $ClientId -Interactive
    $pending = Get-PnPTenantServicePrincipalPermissionRequests |
        Where-Object { $_.PackageName -eq $packageName -and $_.Resource -eq 'Microsoft Graph' }

    if (-not $pending) {
        Write-Host 'No pending requests for this package. They may already be approved (check API access in the SharePoint admin center).'
    }
    foreach ($request in $pending) {
        Approve-PnPTenantServicePrincipalPermissionRequest -RequestId $request.Id -Force | Out-Null
        Write-Host "Approved: Microsoft Graph / $($request.Scope)"
    }
}
catch {
    Write-Warning "Could not approve the permissions automatically: $($_.Exception.Message)"
    Write-Warning 'Approve them in the SharePoint admin center: Advanced > API access > Pending requests > spfx-unified-calendar (Calendars.Read, Tasks.Read).'
}

Write-Host 'Done. Add the "Unified calendar" web part to a modern page, or run Add-UnifiedCalendarToPage.ps1.'
