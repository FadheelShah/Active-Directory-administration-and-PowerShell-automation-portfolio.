
# ============================================================
# Project: Veeam Agent Backup Monitoring
# Script: Monitoring-Script.ps1
# Purpose: Check the latest Veeam backup job result
# Environment: Windows Server 2022 / PowerShell 5.1
# ============================================================

param(
    [switch]$NoBrowser
)

# ------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------

# Name of the Veeam backup job we want to monitor.
$JobName = "Lab-File-Backup"

# Windows Event Log used by Veeam Agent.
$LogName = "Veeam Agent"

# Event ID 190 represents a backup job completion
# in our current Veeam Agent environment.
$CompletionEventID = 190

# Maximum acceptable age of the last successful backup.
$MaxBackupAgeHours = 24

# ------------------------------------------------------------
# HTML report configuration
# ------------------------------------------------------------

# Create the Reports folder if it doesn't exist
$ReportsFolder = Join-Path $PSScriptRoot "Reports"

if (-not (Test-Path $ReportsFolder)) {
    New-Item -Path $ReportsFolder -ItemType Directory -Force | Out-Null
}

# Generate a unique timestamp for each report
$Timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"

# Save the HTML report inside the Reports folder
$ReportPath = Join-Path $ReportsFolder "Backup-Report-$Timestamp.html"

# Open the generated report in the default browser.
$OpenReport = -Not $NoBrowser

# ------------------------------------------------------------
# 2. Retrieve the latest backup completion event
# ------------------------------------------------------------

# Get-WinEvent reads events from Windows Event Logs.
# FilterHashtable limits the search to the Veeam log
# and the completion event ID.
#
# Where-Object ensures we only retrieve events for
# the backup job specified above.
#
# Select-Object -First 1 returns the newest matching event.

$LatestBackup = $null
$EventLogReadFailed = $false

try {

    $LatestBackup = Get-WinEvent -FilterHashtable @{
        LogName = $LogName
        Id      = $CompletionEventID
    } -ErrorAction Stop |
    Where-Object {
        $_.Message -like "*Veeam Agent '$JobName' finished*"
    } |
    Select-Object -First 1

}
catch {

    $EventLogReadFailed = $true

    Write-Host "ERROR: Unable to read Veeam Event Log." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    # Continue so monitoring can report UNKNOWN.
    $LatestBackup = $null
}

# ------------------------------------------------------------
# 3. Check whether a backup completion event exists
# ------------------------------------------------------------

# $null means no matching completion event was found.
# This could happen if the backup has never completed,
# the log was cleared, or the job name is incorrect.

