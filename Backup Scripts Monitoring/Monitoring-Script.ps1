
# ============================================================
# Project: Veeam Agent Backup Monitoring
# Script: Monitoring-Script.ps1
# Purpose: Check the latest Veeam backup job result
# Environment: Windows Server 2022 / PowerShell 5.1
# ============================================================

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

# Save the HTML report in the same folder as this script.
$ReportPath = Join-Path $PSScriptRoot "Backup-Report.html"

# Open the generated report in the default browser.
$OpenReport = $true

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

    # If Windows cannot read the event log,
    # display the error and stop the script.
    Write-Host "ERROR: Unable to read Veeam Event Log."
    Write-Host $_.Exception.Message

    exit 1
}


# ------------------------------------------------------------
# 3. Check whether a backup completion event exists
# ------------------------------------------------------------

# $null means no matching completion event was found.
# This could happen if the backup has never completed,
# the log was cleared, or the job name is incorrect.

if ($null -eq $LatestBackup) {

    Write-Host "WARNING: No completed backup found for $JobName"

    exit 1
}


# ------------------------------------------------------------
# 3.1 Find the last successful backup
# ------------------------------------------------------------

# Search Veeam completion events for our specific job.
# Only events reporting "Success" qualify.

$LastSuccessfulBackup = Get-WinEvent -FilterHashtable @{
    LogName = $LogName
    Id      = $CompletionEventID
} | Where-Object {
    $_.Message -like "*Veeam Agent '$JobName' finished with Success*"
} | Select-Object -First 1

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

# Inspect the message associated with the latest
# completion event to identify the backup result.

if ($LatestBackup.Message -match "finished with Success") {

    Write-Host "Status   : SUCCESS" -ForegroundColor Green

}
elseif ($LatestBackup.Message -match "finished with Warning") {

    Write-Host "Status   : WARNING" -ForegroundColor Yellow

}

elseif ($LatestBackup.Message -match "finished with Failed") {

    # Display the failed backup status.
    Write-Host "Status   : FAILED" -ForegroundColor Red

    # Extract the failure reason from the event message.
    # Veeam includes additional details after "Error:".
    if ($LatestBackup.Message -match "Error:\s*(.+)") {

        $FailureReason = $Matches[1].Trim()

        Write-Host "Reason   : $FailureReason" -ForegroundColor Red

    }
    else {

        # Some failed events might not include an
        # explicit error description.
        Write-Host "Reason   : No detailed error provided"

    }

}

