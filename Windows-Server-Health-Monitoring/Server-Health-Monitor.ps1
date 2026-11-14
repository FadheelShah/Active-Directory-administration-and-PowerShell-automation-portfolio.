#requires -Version 5.1
<#
.SYNOPSIS
    Collects read-only health information from the local Windows Server.
.DESCRIPTION
    Measures CPU, RAM, local fixed disks, uptime, selected Windows services,
    and recent critical/error System events. Generates an HTML report using
    the separate Templates\Health-Report.html file.
    Does not modify Active Directory, DNS, IIS, or Windows services.
#>
[CmdletBinding()]
param(
    [ValidateRange(2,60)][int]$CpuSamples = 5,
    [ValidateRange(1,30)][int]$CpuIntervalSeconds = 2,
    [ValidateRange(1,100)][double]$CpuWarningPercent = 85,
    [ValidateRange(1,100)][double]$MemoryWarningPercent = 85,
    [ValidateRange(1,100)][double]$DiskWarningPercent = 85,
    [ValidateRange(1,168)][int]$EventLookbackHours = 24,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'

# Convert values to HTML-safe text before inserting them into the template.
function ConvertTo-HtmlText {

    param([AllowNull()][object]$Value)

    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

# Render a simple status pill. Only fixed status names are allowed in CSS classes.
function New-StatusHtml {
    param([string]$Status)

    if ($Status -notin @('HEALTHY','WARNING','CRITICAL','UNKNOWN')) { 
        $Status = 'UNKNOWN' 
    }
    return '<span class="status {0}">{0}</span>' -f $Status
}

# A failed measurement must be UNKNOWN, never silently treated as HEALTHY.
function Get-ThresholdStatus {
    param(
        [AllowNull()][object]$Value, 
        [double]$WarningThreshold
     )

    # Missing measurements should not be marked healthy
    if ($null -eq $Value) {
        return 'UNKNOWN' 
    }

    if ([double]$Value -ge $WarningThreshold) { 
        return 'WARNING' 
    }
    return 'HEALTHY'
}

# Add a labelled dashboard card without mixing monitoring logic with HTML layout.
function New-MetricCard {
    param([string]$Title, [string]$Value, [string]$Status, [string]$Details)
    $safeTitle = ConvertTo-HtmlText $Title
    $safeValue = ConvertTo-HtmlText $Value
    $safeDetails = ConvertTo-HtmlText $Details
    $statusHtml = New-StatusHtml $Status
    return '<section class="card"><h2>{0}</h2><div class="value">{1}</div>{2}<p class="details">{3}</p></section>' -f $safeTitle,$safeValue,$statusHtml,$safeDetails
}

# Use paths relative to the script so it runs from ISE or any working directory.
$root = $PSScriptRoot
$templatePath = Join-Path $root 'Templates\Health-Report.html'
$reportsPath = Join-Path $root 'Reports'
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    throw "HTML template not found: $templatePath"
}
if (-not (Test-Path -LiteralPath $reportsPath -PathType Container)) {
    New-Item -Path $reportsPath -ItemType Directory -Force | Out-Null
}

# Fiji time is for display; Windows event queries use the local DateTime comparison.
$fijiZone = [TimeZoneInfo]::FindSystemTimeZoneById('Fiji Standard Time')
$startedUtc = [DateTime]::UtcNow
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$computer = Get-CimInstance -ClassName Win32_ComputerSystem

# CPU: performance counter samples reflect activity during each interval.
# Get-Counter returns cooked percentage values, rather than WMI LoadPercentage estimates.
$cpuAverage = $null
$cpuPeak = $null
$cpuNote = ''
try {
    $counter = Get-Counter -Counter '\Processor(_Total)\% Processor Time' -SampleInterval $CpuIntervalSeconds -MaxSamples $CpuSamples -ErrorAction Stop
    $cpuValues = @($counter | ForEach-Object { $_.CounterSamples[0].CookedValue } | Where-Object { $null -ne $_ -and -not [double]::IsNaN([double]$_) })
    if ($cpuValues.Count -eq 0) { throw 'No valid CPU samples returned.' }
    $cpuAverage = [math]::Round(($cpuValues | Measure-Object -Average).Average, 1)
    $cpuPeak = [math]::Round(($cpuValues | Measure-Object -Maximum).Maximum, 1)
    $cpuNote = '{0} samples at {1}-second intervals; peak {2}%; warning at {3}%' -f $cpuValues.Count,$CpuIntervalSeconds,$cpuPeak,$CpuWarningPercent
}
catch {
    $cpuNote = 'CPU collection failed: ' + $_.Exception.Message
}
$cpuStatus = Get-ThresholdStatus $cpuAverage $CpuWarningPercent

# RAM: WMI reports total and available physical memory in KiB.
$memoryPercent = $null
$memoryNote = ''
try {
    if ($os.TotalVisibleMemorySize -le 0) { throw 'Total memory is invalid.' }
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $availableGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
    $memoryPercent = [math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
    $memoryNote = 'Used {0} GB of {1} GB; available {2} GB; warning at {3}%' -f $usedGB,$totalGB,$availableGB,$MemoryWarningPercent
}
catch { $memoryNote = 'Memory collection failed: ' + $_.Exception.Message }
$memoryStatus = Get-ThresholdStatus $memoryPercent $MemoryWarningPercent

# Fixed local volumes: check capacity; no files are created or deleted on drives.
$diskCards = @()
$diskStatuses = @()
try {
    $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3')
    if ($disks.Count -eq 0) { throw 'No fixed disks returned.' }
    foreach ($disk in $disks) {
        $pct = $null
        $detail = 'Capacity unavailable'
        if ($disk.Size -gt 0 -and $null -ne $disk.FreeSpace) {
            $pct = [math]::Round((1 - ($disk.FreeSpace / $disk.Size)) * 100, 1)
            $detail = 'Free {0:N2} GB of {1:N2} GB; warning at {2}%' -f ($disk.FreeSpace / 1GB),($disk.Size / 1GB),$DiskWarningPercent
        }
        $status = Get-ThresholdStatus $pct $DiskWarningPercent
        $diskStatuses += $status
        $display = if ($null -eq $pct) { 'N/A' } else { "$pct%" }
        $diskCards += New-MetricCard "Disk $($disk.DeviceID)" $display $status $detail
    }
}
catch {
    $diskStatuses += 'UNKNOWN'
    $diskCards += New-MetricCard 'Disk Capacity' 'N/A' 'UNKNOWN' $_.Exception.Message
}

# Uptime: based on Windows' last boot timestamp, not a guessed health threshold.
$uptimeText = 'N/A'
$uptimeStatus = 'UNKNOWN'
$uptimeDetail = 'Last boot time unavailable'
try {
    $boot = [datetime]$os.LastBootUpTime
    $uptime = (Get-Date) - $boot
    if ($uptime.TotalSeconds -lt 0) { throw 'Last boot time is in the future.' }
    $uptimeText = '{0}d {1}h' -f [math]::Floor($uptime.TotalDays),$uptime.Hours
    $uptimeDetail = 'Last boot: ' + $boot.ToString('yyyy-MM-dd HH:mm:ss') + ' (server local time)'
    $uptimeStatus = 'HEALTHY' # Informational only: uptime alone does not establish health.
}
catch { $uptimeDetail = $_.Exception.Message }

# Service checks: monitor services relevant to this lab; never start/stop them.
# W3SVC is IIS web publishing; NTDS is AD DS; DNS is the DNS Server service.
$serviceNames = @('NTDS','DNS','W3SVC')
$serviceRows = @()
$serviceStatuses = @()
foreach ($serviceName in $serviceNames) {
    try {
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        $state = [string]$service.Status
        $status = if ($state -eq 'Running') { 'HEALTHY' } else { 'WARNING' }
    }
    catch {
        $state = 'Not found / inaccessible'
        $status = 'UNKNOWN'
    }
    $serviceStatuses += $status
    $serviceRows += '<tr><td>{0}</td><td>{1}</td><td>{2}</td></tr>' -f (ConvertTo-HtmlText $serviceName),(ConvertTo-HtmlText $state),(New-StatusHtml $status)
}

# Events: count System log Level 1 (Critical) and Level 2 (Error) entries.
# Events are investigation signals, not proof that the server is currently unhealthy.
$eventStatus = 'UNKNOWN'
$eventCountText = 'N/A'
$eventDetail = ''
try {
    $since = (Get-Date).AddHours(-$EventLookbackHours)
    $events = @(Get-WinEvent -FilterHashtable @{ LogName='System'; Level=1,2; StartTime=$since } -ErrorAction Stop)
    $eventCountText = [string]$events.Count
    $eventStatus = if ($events.Count -gt 0) { 'WARNING' } else { 'HEALTHY' }
    $eventDetail = "System Critical/Error events in last $EventLookbackHours hours (requires review)"
}
catch {
    # Get-WinEvent throws when no matching events exist; distinguish that case.
    if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*' -or $_.Exception.Message -match 'No events were found') {
        $eventCountText = '0'
        $eventStatus = 'HEALTHY'
        $eventDetail = "No matching System Critical/Error events in last $EventLookbackHours hours"
    }
    else { $eventDetail = 'Event log query failed: ' + $_.Exception.Message }
}

# Overall status: UNKNOWN data cannot be represented as a clean bill of health.
$allStatuses = @($cpuStatus,$memoryStatus,$uptimeStatus,$eventStatus) + $diskStatuses + $serviceStatuses
$overallStatus = if ('WARNING' -in $allStatuses -or 'CRITICAL' -in $allStatuses) { 'WARNING' }
                 elseif ('UNKNOWN' -in $allStatuses) { 'UNKNOWN' }
                 else { 'HEALTHY' }

# Prepare dashboard sections; the HTML and CSS live in the template file.
$cpuText = if ($null -eq $cpuAverage) { 'N/A' } else { "$cpuAverage%" }
$memText = if ($null -eq $memoryPercent) { 'N/A' } else { "$memoryPercent%" }
$cards = @(
    (New-MetricCard 'CPU Average' $cpuText $cpuStatus $cpuNote),
    (New-MetricCard 'Memory Used' $memText $memoryStatus $memoryNote)
) + $diskCards + @(
    (New-MetricCard 'Server Uptime' $uptimeText $uptimeStatus $uptimeDetail),
    (New-MetricCard 'System Events' $eventCountText $eventStatus $eventDetail)
)

# Replace explicit template placeholders; never execute HTML as PowerShell code.
$fijiFinished = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow,$fijiZone)
$durationSeconds = [math]::Round(([DateTime]::UtcNow - $startedUtc).TotalSeconds,1)
$tokens = @{
    '{{HOSTNAME}}' = ConvertTo-HtmlText $computer.Name
    '{{TIMESTAMP}}' = ConvertTo-HtmlText ($fijiFinished.ToString('yyyy-MM-dd HH:mm:ss') + ' Fiji (UTC+12)')
    '{{OVERALL_STATUS}}' = New-StatusHtml $overallStatus
    '{{CARDS}}' = ($cards -join "`r`n")
    '{{SERVICE_ROWS}}' = ($serviceRows -join "`r`n")
    '{{DURATION}}' = [string]$durationSeconds
}
$html = [System.IO.File]::ReadAllText($templatePath)
foreach ($token in $tokens.Keys) { $html = $html.Replace($token,[string]$tokens[$token]) }

# Store each run as a timestamped HTML evidence file; do not overwrite old reports.
$reportFile = 'Server-Health-{0}.html' -f $fijiFinished.ToString('yyyy-MM-dd-HH-mm-ss')
$reportPath = Join-Path $reportsPath $reportFile
[System.IO.File]::WriteAllText($reportPath,$html,[System.Text.UTF8Encoding]::new($false))
Write-Host ('Overall: {0} | CPU: {1} | Memory: {2}' -f $overallStatus,$cpuText,$memText)
Write-Host ('Elapsed: {0} seconds | Report: {1}' -f $durationSeconds,$reportPath)
if (-not $NoBrowser) { Start-Process -FilePath $reportPath }