if ($null -eq $LatestBackup) {

    Write-Host "WARNING: No completed backup found for $JobName" `
        -ForegroundColor Yellow

    $BackupStatus = "UNKNOWN"
    $OverallStatus = "UNKNOWN"
}


# ------------------------------------------------------------
# 3.1 Find the last successful backup
# ------------------------------------------------------------

# Search Veeam completion events for our specific job.
# Only events reporting "Success" qualify.
$LastSuccessfulBackup = $null

if (-not $EventLogReadFailed) {

    try {

        $LastSuccessfulBackup = Get-WinEvent -FilterHashtable @{
            LogName = $LogName
            Id      = $CompletionEventID
        } -ErrorAction Stop |
        Where-Object {
            $_.Message -like "*Veeam Agent '$JobName' finished with Success*"
        } |
        Select-Object -First 1

    }
    catch {

    if ($_.FullyQualifiedErrorId -like "NoMatchingEventsFound*") {

        Write-Host "WARNING: No Veeam completion events found." `
            -ForegroundColor Yellow

    }
    else {

        $EventLogReadFailed = $true

        Write-Host "ERROR: Unable to retrieve the last successful backup." `
            -ForegroundColor Red

        Write-Host $_.Exception.Message
    }

    $LastSuccessfulBackup = $null
        }
    
    
    }


# Check whether a successful backup was found.
if ($null -eq $LastSuccessfulBackup) {

    Write-Host "WARNING: No successful backup found." -ForegroundColor Yellow

}



# ------------------------------------------------------------
# 4. Display backup information
# ------------------------------------------------------------

Write-Host "========================================"
Write-Host "        VEEAM BACKUP MONITOR"
Write-Host "========================================"

Write-Host "Job Name : $JobName"
Write-Host "Last Run : $($LatestBackup.TimeCreated)"
Write-Host "Event ID : $($LatestBackup.Id)"


# ------------------------------------------------------------
# 5. Determine the backup result
# ------------------------------------------------------------

if ($null -eq $LatestBackup) {

    Write-Host "Status   : UNKNOWN" -ForegroundColor Yellow

}
elseif ($LatestBackup.Message -match "finished with Success") {

    Write-Host "Status   : SUCCESS" -ForegroundColor Green

}
elseif ($LatestBackup.Message -match "finished with Warning") {

    Write-Host "Status   : WARNING" -ForegroundColor Yellow

}
elseif ($LatestBackup.Message -match "finished with Failed") {

    Write-Host "Status   : FAILED" -ForegroundColor Red

    if ($LatestBackup.Message -match "Error:\s*(.+)") {

        $FailureReason = $Matches[1].Trim()

        Write-Host "Reason   : $FailureReason" -ForegroundColor Red

    }
    else {

        Write-Host "Reason   : No detailed error provided"

    }

}
else {

    Write-Host "Status   : UNKNOWN" -ForegroundColor Yellow

}


# ------------------------------------------------------------
# 6. Check backup freshness
# ------------------------------------------------------------

# Check whether a successful backup exists before
# attempting to calculate its age.
if ($null -ne $LastSuccessfulBackup) {

    # Get the current system date and time.
    $CurrentTime = Get-Date

    # Calculate how much time has passed since
    # the last SUCCESSFUL backup.
    $BackupAge = $CurrentTime - $LastSuccessfulBackup.TimeCreated

    # Convert the elapsed time into hours.
    $BackupAgeHours = [math]::Round($BackupAge.TotalHours, 2)

    # Display the last successful backup information.
    Write-Host "Last Success : $($LastSuccessfulBackup.TimeCreated)"
    Write-Host "Backup Age   : $BackupAgeHours hours"

    # Compare backup age with the configured threshold.
    if ($BackupAge.TotalHours -gt $MaxBackupAgeHours) {

        Write-Host "Freshness    : STALE" -ForegroundColor Red
        Write-Host "WARNING: Last successful backup is older than $MaxBackupAgeHours hours."

    }
    else {

        Write-Host "Freshness    : CURRENT" -ForegroundColor Green

    }

}
else {

    # No successful backup was found in the event log.
    # Therefore, freshness cannot be calculated.
    Write-Host "Last Success : Not found"
    Write-Host "Freshness    : UNKNOWN" -ForegroundColor Yellow

}


# ------------------------------------------------------------
# 7. Determine overall backup health
# ------------------------------------------------------------

$OverallStatus = "UNKNOWN"

$LatestJobSucceeded = $false
$SuccessfulBackupIsCurrent = $false

# Check the latest completed backup.
if ($null -ne $LatestBackup) {

    if ($LatestBackup.Message -match "finished with Success") {
        $LatestJobSucceeded = $true
    }

    # A known failed, warning, or stale backup is unhealthy.
    $OverallStatus = "UNHEALTHY"
}

# Check whether a successful backup is recent.
if ($null -ne $LastSuccessfulBackup) {

    $SuccessfulBackupAge = (Get-Date) -
        $LastSuccessfulBackup.TimeCreated

    if ($SuccessfulBackupAge.TotalHours -ge 0 -and
        $SuccessfulBackupAge.TotalHours -le $MaxBackupAgeHours) {

        $SuccessfulBackupIsCurrent = $true
    }
}

# Healthy only when both conditions are satisfied
# and the event log was read successfully.
if ($EventLogReadFailed) {

    $OverallStatus = "UNKNOWN"

}
elseif ($LatestJobSucceeded -and $SuccessfulBackupIsCurrent) {

    $OverallStatus = "HEALTHY"

}

# ------------------------------------------------------------
# 8. Display overall monitoring result
# ------------------------------------------------------------

Write-Host "----------------------------------------"

switch ($OverallStatus) {

    "HEALTHY" {
        Write-Host "Overall Status : HEALTHY" -ForegroundColor Green
        $ExitCode = 0
    }

    "UNHEALTHY" {
        Write-Host "Overall Status : UNHEALTHY" -ForegroundColor Red
        $ExitCode = 1
    }

    default {
        Write-Host "Overall Status : UNKNOWN" -ForegroundColor Yellow
        $ExitCode = 2
    }
}

Write-Host "========================================"
# Return an exit code to the calling process.
# Task Scheduler can use this to identify the result.


# ------------------------------------------------------------
# 9. Generate HTML backup monitoring report
# ------------------------------------------------------------

# Convert text into HTML-safe values.
# This prevents special characters in event messages
# from breaking the HTML report.
function ConvertTo-HtmlSafe {
    param([string]$Text)

    return [System.Net.WebUtility]::HtmlEncode($Text)
}

# ------------------------------------------------------------
# Prepare the backup information
# ------------------------------------------------------------

# Get the latest backup status from the event message.
# Determine the latest backup result safely.
$BackupStatus = "UNKNOWN"

if ($null -ne $LatestBackup) {

    if ($LatestBackup.Message -match "finished with Success") {
        $BackupStatus = "SUCCESS"
    }
    elseif ($LatestBackup.Message -match "finished with Failed") {
        $BackupStatus = "FAILED"
    }
    elseif ($LatestBackup.Message -match "finished with Warning") {
        $BackupStatus = "WARNING"
    }

}

# Default values when no successful backup exists.
$LastSuccessText = "Not found"
$BackupAgeText = "Unknown"
$FreshnessStatus = "UNKNOWN"

# Calculate freshness using the last SUCCESSFUL backup.
if ($null -ne $LastSuccessfulBackup) {

    $LastSuccessText = $LastSuccessfulBackup.TimeCreated.ToString(
        "yyyy-MM-dd HH:mm:ss"
    )

    $Age = (Get-Date) - $LastSuccessfulBackup.TimeCreated

    $BackupAgeText = "{0:N2} hours" -f $Age.TotalHours

    if ($Age.TotalHours -le $MaxBackupAgeHours) {
        $FreshnessStatus = "CURRENT"
    }
    else {
        $FreshnessStatus = "STALE"
    }
}

# Extract the error reason if the latest backup failed.
$FailureReason = "None"

if ($BackupStatus -eq "FAILED") {

    if ($LatestBackup.Message -match "Error:\s*(.+)") {
        $FailureReason = $Matches[1].Trim()
    }
    else {
        $FailureReason = "No detailed error provided"
    }
}

# ------------------------------------------------------------
# Choose dashboard colors based on monitoring results
# ------------------------------------------------------------

# CSS classes control the appearance of status indicators.
$OverallClass = if ($OverallStatus -eq "HEALTHY") {
    "success"
}
else {
    "danger"
}

$BackupClass = switch ($BackupStatus) {
    "SUCCESS" { "success" }
    "WARNING" { "warning" }
    default   { "danger" }
}

$FreshnessClass = if ($FreshnessStatus -eq "CURRENT") {
    "success"
}
else {
    "danger"
}

# Encode text that came from event logs.
$SafeJobName = ConvertTo-HtmlSafe $JobName
$SafeFailureReason = ConvertTo-HtmlSafe $FailureReason
$SafeLastSuccess = ConvertTo-HtmlSafe $LastSuccessText

# Record when the report was generated.
$GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ------------------------------------------------------------
# Load the external HTML template
# ------------------------------------------------------------

$TemplatePath = Join-Path $PSScriptRoot "Templates\Backup-Report.html"

if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
    throw "HTML template not found: $TemplatePath"
}

$HtmlReport = [System.IO.File]::ReadAllText($TemplatePath)

# Replace template placeholders with monitoring values.
$LatestBackupTimeText = "Not found"

if ($null -ne $LatestBackup) {
    $LatestBackupTimeText = $LatestBackup.TimeCreated.ToString(
        "yyyy-MM-dd HH:mm:ss"
    )
}

$Tokens = @{
    '{{JOB_NAME}}'           = $SafeJobName
    '{{OVERALL_STATUS}}'     = $OverallStatus
    '{{OVERALL_CLASS}}'      = $OverallClass
    '{{BACKUP_STATUS}}'      = $BackupStatus
    '{{BACKUP_CLASS}}'       = $BackupClass
    '{{FRESHNESS_STATUS}}'   = $FreshnessStatus
    '{{FRESHNESS_CLASS}}'    = $FreshnessClass
    '{{LAST_SUCCESS}}'       = $SafeLastSuccess
    '{{BACKUP_AGE}}'         = $BackupAgeText
    '{{LATEST_BACKUP_TIME}}' = ConvertTo-HtmlSafe $LatestBackupTimeText
    '{{FAILURE_REASON}}'     = $SafeFailureReason
    '{{GENERATED_AT}}'       = $GeneratedAt
}

foreach ($Token in $Tokens.Keys) {
    $HtmlReport = $HtmlReport.Replace($Token, [string]$Tokens[$Token])
}

$HtmlReportSaved = $false

try {

    # UTF-8 allows browsers to display text correctly.
    $HtmlReport | Out-File -FilePath $ReportPath `
                           -Encoding UTF8 `
                           -ErrorAction Stop

        $HtmlReportSaved = $true

    Write-Host "HTML report saved to: $ReportPath" `
        -ForegroundColor Green


}
catch {

    Write-Host "ERROR: Could not save HTML report." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    $HtmlReportSaved = $false
    $ExitCode = 2
}