else {

    # An unexpected message should not be treated
    # as a successful backup.
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

# Start by assuming the backup is unhealthy.
# We will only mark it healthy if all checks pass.
$OverallStatus = "UNHEALTHY"

# Check whether the latest completed backup succeeded.
$LatestJobSucceeded = $LatestBackup.Message -match "finished with Success"

# Check whether a successful backup exists and is recent.
$SuccessfulBackupIsCurrent = $false

if ($null -ne $LastSuccessfulBackup) {

    # Calculate the age of the last successful backup.
    $SuccessfulBackupAge = (Get-Date) - $LastSuccessfulBackup.TimeCreated

    if ($SuccessfulBackupAge.TotalHours -le $MaxBackupAgeHours) {
        $SuccessfulBackupIsCurrent = $true
    }
}

# Both conditions must be true for a healthy result.
if ($LatestJobSucceeded -and $SuccessfulBackupIsCurrent) {

    $OverallStatus = "HEALTHY"
}

# ------------------------------------------------------------
# 8. Display overall monitoring result
# ------------------------------------------------------------

Write-Host "----------------------------------------"

if ($OverallStatus -eq "HEALTHY") {

    Write-Host "Overall Status : HEALTHY" -ForegroundColor Green
    $ExitCode = 0

}
else {

    Write-Host "Overall Status : UNHEALTHY" -ForegroundColor Red
    $ExitCode = 1

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
if ($LatestBackup.Message -match "finished with Success") {
    $BackupStatus = "SUCCESS"
}
elseif ($LatestBackup.Message -match "finished with Failed") {
    $BackupStatus = "FAILED"
}
elseif ($LatestBackup.Message -match "finished with Warning") {
    $BackupStatus = "WARNING"
}
else {
    $BackupStatus = "UNKNOWN"
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
# Build the HTML document
# ------------------------------------------------------------

# A here-string allows us to write multiline HTML.
# PowerShell replaces variables inside a double-quoted
# here-string with their values.

$HtmlReport = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>Veeam Backup Monitor</title>

    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: #f3f5f9;
            color: #1e293b;
            margin: 0;
            padding: 40px 20px;
        }

        .container {
            max-width: 850px;
            margin: auto;
        }

        .header {
            margin-bottom: 25px;
        }

        .header h1 {
            margin-bottom: 5px;
        }

        .subtitle {
            color: #64748b;
        }

        .card {
            background: white;
            border-radius: 12px;
            padding: 25px;
            margin-bottom: 20px;
            box-shadow: 0 3px 12px rgba(0,0,0,0.06);
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 15px;
        }

        .label {
            color: #64748b;
            font-size: 14px;
            margin-bottom: 8px;
        }

        .value {
            font-size: 20px;
            font-weight: 600;
            overflow-wrap: anywhere;
        }

        .success {
            color: #15803d;
        }

        .danger {
            color: #dc2626;
        }

        .warning {
            color: #b45309;
        }

        .footer {
            color: #64748b;
            font-size: 13px;
            text-align: center;
            margin-top: 25px;
        }

        @media (max-width: 600px) {
            .grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>

<body>
    <div class="container">

        <div class="header">
            <h1>Veeam Backup Monitor</h1>
            <div class="subtitle">
                PowerShell Backup Health Report
            </div>
        </div>

        <div class="card">
            <div class="label">Backup Job</div>
            <div class="value">$SafeJobName</div>
        </div>

        <div class="card">
            <div class="label">Overall Backup Health</div>
            <div class="value $OverallClass">
                $OverallStatus
            </div>
        </div>

        <div class="grid">

            <div class="card">
                <div class="label">Latest Backup Result</div>
                <div class="value $BackupClass">
                    $BackupStatus
                </div>
            </div>

            <div class="card">
                <div class="label">Backup Freshness</div>
                <div class="value $FreshnessClass">
                    $FreshnessStatus
                </div>
            </div>

            <div class="card">
                <div class="label">Last Successful Backup</div>
                <div class="value">$SafeLastSuccess</div>
            </div>

            <div class="card">
                <div class="label">Backup Age</div>
                <div class="value">$BackupAgeText</div>
            </div>

        </div>

        <div class="card">
            <div class="label">Latest Backup Time</div>
            <div class="value">$($LatestBackup.TimeCreated)</div>
        </div>

        <div class="card">
            <div class="label">Failure Details</div>
            <div class="value">$SafeFailureReason</div>
        </div>

        <div class="footer">
            Report generated: $GeneratedAt
            <p>Windows Server 2022 | Veeam Agent | PowerShell</p>
        </div>

    </div>
</body>
</html>
"@

# ------------------------------------------------------------
# Save the HTML file
# ------------------------------------------------------------

try {

    # UTF-8 allows browsers to display text correctly.
    $HtmlReport | Out-File -FilePath $ReportPath `
                           -Encoding UTF8 `
                           -ErrorAction Stop

    Write-Host "HTML report saved to: $ReportPath" `
        -ForegroundColor Green

}
catch {

    Write-Host "ERROR: Could not save HTML report." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message

    exit 2
}

# ------------------------------------------------------------
# Open the report in the default browser
# ------------------------------------------------------------

if ($OpenReport) {

    # Start-Process opens the local HTML file using
    # the default application associated with .html.
    Start-Process -FilePath $ReportPath
}

exit $ExitCode
