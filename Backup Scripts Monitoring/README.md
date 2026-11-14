# Veeam Backup Health Monitoring with PowerShell

A PowerShell-based backup monitoring solution that checks Veeam Agent backup results using Windows Event Logs and presents backup health information through a local HTML dashboard.

Developed and tested in a Windows Server 2022 lab to demonstrate backup monitoring, PowerShell automation, troubleshooting, and recovery verification.

## 1. Executive Overview

### The Problem

Backup jobs can fail without being noticed until someone manually checks the backup software or attempts to recover data.

For IT teams managing multiple systems, repeatedly checking backup results can consume time and increase the risk of overlooking a failed or outdated backup.

### The Solution

This project uses PowerShell to retrieve Veeam Agent backup events, evaluate backup health, and generate an HTML report that can be opened in a web browser.

The report provides visibility into:

- Latest backup result (Success, Failed, Warning, or Unknown)
- Most recent successful backup
- Age of the last successful backup
- Backup freshness against a configurable threshold
- Failure reason, when available
- Overall backup health (Healthy or Unhealthy)

### Business Value

| Benefit | Description |
|---|---|
| Reduced manual checking | Backup information is collected and evaluated automatically when the script runs |
| Faster troubleshooting | Failure details are extracted from Windows Event Logs |
| Backup visibility | Technicians can identify failed or outdated backups |
| Clear reporting | HTML dashboard makes results easier to interpret |
| Low infrastructure overhead | Uses native PowerShell and Windows Event Logs |

**Project scope:** This is a local monitoring prototype, not a centralized monitoring platform or a replacement for Veeam's backup and recovery capabilities.

---

## 2. Technical Overview

### Lab Environment

| Component | Configuration |
|---|---|
| Hypervisor | Oracle VirtualBox |
| Operating system | Windows Server 2022 |
| Scripting language | Windows PowerShell 5.1 |
| Backup software | Veeam Agent for Microsoft Windows Free |
| Backup source | `C:\BackupTest` |
| Backup destination | Separate 10 GB virtual disk (`D:`) |
| Backup job | `Lab-File-Backup` |
| Backup schedule | Daily |
| Monitoring data source | Windows Event Log — `Veeam Agent` |
| Report format | Local HTML file |

The Windows Server VM also hosts Active Directory, DNS, and IIS for other lab exercises. The monitoring solution does not require modifying those services.

### How It Works

```text
Veeam Agent Backup Job
          |
          v
Windows Event Log
    "Veeam Agent"
          |
          v
Monitoring-Script.ps1
          |
          +-- Latest job result
          |
          +-- Last successful backup
          |
          +-- Backup age / freshness
          |
          +-- Failure reason
          |
          v
Overall Health Evaluation
          |
          +-- PowerShell console output
          |
          +-- Backup-Report.html
                    |
                    v
               Web Browser
```

The script reads Windows Event Logs without modifying the backup job or its restore points.

---

## 3. Backup Events

The following event IDs were observed during testing.

| Event ID | Description |
|---|---|
| 110 | Backup job started |
| 190 | Backup job completed |
| 10010 | Restore point created |
| 210 | File-level restore started |
| 290 | File-level restore completed |

### Event ID 190

Both successful and failed backup attempts generated Event ID `190` in the lab.

The script examines the event message to determine the result.

**Successful backup example:**

```text
Event ID: 190
Level: Information

Veeam Agent 'Lab-File-Backup' finished with Success.
Job details: Backup has been created.
```

**Failed backup example:**

```text
Event ID: 190
Level: Error

Veeam Agent 'Lab-File-Backup' finished with Failed.
Job details: Error: Cannot find folder C:\BackupTest
```

These event mappings were verified in the test environment. Event behavior should be validated when using other Veeam versions or configurations.

A restore-point-created event does not necessarily indicate that the entire backup job completed successfully.

---

## 4. Monitoring Logic

The script performs three main checks.

### Latest Backup Result

Retrieves the most recent completion event for the configured backup job and identifies whether it succeeded or failed.

### Last Successful Backup

Independently identifies the most recent successful backup.

This is important because a failed backup does not necessarily mean that no previous successful backup exists.

### Backup Freshness

Calculates the elapsed time since the last successful backup.

The configured threshold is:

```powershell
$MaxBackupAgeHours = 24
```

A successful backup older than the threshold is classified as stale.

### Overall Health

| Latest result | Freshness | Overall health |
|---|---|---|
| SUCCESS | CURRENT | HEALTHY |
| SUCCESS | STALE | UNHEALTHY |
| FAILED | CURRENT | UNHEALTHY |
| FAILED | STALE | UNHEALTHY |
| WARNING | CURRENT | UNHEALTHY |

The monitoring logic requires both a successful latest backup and a current successful backup for a healthy result.

---

## 5. HTML Dashboard

The monitoring script generates a local HTML report named:

`Backup-Report.html`