# ------------------------------------------------------------
# Open the report in the default browser
# ------------------------------------------------------------

# ------------------------------------------------------------
# Structured data for the Unified Monitoring Dashboard
# ------------------------------------------------------------

$CollectedAtUtc = [DateTime]::UtcNow.ToString('o')

$LatestBackupTimeUtc = $null
$LastSuccessTimeUtc = $null
$BackupAgeHoursJson = $null

if ($null -ne $LatestBackup) {
    $LatestBackupTimeUtc = $LatestBackup.TimeCreated.ToUniversalTime().ToString('o')
}

if ($null -ne $LastSuccessfulBackup) {
    $LastSuccessTimeUtc = $LastSuccessfulBackup.TimeCreated.ToUniversalTime().ToString('o')
    $BackupAgeHoursJson = [math]::Round(
        ((Get-Date) - $LastSuccessfulBackup.TimeCreated).TotalHours, 2
    )
}

$BackupData = [PSCustomObject]@{
    SchemaVersion        = 1
    Hostname             = $env:COMPUTERNAME
    CollectedAtUtc       = $CollectedAtUtc
    JobName              = $JobName
    OverallStatus        = $OverallStatus
    BackupStatus         = $BackupStatus
    FreshnessStatus      = $FreshnessStatus
    LatestBackupTimeUtc  = $LatestBackupTimeUtc
    LastSuccessTimeUtc   = $LastSuccessTimeUtc
    BackupAgeHours       = $BackupAgeHoursJson
    MaxBackupAgeHours    = $MaxBackupAgeHours
    FailureReason        = $FailureReason
}

