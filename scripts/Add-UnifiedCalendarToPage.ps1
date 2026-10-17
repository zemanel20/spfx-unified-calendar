<#
.SYNOPSIS
    Adds the Unified calendar web part to a modern page with the settings you choose.

.DESCRIPTION
    Optional. The same can be done by hand: edit the page, add "Unified calendar"
    from the "Text, media, and content" group and use the property pane.
    The package must already be installed (see Install-UnifiedCalendar.ps1) and, for a
    site collection app catalog, installed on this site.

.PARAMETER SiteUrl
    Site that holds the page, e.g. https://contoso.sharepoint.com/sites/intranet.

.PARAMETER PageName
    Page file name in Site Pages, e.g. Home.aspx.

.PARAMETER ClientId
    Application (client) id of the Entra ID app used for PnP PowerShell interactive login.

.PARAMETER Section / Column
    Where to put the web part (1-based). A one-third column works well: the web part
    switches to its narrow layout on its own.

.PARAMETER Title
    Heading above the calendar. Empty string hides it.

.PARAMETER DefaultView
    dayGridMonth, timeGridWeek (default) or listWeek.

.PARAMETER VisibleDays
    Days of the week to show, 0 = Sunday ... 6 = Saturday. Default Monday to Friday.

.PARAMETER DayStartHour / DayEndHour
    Time axis of the week view, whole hours. Default 8 to 19.

.PARAMETER PlannerScope
    assigned (tasks assigned to the user, default) or myPlans (every task in the user's plans).

.PARAMETER ShowCompleted
    Completed Planner and To Do tasks visible by default. Default $true.

.EXAMPLE
    .\Add-UnifiedCalendarToPage.ps1 -SiteUrl https://contoso.sharepoint.com/sites/intranet -PageName Home.aspx -ClientId 00000000-0000-0000-0000-000000000000 -Section 2 -Column 2 -Title "My week"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $SiteUrl,
    [Parameter(Mandatory = $true)] [string] $PageName,
    [Parameter(Mandatory = $true)] [string] $ClientId,
    [int] $Section = 1,
    [int] $Column = 1,
    [string] $Title = 'My calendar',
    [ValidateSet('dayGridMonth', 'timeGridWeek', 'listWeek')] [string] $DefaultView = 'timeGridWeek',
    [int[]] $VisibleDays = @(1, 2, 3, 4, 5),
    [ValidateRange(0, 23)] [int] $DayStartHour = 8,
    [ValidateRange(1, 24)] [int] $DayEndHour = 19,
    [ValidateSet('assigned', 'myPlans')] [string] $PlannerScope = 'assigned',
    [bool] $ShowCompleted = $true
)

$ErrorActionPreference = 'Stop'

if ($DayEndHour -le $DayStartHour) {
    throw 'DayEndHour must be greater than DayStartHour.'
}

Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -Interactive

$properties = @{
    title         = $Title
    defaultView   = $DefaultView
    weekStartsOn  = 1
    visibleDays   = $VisibleDays
    dayStartHour  = $DayStartHour
    dayEndHour    = $DayEndHour
    showOutlook   = $true
    showPlanner   = $true
    showToDo      = $true
    plannerScope  = $PlannerScope
    showCompleted = $ShowCompleted
    daysToLoad    = 60
    useDemoData   = $false
}

Add-PnPPageWebPart -Page $PageName -Component 'Unified calendar' -Section $Section -Column $Column -WebPartProperties $properties | Out-Null
Set-PnPPage -Identity $PageName -Publish | Out-Null

Write-Host "Unified calendar added to $PageName (section $Section, column $Column) and the page was published."