The dashboard displays the backup job name, latest result, last successful backup, backup age, freshness, failure details, and overall health.

Status indicators use colors to make results easier to identify.

The HTML report is generated locally and does not require a web server, external hosting, or an internet connection.

**Note:** The dashboard displays a snapshot from the last script execution. It does not provide live monitoring or automatically refresh backup information.

---

## 6. Technician Guide

### Prerequisites

- Windows Server with a compatible Veeam Agent installation
- Windows PowerShell 5.1
- An existing Veeam backup job
- Access to the `Veeam Agent` Windows Event Log
- Permission to save the HTML report

### Configuration

Open `Monitoring-Script.ps1` and review the configuration variables.

```powershell
$JobName = "Lab-File-Backup"

$LogName = "Veeam Agent"

$CompletionEventID = 190

$MaxBackupAgeHours = 24
```

For HTML reporting:

```powershell
$ReportPath = Join-Path $PSScriptRoot "Backup-Report.html"

$OpenReport = $true
```

Set `$OpenReport` to `$false` if automatic browser launching is not required.

### Running the Script

Open PowerShell and execute:

```powershell
& "C:\Path\To\Monitoring-Script.ps1"
```

The script evaluates the latest recorded backup events and displays the monitoring results.

With HTML reporting enabled, it also generates `Backup-Report.html` and attempts to open it in the default browser.

### Example Console Output

```text
========================================
        VEEAM BACKUP MONITOR
========================================
Job Name : Lab-File-Backup
Last Run : 11/14/2026 16:36:26
Event ID : 190
Status   : FAILED
Reason   : Cannot find folder C:\BackupTest
Last Success : 11/14/2026 16:35:10
Backup Age   : 0.2 hours
Freshness    : CURRENT
----------------------------------------
Overall Status : UNHEALTHY
========================================
```

### Troubleshooting

| Problem | Recommended action |
|---|---|
| No backup events found | Verify the job name and Windows Event Log |
| Backup FAILED | Review the extracted error message and Veeam job details |
| Backup STALE | Check the backup schedule and last successful execution |
| Freshness UNKNOWN | Verify that a successful completion event exists |
| HTML report missing | Check the output path, file permissions, and script errors |
| Browser does not open | Open the generated HTML file manually |

---

## 7. Testing and Validation

The monitoring logic was tested using actual Veeam Agent events.

### Test 1 — Successful Backup

A file-level backup of `C:\BackupTest` completed successfully.

**Result:** The script identified the successful backup.

### Test 2 — File Restoration

A backed-up test file was copied to a separate location using Veeam File Level Restore.

**Result:** The restored file was located successfully.

### Test 3 — Stale Backup Detection

The freshness threshold was temporarily reduced from 24 hours to 0.1 hours.

**Result:** The script correctly identified the backup as STALE.

The threshold was restored to 24 hours afterward.

### Test 4 — Real Backup Failure

The source folder `C:\BackupTest` was temporarily renamed, making the configured backup source unavailable.

Veeam reported:

```text
Error: Cannot find folder C:\BackupTest
```

The monitoring script detected:

```text
Status         : FAILED
Overall Status : UNHEALTHY
```

### Test 5 — Previous Successful Backup Detection

Despite the latest backup failure, the script correctly identified an earlier successful backup.

**Result:** The script displayed a CURRENT previous success while maintaining an UNHEALTHY overall status.

The original source folder name was restored after the failure test.

---

## 8. Limitations

This project is designed as a small-scale monitoring prototype.

Current limitations include:

- Monitors a configured Veeam Agent backup job on one Windows machine.
- Relies on available Windows Event Log history.
- Does not independently verify the integrity or continued availability of backup files.
- Does not replace periodic backup restoration testing.
- Does not provide centralized monitoring across multiple servers.
- Does not currently send email or other notifications.
- The local HTML report is updated when the script runs, not continuously.
- Additional testing is required for warning events, missing events, and event-log access failures.

The 24-hour freshness threshold is configurable and may need adjustment based on actual backup completion times.

---

## 9. Potential Future Improvements

Possible enhancements include:

- Windows Task Scheduler integration for unattended daily checks
- Additional error handling and monitoring exit codes
- Email notifications for unhealthy backups
- CSV reporting and historical results
- Support for monitoring multiple backup jobs or servers

These are potential enhancements and are not claimed as implemented features.

---

## 10. Skills Demonstrated

- PowerShell scripting and conditional logic
- Windows Event Log analysis using `Get-WinEvent`
- Windows Server administration
- Veeam Agent backup configuration
- File-level backup and restoration
- Backup failure troubleshooting
- Error message extraction
- Time-based monitoring
- HTML and CSS report generation
- Controlled failure testing

---

## Disclaimer

This project was developed in an isolated personal lab for educational and portfolio purposes.

It is not a production-ready backup monitoring platform. Production use would require additional validation, error handling, security review, and testing against the target backup environment.