# ------------------------------------------------------------
# Export JSON for the Unified Monitoring Dashboard
# ------------------------------------------------------------

$DataFolder = Join-Path $PSScriptRoot 'Data'
$HistoryFolder = Join-Path $DataFolder 'History'

foreach ($Folder in @($DataFolder, $HistoryFolder)) {
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    }
}

# Convert backup monitoring data into JSON.
$Json = $BackupData | ConvertTo-Json -Depth 5

$Utf8 = New-Object System.Text.UTF8Encoding($false)

# Save a historical record of this monitoring run.
$HistoryFile = "Backup-Report-$Timestamp.json"
$HistoryPath = Join-Path $HistoryFolder $HistoryFile

[System.IO.File]::WriteAllText($HistoryPath, $Json, $Utf8)

# Update latest.json using a temporary file.
$LatestPath = Join-Path $DataFolder 'latest.json'

$TempPath = Join-Path $DataFolder (
    'latest-{0}.tmp' -f [guid]::NewGuid().ToString('N')
)

$BackupPath = Join-Path $DataFolder (
    'latest-backup-{0}.tmp' -f [guid]::NewGuid().ToString('N')
)

try {
    [System.IO.File]::WriteAllText($TempPath, $Json, $Utf8)

    if (Test-Path -LiteralPath $LatestPath -PathType Leaf) {
        [System.IO.File]::Replace(
            $TempPath,
            $LatestPath,
            $BackupPath
        )
    }
    else {
        [System.IO.File]::Move($TempPath, $LatestPath)
    }

    Write-Host "JSON data saved to: $LatestPath"
    Write-Host "JSON history saved to: $HistoryPath"
}
finally {
    foreach ($Path in @($TempPath, $BackupPath)) {
        if (Test-Path -LiteralPath $Path) {
            Remove-Item -LiteralPath $Path -Force
        }
    }
}

# ------------------------------------------------------------
# Save the HTML file
# ------------------------------------------------------------

if ($OpenReport -and $HtmlReportSaved) {

    # Start-Process opens the local HTML file using
    # the default application associated with .html.
    Start-Process -FilePath $ReportPath
}

exit $ExitCode
