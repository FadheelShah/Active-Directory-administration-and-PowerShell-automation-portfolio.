# Unified Windows Server Monitoring Dashboard

**Status:** Concept / Planning  
**Origin:** Personal initiative  
**Environment:** Windows Server 2022 lab

## Overview

A proposed lightweight dashboard combining results from two existing PowerShell projects: Windows Server Health Monitoring and Backup Checker. Each script will remain independently scheduled and generate timestamped reports. The dashboard will present their latest collected information through a single web interface.

## Motivation and business case

This personal idea explores a lower-additional-licensing-cost monitoring option for smaller client sites that do not want to pay for a commercial Remote Monitoring and Management (RMM) platform, or whose limited requirements do not justify one. It could reduce time spent locating separate reports, support earlier recognition of issues, and make monitoring results easier to review.

For the company, the project could improve reporting efficiency, offer a reusable monitoring approach, and provide an opportunity to use remaining monthly SLA hours productively **only if the SLA permits development work and management/client approval is obtained**. For clients, the potential value is clearer server and backup visibility, report history, and reduced manual checking. Development, security, hosting, support and maintenance still have costs.

**This project does not replace RMM or diminish its benefits.** Commercial RMM solutions may provide centralized multi-device management, remote access, patching, alert escalation, security integrations, vendor support, and other capabilities not offered here. Where those are required, an RMM remains the appropriate choice.

## Planned features

- CPU, memory, disk and critical Windows service status from the latest health check.
- Backup-check results and timestamps; no claim of recoverability without restore tests.
- Dashboard status cards, warnings, stale-data indicators and historical report links.
- Separate PowerShell collection scripts with JSON output alongside existing HTML reports.
- Scheduled unattended execution through Windows Task Scheduler.

## Proposed architecture

```text
Windows Task Scheduler
    |-- Server Health Monitor.ps1 --> HTML + JSON --|
    |-- Backup Checker.ps1 -------> HTML + JSON --+--> Unified dashboard --> Administrator
```

## Technology

Windows Server 2022; Windows PowerShell 5.1; Task Scheduler; HTML; CSS; JavaScript; JSON; potentially IIS for internal hosting; Git/GitHub for documentation.

## Roadmap

### Phase 1 — Verify existing automation
- [ ] Review the two scripts and their outputs.
- [ ] Verify scheduled, unattended execution and report retention.
- [ ] Review error handling and output paths.

### Phase 2 — Integrate data
- [ ] Define a consistent JSON schema.
- [ ] Add JSON exports without removing HTML reports.
- [ ] Handle missing, invalid, and stale results.

### Phase 3 — Build dashboard
- [ ] Create interface and status cards.
- [ ] Display actual collected metrics and timestamps.
- [ ] Link to historical reports.

### Phase 4 — Test and document
- [ ] Test after reboot, without login, and with missing or failed reports.
- [ ] Review permissions, authentication, and internal access controls.
- [ ] Capture evidence, troubleshooting notes, and screenshots.

## Scope and limitations

This is a lab prototype, not a production-ready monitoring service. Data is periodically collected, not continuously live. The initial scope does not include remote control, patch deployment, multi-tenant device management, enterprise alerting or guaranteed monitoring availability. A successful backup-check result does not prove restore capability. Production/client use requires explicit approval, security assessment, maintenance ownership, and testing.

## Project origin

A **personal project idea** that may eventually be suitable for small sites with limited budgets or monitoring requirements. The dashboard is still proposed; features and benefits above are expected outcomes, not claims of completed implementation.
