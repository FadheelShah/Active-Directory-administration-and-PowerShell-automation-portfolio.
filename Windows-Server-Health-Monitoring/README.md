# Windows Server Health Monitoring Automation

**Automated Windows Server Health Checks Using PowerShell and HTML Reporting**

## Overview

This project automates routine Windows Server health checks using **PowerShell 5.1**, collecting system performance metrics, critical service statuses, and recent event logs into a centralized HTML dashboard.

The solution was developed and tested in a Windows Server 2022 VirtualBox lab to demonstrate practical server administration, monitoring, and automation skills.

### Business Objective

Routine manual health checks may require technicians to inspect several administrative tools, capture screenshots, and compile results.

This project aims to streamline that workflow.

| Metric                    | Value         |
| ------------------------- | ------------- |
| Estimated manual workflow | 60 minutes    |
| Target automated workflow | 40 minutes    |
| Target time reduction     | 33%           |
| Current status            | Lab prototype |

**Note:** The 33% improvement is a target, not a measured result. Further testing is required to validate actual time savings.

## Monitoring Features

The script collects real operating system data rather than simulated measurements.

| Component        | Monitoring method                       | Information collected                   |
| ---------------- | --------------------------------------- | --------------------------------------- |
| CPU              | `Get-Counter`                           | Average and peak CPU utilization        |
| Memory           | `Get-CimInstance Win32_OperatingSystem` | Used and available RAM                  |
| Disk             | `Get-CimInstance Win32_LogicalDisk`     | Total, free, and used disk capacity     |
| Uptime           | CIM operating system information        | Last boot time and uptime               |
| Windows services | `Get-Service`                           | Status of configured services           |
| Event logs       | `Get-WinEvent`                          | Recent System critical and error events |

### Health Evaluation

The script evaluates collected information against configurable thresholds.

| Status  | Description                                                      |
| ------- | ---------------------------------------------------------------- |
| HEALTHY | Measurement is within the configured threshold or expected state |
| WARNING | A threshold is exceeded or an expected condition is not met      |
| UNKNOWN | Information could not be collected or evaluated reliably         |

Default resource utilization warning thresholds:

- CPU average: 85%
- Memory: 85%
- Disk: 85%

CPU monitoring uses multiple performance counter samples to reduce reliance on a single reading.

The initial service monitoring configuration includes Active Directory Domain Services (`NTDS`), DNS (`DNS`), and IIS (`W3SVC`), reflecting the services hosted in the development lab.

Service expectations should be adjusted for other server roles.

## Technical Architecture

```text
Windows Server 2022
        |
        v
PowerShell Monitoring Script
        |
        |-- CPU Performance Counters
        |-- Memory and Disk (CIM)
        |-- Server Uptime
        |-- Windows Service Status
        |-- System Event Logs
        |
        v
Threshold and Status Evaluation
        |
        v
HTML Report Template
        |
        v
Generated Health Dashboard
        |
        v
Technician Review
```

The solution separates monitoring logic from dashboard presentation, allowing the HTML template to be maintained independently of the PowerShell script.

### Project Structure

```text
Windows-Server-Health-Monitoring/
│
├── Server-Health-Monitor.ps1
├── Templates/
│   └── Health-Report.html
├── Reports/
│   └── Generated HTML reports (ignored by Git)
├── README.md
└── .gitignore
```

## Installation and Usage

### Prerequisites

- Windows Server 2022 (development environment)
- Windows PowerShell 5.1
- Appropriate permissions to access performance counters, CIM information, services, and event logs
- A web browser to view the HTML report

### Running the Script

**1.** Clone or download the repository.

**2.** Open PowerShell and navigate to the project directory:

```powershell
cd "C:\Path\To\Windows-Server-Health-Monitoring"
```

**3.** Execute the monitoring script:

```powershell
.\Server-Health-Monitor.ps1
```

The script collects server health information and generates an HTML report.

### Custom CPU Sampling

```powershell
.\Server-Health-Monitor.ps1 `
    -CpuSamples 10 `
    -CpuIntervalSeconds 2 `
    -CpuWarningPercent 80
```

This example collects 10 CPU samples at two-second intervals and sets the CPU warning threshold to 80%.

To generate the report without automatically opening a browser:

```powershell
.\Server-Health-Monitor.ps1 -NoBrowser
```

*Verify these parameters against the current script version before use.*

## HTML Health Dashboard

The generated report consolidates monitoring results into a dashboard for technician review.

It includes CPU and memory utilization, disk capacity, uptime, monitored service statuses, and recent System event information.

### Dashboard Preview

\<!-- Replace this placeholder with the actual dashboard screenshot. -->



Reports include a timestamp displayed in Fiji time (UTC+12).

Generated reports are stored in the `Reports/` directory and excluded from Git using `.gitignore`.

## Testing and Validation

Development and testing take place in an isolated Windows Server 2022 VirtualBox environment.

The monitoring solution uses actual Windows system measurements.

During initial development, CPU readings displayed 0% despite system activity. The collection approach was reviewed and tested using Windows Performance Counters, which returned nonzero utilization values.

This led to using `Get-Counter` for CPU sampling.

### Validation Checklist

- [x] Obtain nonzero CPU measurements using performance counters.
- [ ] Verify CPU measurements against the generated HTML report.
- [ ] Compare memory and disk results with Windows system information.
- [ ] Validate configured Windows service status reporting.
- [ ] Verify event log results against Event Viewer.
- [ ] Test warning and collection-failure handling.
- [ ] Measure actual time savings against the manual workflow.

The unchecked items represent validation work that has not yet been documented as completed.

## Security and Limitations

The script is intended for read-only monitoring and does not require changes to Active Directory, DNS, or IIS configurations.

**Operational considerations:**

- Use accounts with appropriate monitoring permissions.
- Review reports before sharing them outside the environment.
- Adjust service checks and warning thresholds for each server.
- Investigate UNKNOWN results rather than assuming the system is healthy.

**Current limitations:**

- Local server monitoring only.
- No centralized multi-server dashboard.
- No automated email alerts.
- No historical performance database.
- No measured evidence of the target 33% efficiency improvement.

This is a lab prototype, not a production-certified enterprise monitoring solution.

## Future Improvements

Planned enhancements include:

- Monitoring multiple Windows Servers using PowerShell remoting.
- Scheduling automated health checks with Task Scheduler.
- Adding email notifications for warning conditions.
- Recording historical metrics for trend analysis.
- Implementing configurable critical thresholds.

## Skills Demonstrated

**Windows Server Administration · PowerShell Automation · Performance Monitoring · CIM/WMI · Event Log Analysis · HTML/CSS Reporting · Git/GitHub · Technical Documentation**

---

**Project Status:** Functional lab prototype — ongoing testing and validation.

**Environment:** Windows Server 2022 | PowerShell 5.1 | Oracle VirtualBox
