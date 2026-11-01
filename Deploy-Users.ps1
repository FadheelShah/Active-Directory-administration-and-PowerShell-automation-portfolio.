<#
.SYNOPSIS
    Active Directory Bulk Provisioning Engine Guided by HR Employee IDs.
.DESCRIPTION
    Processes HR roster records, matching them against Active Directory using 
    unique Employee ID numbers to prevent duplicate profile creation.
.NOTES
    Author: Fadheel Ahmed Shah
    Test Environment: VM Server 2022 created in Oracle VB
#>

# Explicitly ensure the native Active Directory module is loaded
Import-Module ActiveDirectory -ErrorAction Stop

# 1. THE DATA SOURCE (Staging the unique Employee ID Keys from HR)
$LogPath = "$PSScriptRoot\ProvisioningAuditLog.csv"
$OnboardingData = @"
EmployeeID,FirstName,LastName,Department,Title
EMP-1001,Fadheel,Ahmed,IT,SysAdmin
EMP-1002,Peter,Pet,Finance,Accountant
EMP-1003,Jane,Doe,Operations,Manager
EMP-1004,Fadheel,Ahmed,IT,SysAdmin
"@

# Initialize Log Ledger if it doesn't exist
if (-not (Test-Path $LogPath)) {
    "Timestamp,EmployeeID,SamAccountName,Department,Status,Details" | Out-File $LogPath -Encoding utf8
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "     LIVE AD IDENTITY ENGINE (HR ID MATCHING)       " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$CSVUsers = ConvertFrom-Csv -InputObject $OnboardingData

# 2. Process each HR record row-by-row
foreach ($User in $CSVUsers) {
    $BaseSAM = ($User.FirstName.Substring(0,1) + $User.LastName).ToLower()
    $BaseDisplayName = "$($User.FirstName) $($User.LastName)"
    
    Write-Host "[*] Processing Record:  [$($User.EmployeeID)] $BaseDisplayName..." -ForegroundColor Cyan
    
    # 3. CRITICAL SECURITY STEP: Query AD using the unique HR EmployeeID attribute
    $ExistingUser = Get-ADUser -Filter "EmployeeID -eq '$($User.EmployeeID)'" -ErrorAction SilentlyContinue
    
    # 4. THE DECISION GATEWAY
    if ($null -ne $ExistingUser) {
        # MATCH FOUND: This unique employee is already registered in the system.
        Write-Host "  [SKIPPED] Employee ID '$($User.EmployeeID)' already has an active account ($($ExistingUser.SamAccountName)). Skipping duplicate record safely..." -ForegroundColor Yellow
        
        $LogEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$($User.EmployeeID),$($ExistingUser.SamAccountName),$($User.Department),SKIPPED,""Employee ID matches an existing user profile."""
        $LogEntry | Out-File $LogPath -Append -Encoding utf8
        continue # Stop processing this row and immediately skip to the next person
    }

    # 5. USERNAME COLLISION LOOP (Only triggers for completely different people who happen to share a name format)
    $SAM = $BaseSAM
    $DisplayName = $BaseDisplayName
    $Counter = 1
    while (($null -ne (Get-ADUser -Filter "SamAccountName -eq '$SAM'" -ErrorAction SilentlyContinue)) -or 
           ($null -ne (Get-ADUser -Filter "Name -eq '$DisplayName'" -ErrorAction SilentlyContinue))) {
        $SAM = "$BaseSAM$Counter"
        $DisplayName = "$BaseDisplayName $Counter"
        $Counter++
    }

    # 6. LIVE PROVISIONING LAYER (Runs only for verified new employees)
    try {
        $SecurePassword = ConvertTo-SecureString "TempPassw0rd1!" -AsPlainText -Force
        
        New-ADUser -Name $DisplayName `
                   -GivenName $User.FirstName `
                   -Surname $User.LastName `
                   -SamAccountName $SAM `
                   -UserPrincipalName "$SAM@testlab.local" `
                   -Department $User.Department `
                   -Title $User.Title `
                   -EmployeeID $User.EmployeeID `
                   -Path "OU=Employees,DC=testlab,DC=local" `
                   -AccountPassword $SecurePassword `
                   -ChangePasswordAtLogon $true `
                   -Enabled $true `
                   -ErrorAction Stop
                   
        Write-Host "  [+] SUCCESS: Created new account $SAM for Employee ID $($User.EmployeeID)" -ForegroundColor Green
        $LogEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$($User.EmployeeID),$SAM,$($User.Department),SUCCESS,""Account provisioned cleanly."""
        $LogEntry | Out-File $LogPath -Append -Encoding utf8
    } 
    catch {
        Write-Host "  [-] ERROR: Failed to create $SAM. Reason: $_" -ForegroundColor Red
    }
}
Write-Host "====================================================" -ForegroundColor Cyan
