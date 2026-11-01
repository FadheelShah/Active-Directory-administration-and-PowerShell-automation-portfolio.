<#
.SYNOPSIS
    Enterprise Single-User Active Directory Provisioning Utility with HR ID Validation.
.DESCRIPTION
    Takes external command parameters to safely onboard an individual employee, dynamically 
    checking for pre-existing Employee IDs and resolving naming collisions.
.NOTES
    Author: Fadheel Ahmed Shah
    Test Environment: VM Server 2022 created in Oracle VB
#>

# 1. ENTERPRISE PARAMETER INTERFACE (Now including mandatory Employee ID)
param (
    [Parameter(Mandatory=$true)]
    [string]$EmployeeID,

    [Parameter(Mandatory=$true)]
    [string]$FirstName,

    [Parameter(Mandatory=$true)]
    [string]$LastName,

    [Parameter(Mandatory=$true)]
    [string]$Department,

    [Parameter(Mandatory=$true)]
    [string]$Title
)

# Explicitly ensure the native Active Directory module is loaded
Import-Module ActiveDirectory -ErrorAction Stop

# 2. DYNAMIC IDENTITY STRINGS GENERATION
$BaseSAM = ($FirstName.Substring(0,1) + $LastName).ToLower()
$BaseDisplayName = "$FirstName $LastName"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "       SINGLE-USER PROVISIONING INTERFACE           " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "[*] Evaluating directory availability for Employee ID: $EmployeeID..." -ForegroundColor Yellow

# 3. CRITICAL HR ID PRE-CHECK
$ExistingUser = Get-ADUser -Filter "EmployeeID -eq '$EmployeeID'" -ErrorAction SilentlyContinue

if ($null -ne $ExistingUser) {
    Write-Host "  [!] ABORT: Employee ID '$EmployeeID' already exists in Active Directory!" -ForegroundColor Red
    Write-Host "  [!] Account is bound to pre-existing profile: $($ExistingUser.SamAccountName). Exiting..." -ForegroundColor Red
    Write-Host "====================================================" -ForegroundColor Cyan
    return # Terminate execution safely without making changes
}

# 4. USERNAME & DISPLAY NAME COLLISION LOOP
$SAM = $BaseSAM
$DisplayName = $BaseDisplayName
$Counter = 1

# Keep looping if EITHER the login handle OR the folder display name is already in use
while (($null -ne (Get-ADUser -Filter "SamAccountName -eq '$SAM'" -ErrorAction SilentlyContinue)) -or 
       ($null -ne (Get-ADUser -Filter "Name -eq '$DisplayName'" -ErrorAction SilentlyContinue))) {
    
    Write-Host "  [!] Name conflict detected for handle '$SAM' or folder object '$DisplayName'." -ForegroundColor Yellow
    
    # Append the counter to keep assets perfectly unique
    $SAM = "$BaseSAM$Counter"
    $DisplayName = "$BaseDisplayName $Counter"
    $Counter++
    
    Write-Host "  [*] Retrying with alternative handle configuration: $DisplayName ($SAM)..." -ForegroundColor Gray
}

# 5. LIVE TARGETED PROVISIONING LAYER
Write-Host "  [+] Identity cleared. Deploying account asset..." -ForegroundColor Green

# Generate secure, encrypted corporate baseline password asset
$SecurePassword = ConvertTo-SecureString "TempPassw0rd1!" -AsPlainText -Force

# Target deployment command executing against our specific VM compartment
New-ADUser -Name $DisplayName `
           -GivenName $FirstName `
           -Surname $LastName `
           -SamAccountName $SAM `
           -UserPrincipalName "$SAM@testlab.local" `
           -Department $Department `
           -Title $Title `
           -EmployeeID $EmployeeID `
           -Path "OU=Employees,DC=testlab,DC=local" `
           -AccountPassword $SecurePassword `
           -ChangePasswordAtLogon $true `
           -Enabled $true
           
Write-Host "  [SUCCESS] Employee ID '$EmployeeID' cleanly provisioned as username: $SAM!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
