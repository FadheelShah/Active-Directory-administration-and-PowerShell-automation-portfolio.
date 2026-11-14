# Windows Server Health Monitoring

Read-only Windows PowerShell 5.1 monitoring project for a Windows Server 2022 lab. Reports are saved as standalone HTML files.

## Structure
- `Server-Health-Monitor.ps1`: data collection, evaluation, report generation
- `Templates/Health-Report.html`: HTML and CSS layout (separate from PowerShell)
- `Reports/`: generated reports (not committed to Git)

## Run
Open `Server-Health-Monitor.ps1` in Windows PowerShell ISE and press F5, or run:

```powershell
.\Server-Health-Monitor.ps1
```

To avoid opening the browser:

```powershell
.\Server-Health-Monitor.ps1 -NoBrowser
```

## Checks
- CPU average and peak, sampled with `Get-Counter`
- RAM utilization from `Win32_OperatingSystem`
- Fixed local disk usage
- Server uptime and last boot
- NTDS, DNS and W3SVC service states (lab-specific defaults)
- Count of System log Critical/Error events in the last 24 hours

Thresholds default to 85% for CPU average, RAM and disks. Warning does not necessarily indicate an incident; technicians must investigate. A missing measurement is UNKNOWN rather than healthy. Overall status prioritizes WARNING over UNKNOWN.

## Limitations
Local server only. No ESXi monitoring. The report is a snapshot, not a continuous trend. The timestamp is displayed in Fiji time but is not independently synchronized against a trusted reference. No production validation or measured time savings are claimed. Verify service expectations and thresholds for each environment. Event counts alone do not establish health.

## Safety
Does not start/stop services or change AD, DNS, IIS, firewall or network settings. Creates only HTML files in Reports.
