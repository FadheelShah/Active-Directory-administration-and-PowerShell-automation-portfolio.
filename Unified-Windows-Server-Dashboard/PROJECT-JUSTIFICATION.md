# Project Justification — Unified Windows Server Monitoring Dashboard

**Status:** Proposal / concept — not yet deployed  
**Origin:** Personal initiative  
**Environment:** Windows Server 2022 lab  
**Proposed technologies:** PowerShell 5.1, Windows Task Scheduler, JSON, HTML, CSS, JavaScript, IIS

## 1. Executive summary

This personal project idea proposes a lightweight, internally accessible dashboard that brings together Windows Server health monitoring and backup-check results. The aim is to make existing PowerShell-generated information easier to review, identify potential problems sooner, and retain useful historical records.

It could be evaluated as a lower-additional-licensing-cost option for small client sites whose needs or budgets do not justify a full commercial Remote Monitoring and Management (RMM) platform. **It is not an RMM replacement**, and it does not remove the operational benefits of professional RMM tools.

Subject to management approval and the applicable client agreement, remaining allocated SLA hours in a month could be used to prototype, test, document, and assess the idea. No client work or SLA eligibility is assumed to be approved by this proposal.

## 2. Background and problem

Two separate PowerShell projects already collect server-health and backup-check information and produce HTML reports. Task Scheduler can run these scripts automatically. However, the reports are separate, which can make routine review and comparison less convenient.

A single dashboard could reduce the effort of locating multiple reports and help administrators see when a check last ran, whether its results are stale, and which conditions warrant attention.

## 3. Proposed solution

Build a web interface that reads structured results (proposed JSON exports) from the existing scripts, while retaining their independent execution and timestamped HTML reports. The first version would show the **latest collected readings**, not claim continuous live monitoring.

Proposed dashboard information includes CPU and memory utilization, disk capacity, critical service status, backup-check findings, report timestamps, warning indicators, and links to detailed historical reports. The exact fields will depend on what the scripts can reliably collect.

## 4. Benefits to the company

- **More efficient support workflows:** one view for routine health and backup reviews may reduce manual report navigation.
- **Proactive service improvement:** better visibility may help engineers recognize warnings before they become larger incidents, provided results are reviewed promptly.
- **Reusable internal knowledge:** a documented prototype could inform similar solutions for other suitable Windows Server sites.
- **Additional service option:** a scoped, lightweight monitoring offering may suit some budget-constrained clients without misrepresenting it as a full RMM product.
- **Skills and documentation:** practical experience in automation, integration, testing, and supportability can improve internal technical capability.

These are anticipated benefits; time savings and operational outcomes should be measured during testing rather than promised in advance.

## 5. Benefits to the client

- **Clearer visibility** into selected server conditions and backup-check results.
- **Simpler reporting** through a centralized interface and historical records.
- **Potentially earlier issue identification** for conditions such as low disk space, stopped services, or failed checks.
- **Potentially lower additional licensing costs** when existing Windows technologies meet a narrowly defined need.
- **Support for continuity planning** through more visible backup-check findings, without suggesting that checks replace restore tests.

The solution is **not free to operate**: implementation, maintenance, security, hosting, and support all have costs.

## 6. Proposed use of remaining monthly SLA hours

If the applicable SLA allows improvement work, and both management and the client authorize it where required, available hours could support:

1. Reviewing the two existing scripts and their scheduled-task results.
2. Defining a consistent, safe JSON output format.
3. Building the dashboard prototype and report-history access.
4. Testing stale data, missing files, script failures, and access controls.
5. Documenting configuration, results, limitations, and maintenance needs.
6. Presenting findings and a recommendation on whether further development is worthwhile.

This is a proposed use of time, **not a claim that development is included in any particular SLA**. Priority support obligations and contractual restrictions take precedence.

## 7. Relationship to commercial RMM

Commercial RMM platforms commonly offer capabilities outside this project's initial scope, including fleet-wide visibility, remote access, patching, endpoint management, centralized alerting and escalation, policy enforcement, vendor support, and multi-client administration.

This dashboard would initially provide **local, periodic monitoring and reporting**. It would not deliver feature parity, guaranteed availability, or equivalent security and support. Sites that need comprehensive remote management, mature alerting, or centrally governed operations may be better served by an RMM platform.

**The idea is to provide a limited alternative for suitable sites that do not wish to pay for a full RMM service—not to undermine or replace the benefits of RMM.**

## 8. Technical approach

```text
Windows Task Scheduler
        |
        +--> Server Health Monitor.ps1 --> HTML reports + proposed JSON
        |
        +--> Backup Checker.ps1 --------> HTML reports + proposed JSON
                                               |
                               Unified internal web dashboard
                                               |
                                       Authorized administrator
```

The scripts remain independent to simplify testing and troubleshooting. A dashboard should make stale or missing data explicit instead of showing an outdated result as healthy. IIS hosting is a possible deployment option, subject to access-control and security review.

## 9. Risks, safeguards, and limitations

- Scheduled checks can miss problems between runs; unattended execution depends on the server or VM being powered on.
- A task may exit successfully even when the monitored backup or service is unhealthy; the dashboard must distinguish execution success from operational status.
- Monitoring data can reveal sensitive infrastructure details; restrict access and protect report directories.
- Static reports and dashboards do not provide automatic alert escalation unless separately implemented.
- Backup checks cannot prove that data is recoverable; restore testing is still necessary.
- Custom software creates ongoing maintenance, testing, and ownership responsibilities.
- Any real client deployment requires authorization, scope agreement, security review, and validation.

## 10. Proposed deliverables and success criteria

**Deliverables:** dashboard prototype, structured data outputs, retained HTML reports, task and dashboard test evidence, configuration guidance, screenshots, and limitations documentation.

**Success criteria:** both scripts run unattended; output is accurate and timestamped; previous reports remain available; the dashboard reflects the newest valid data; missing/stale/error states are visible; access is appropriately restricted; and the solution can be maintained without disrupting the original scripts.

## 11. Project status and next steps

The underlying monitoring and backup-check scripts exist as separate lab projects. The **unified dashboard is a concept and has not yet been implemented or validated**. The next step is to review the scripts and sample outputs before finalizing the data model and building the first dashboard version.

## 12. Conclusion

This personal initiative proposes a practical way to combine existing Windows Server automation into a clearer administrative view. It may benefit the company through improved support workflows and a reusable prototype, and benefit appropriate clients through simpler visibility and potentially lower additional licensing costs. Any use of remaining SLA hours must be approved and contractually appropriate. The dashboard should be evaluated as a **complement to, not a substitute for, commercial RMM capabilities**.
