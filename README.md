# Enterprise Active Directory Engineering & Automation Portfolio

A comprehensive, production-grade systems administration portfolio demonstrating automated identity provisioning, conflict resolution matrices, environment hardening, and console optimization. This architecture bridges the gap between Human Resources (HR) data rosters and Active Directory Domain Services (AD DS) within a Windows Server ecosystem.

## 🏗️ Project Architecture & Topology
*   **Operating System:** Windows Server 2022 (Promoted to Core Domain Controller)
*   **Domain Context:** `testlab.local`
*   **Target Organizational Unit (OU):** `OU=Employees,DC=testlab,DC=local`
*   **Identity Source of Truth:** Structured HR data rosters leveraging unique Employee ID keys (`employeeID`).
*   **Execution Policy Context:** Managed administrative session execution controls (`Bypass`).

---

## 🛠️ Engineered Solutions & Core Modules

### 1. Bulk Identity Automation Engine (`Deploy-Users.ps1`)
Designed for large-scale operations (e.g., corporate mergers, batch graduate hiring), this script parses multi-line HR data streams, executes automated data-integrity gates, and logs operations to an audit ledger.
*   **Idempotency & Deduplication Guard:** Utilizes native directory query controls (`Get-ADUser -Filter "EmployeeID -eq '$ID'"`) to interrogate the active database. If an Employee ID matches an existing record, the engine safely skips creation to protect production data persistence.
*   **Automated Verification Loop:** If a username format matches an existing account but belongs to a *different* individual, the loop automatically appends an ascending numerical string until a clean slot is cleared.
*   **Transactional Logging Ledger:** Pipelines execution states (`SUCCESS`, `SKIPPED`, `FAILED`) dynamically to a centralized, local text ledger using native PowerShell 5.1 compatibility standards (`-Encoding utf8`).

### 2. Daily Administrative Parameter Utility (`Add-SingleUser.ps1`)
A locked-down, parameter-driven command-line tool built for Tier 1 Helpdesk technicians to handle ad-hoc user creations without touching or exposing the core script logic.
*   **Command Interface encapsulation:** Uses a structured `param()` block enforcing mandatory fields (`-EmployeeID`, `-FirstName`, `-LastName`, `-Department`, `-Title`).
*   **Advanced Conflict Resolution:** Checks both the backend system login ID (`sAMAccountName`) and the graphical directory Common Name (`CN`) to prevent directory object duplication conflicts within the target OU compartment.

### 3. Active Directory Schema & Management Console Optimization
Engineered custom graphical view modifications using **ADSI Edit (`adsiedit.msc`)** to surface advanced, hidden database fields for administrative staff.
*   **Schema Extension Partitioning:** Connected directly to the `Configuration` naming context database partition.
*   **Display Specifier Hardening:** Modified the English locale specifier (`CN=409 -> CN=default-Display -> extraColumns`) to bind the `employeeID` property globally.
*   **Console Enhancement:** Unlocked the ability to add `Employee ID` as a selectable, live-updating column header directly within Saved Queries and folder views inside the Active Directory Users and Computers (ADUC) application window.

---

## 🚀 Local Staging & Deployment Guide

### Prerequisites
1.  A fresh Windows Server VM promoted to a Domain Controller with the **Active Directory Domain Services (AD DS)** role active.
2.  An Organizational Unit compartment named `Employees` created under the root domain tree.

### Installation & Execution Steps

1.  **Clone the portfolio codebase into your lab environment:**
    ```powershell
    git clone https://github.com/YOUR_USERNAME/ad-identity-provisioner.git
    cd ad-identity-provisioner
    ```

2.  **Execute the mass onboarding engine (Simulated HR Batch run):**
    ```powershell
    .\Deploy-Users.ps1
    ```

3.  **Execute an ad-hoc single user onboarding via the parameter framework:**
    ```powershell
    .\Add-SingleUser.ps1 -EmployeeID "EMP-2001" -FirstName "Fadheel" -LastName "Shah" -Department "IT" -Title "SysAdmin"
    ```

4.  **Review the generated transaction logs:**
    ```powershell
    Get-Content .\ProvisioningAuditLog.csv | ConvertFrom-Csv | Format-Table -AutoSize
    ```

---

## 📈 Real-World Business Value (Resume Highlights)
*   **Elimination of Human Error:** Standardizes corporate profile properties (`sAMAccountName`, `UserPrincipalName`) using deterministic string manipulation practices, ensuring zero typing errors during mass setups.
*   **System Integrity Preservation:** Integrates advanced pre-checks that shield production directories from schema collision failures, crashing scripts, or duplicate data pollution.
*   **Operational Delegation:** Packages complex Active Directory interactions into simple command parameters, allowing junior administrators to safely run identity creation scripts without elevated system design exposure.
