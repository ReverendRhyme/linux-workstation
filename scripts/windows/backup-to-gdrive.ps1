param(
    [string]$GoogleDriveRoot = "S:\My Drive",
    [string]$BackupName = "PRICK-Migration-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [switch]$IncludeDownloads,
    [ValidateRange(1, 100)]
    [int]$HashSamplePercent = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Test-RobocopySuccess {
    param([int]$ExitCode)
    return ($ExitCode -le 7)
}

function Get-DirStats {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ FileCount = 0; TotalBytes = 0 }
    }

    $files = Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue
    $count = ($files | Measure-Object).Count
    $bytes = ($files | Measure-Object -Property Length -Sum).Sum
    if (-not $bytes) { $bytes = 0 }

    return [pscustomobject]@{ FileCount = $count; TotalBytes = [int64]$bytes }
}

function Get-SampleHashes {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$Percent
    )

    $result = [ordered]@{
        Sampled = 0
        Matched = 0
        Mismatched = 0
        MissingAtDestination = 0
    }

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return [pscustomobject]$result
    }

    $sourceFiles = Get-ChildItem -LiteralPath $SourcePath -File -Recurse -Force -ErrorAction SilentlyContinue
    $totalFiles = ($sourceFiles | Measure-Object).Count
    if ($totalFiles -eq 0) {
        return [pscustomobject]$result
    }

    $sampleCount = [Math]::Max(1, [Math]::Floor($totalFiles * ($Percent / 100.0)))
    $sample = $sourceFiles | Get-Random -Count ([Math]::Min($sampleCount, $totalFiles))
    $result.Sampled = ($sample | Measure-Object).Count

    foreach ($file in $sample) {
        $relative = $file.FullName.Substring($SourcePath.Length).TrimStart('\\')
        $destFile = Join-Path $DestinationPath $relative

        if (-not (Test-Path -LiteralPath $destFile)) {
            $result.MissingAtDestination++
            continue
        }

        $srcHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $dstHash = (Get-FileHash -LiteralPath $destFile -Algorithm SHA256).Hash

        if ($srcHash -eq $dstHash) {
            $result.Matched++
        }
        else {
            $result.Mismatched++
        }
    }

    return [pscustomobject]$result
}

if (-not (Test-Path -LiteralPath $GoogleDriveRoot)) {
    throw "Google Drive root not found: $GoogleDriveRoot"
}

$backupRoot = Join-Path $GoogleDriveRoot $BackupName
$dataRoot = Join-Path $backupRoot "data"
$logRoot = Join-Path $backupRoot "logs"

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

Write-Info "Backup root: $backupRoot"
Write-Info "Log root: $logRoot"

$browserProcesses = @("chrome", "msedge", "firefox", "brave")
$runningBrowsers = Get-Process -ErrorAction SilentlyContinue | Where-Object { $browserProcesses -contains $_.ProcessName.ToLowerInvariant() }
if (($runningBrowsers | Measure-Object).Count -gt 0) {
    $names = ($runningBrowsers | Select-Object -ExpandProperty ProcessName -Unique) -join ", "
    Write-WarnMsg "Detected running browsers: $names"
    Write-WarnMsg "For best bookmark/profile consistency, close browsers and rerun this script."
}

$sources = @(
    # Core user data
    @{ Name = "Desktop"; Path = Join-Path $env:USERPROFILE "Desktop"; Required = $true; Type = "Directory" },
    @{ Name = "Documents"; Path = Join-Path $env:USERPROFILE "Documents"; Required = $true; Type = "Directory" },
    @{ Name = "Pictures"; Path = Join-Path $env:USERPROFILE "Pictures"; Required = $false; Type = "Directory" },
    @{ Name = "Videos"; Path = Join-Path $env:USERPROFILE "Videos"; Required = $false; Type = "Directory" },
    @{ Name = "Saved-Games"; Path = Join-Path $env:USERPROFILE "Saved Games"; Required = $false; Type = "Directory" },
    @{ Name = "OneDrive-Local"; Path = Join-Path $env:USERPROFILE "OneDrive"; Required = $false; Type = "Directory" },

    # Browser profiles (full) and explicit bookmark artifacts
    @{ Name = "Chrome-User-Data"; Path = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"; Required = $false; Type = "Directory" },
    @{ Name = "Edge-User-Data"; Path = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data"; Required = $false; Type = "Directory" },
    @{ Name = "Brave-User-Data"; Path = Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data"; Required = $false; Type = "Directory" },
    @{ Name = "Firefox-Profiles"; Path = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles"; Required = $false; Type = "Directory" },
    @{ Name = "Chrome-Bookmarks-Default"; Path = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Bookmarks"; Required = $false; Type = "File" },
    @{ Name = "Edge-Bookmarks-Default"; Path = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Default\Bookmarks"; Required = $false; Type = "File" },
    @{ Name = "Brave-Bookmarks-Default"; Path = Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data\Default\Bookmarks"; Required = $false; Type = "File" },

    # Gaming and launcher metadata
    @{ Name = "Steam-Userdata"; Path = Join-Path ${env:ProgramFiles(x86)} "Steam\userdata"; Required = $false; Type = "Directory" },
    @{ Name = "Steam-Library-Metadata"; Path = Join-Path ${env:ProgramFiles(x86)} "Steam\steamapps"; Required = $false; Type = "Directory" },
    @{ Name = "Epic-Data"; Path = Join-Path $env:PROGRAMDATA "Epic"; Required = $false; Type = "Directory" },
    @{ Name = "Epic-Launcher-Saved"; Path = Join-Path $env:LOCALAPPDATA "EpicGamesLauncher\Saved"; Required = $false; Type = "Directory" },
    @{ Name = "GOG-Galaxy"; Path = Join-Path $env:PROGRAMDATA "GOG.com\Galaxy\storage"; Required = $false; Type = "Directory" },

    # CAD / 3D printing settings and projects
    @{ Name = "Autodesk-Documents"; Path = Join-Path $env:USERPROFILE "Documents\Autodesk"; Required = $false; Type = "Directory" },
    @{ Name = "Fusion360-LocalData"; Path = Join-Path $env:LOCALAPPDATA "Autodesk\Autodesk Fusion 360"; Required = $false; Type = "Directory" },
    @{ Name = "Blender-Config"; Path = Join-Path $env:APPDATA "Blender Foundation\Blender"; Required = $false; Type = "Directory" },
    @{ Name = "OrcaSlicer"; Path = Join-Path $env:APPDATA "OrcaSlicer"; Required = $false; Type = "Directory" },
    @{ Name = "PrusaSlicer"; Path = Join-Path $env:APPDATA "PrusaSlicer"; Required = $false; Type = "Directory" },
    @{ Name = "Cura"; Path = Join-Path $env:APPDATA "cura"; Required = $false; Type = "Directory" },

    # Dev and credentials
    @{ Name = "SSH"; Path = Join-Path $env:USERPROFILE ".ssh"; Required = $false; Type = "Directory" },
    @{ Name = "GitConfig"; Path = Join-Path $env:USERPROFILE ".gitconfig"; Required = $false; Type = "File" },
    @{ Name = "PowerShell-Profile"; Path = Join-Path $env:USERPROFILE "Documents\PowerShell"; Required = $false; Type = "Directory" },
    @{ Name = "VSCode-User"; Path = Join-Path $env:APPDATA "Code\User"; Required = $false; Type = "Directory" },
    @{ Name = "Cursor-User"; Path = Join-Path $env:APPDATA "Cursor\User"; Required = $false; Type = "Directory" }
)

if ($IncludeDownloads.IsPresent) {
    $sources += @{ Name = "Downloads"; Path = Join-Path $env:USERPROFILE "Downloads"; Required = $false; Type = "Directory" }
}

$results = @()

foreach ($src in $sources) {
    $name = $src.Name
    $path = $src.Path
    $required = [bool]$src.Required
    $itemType = $src.Type

    $safeName = ($name -replace '[^A-Za-z0-9._-]', '_')
    $destPath = Join-Path $dataRoot $safeName
    $logPath = Join-Path $logRoot "$safeName-robocopy.log"

    if (-not (Test-Path -LiteralPath $path)) {
        $status = if ($required) { "MissingRequiredSource" } else { "SkippedMissingSource" }
        if ($required) {
            Write-WarnMsg "$name missing (required): $path"
        }
        else {
            Write-Info "$name missing (optional), skipping"
        }

        $results += [pscustomobject]@{
            Name = $name
            Source = $path
            Destination = $destPath
            ItemType = $itemType
            Status = $status
            SourceFileCount = 0
            SourceBytes = 0
            DestinationFileCount = 0
            DestinationBytes = 0
            HashSampled = 0
            HashMatched = 0
            HashMismatched = 0
            HashMissingDestination = 0
            RobocopyExitCode = $null
        }
        continue
    }

    if ($itemType -eq "Directory") {
        New-Item -ItemType Directory -Path $destPath -Force | Out-Null

        Write-Info "Copying $name"
        & robocopy $path $destPath /E /Z /R:2 /W:2 /MT:16 /COPY:DAT /DCOPY:DAT /XJ /NFL /NDL /NP /LOG+:$logPath | Out-Null
        $exitCode = $LASTEXITCODE

        $copyStatus = if (Test-RobocopySuccess -ExitCode $exitCode) { "Copied" } else { "CopyError" }
        if ($copyStatus -eq "Copied") {
            Write-Ok "$name copied (robocopy exit code: $exitCode)"
        }
        else {
            Write-WarnMsg "$name copy error (robocopy exit code: $exitCode)"
        }

        $srcStats = Get-DirStats -Path $path
        $dstStats = Get-DirStats -Path $destPath
        $hashStats = Get-SampleHashes -SourcePath $path -DestinationPath $destPath -Percent $HashSamplePercent

        $results += [pscustomobject]@{
            Name = $name
            Source = $path
            Destination = $destPath
            ItemType = $itemType
            Status = $copyStatus
            SourceFileCount = $srcStats.FileCount
            SourceBytes = $srcStats.TotalBytes
            DestinationFileCount = $dstStats.FileCount
            DestinationBytes = $dstStats.TotalBytes
            HashSampled = $hashStats.Sampled
            HashMatched = $hashStats.Matched
            HashMismatched = $hashStats.Mismatched
            HashMissingDestination = $hashStats.MissingAtDestination
            RobocopyExitCode = $exitCode
        }
    }
    else {
        New-Item -ItemType Directory -Path $destPath -Force | Out-Null
        $destFile = Join-Path $destPath (Split-Path $path -Leaf)
        Copy-Item -LiteralPath $path -Destination $destFile -Force
        Write-Ok "$name copied"

        $srcFileInfo = Get-Item -LiteralPath $path
        $dstFileInfo = Get-Item -LiteralPath $destFile
        $srcHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        $dstHash = (Get-FileHash -LiteralPath $destFile -Algorithm SHA256).Hash

        $results += [pscustomobject]@{
            Name = $name
            Source = $path
            Destination = $destFile
            ItemType = $itemType
            Status = if ($srcHash -eq $dstHash) { "Copied" } else { "HashMismatch" }
            SourceFileCount = 1
            SourceBytes = [int64]$srcFileInfo.Length
            DestinationFileCount = 1
            DestinationBytes = [int64]$dstFileInfo.Length
            HashSampled = 1
            HashMatched = if ($srcHash -eq $dstHash) { 1 } else { 0 }
            HashMismatched = if ($srcHash -eq $dstHash) { 0 } else { 1 }
            HashMissingDestination = 0
            RobocopyExitCode = $null
        }
    }
}

$appsOut = Join-Path $backupRoot "installed-apps.csv"
$uninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$apps = foreach ($regPath in $uninstallPaths) {
    Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object @{ Name = "DisplayName"; Expression = { $_.DisplayName } },
                      @{ Name = "DisplayVersion"; Expression = { $_.DisplayVersion } },
                      @{ Name = "Publisher"; Expression = { $_.Publisher } }
}

$apps | Sort-Object DisplayName -Unique | Export-Csv -LiteralPath $appsOut -NoTypeInformation -Encoding UTF8
Write-Ok "Installed apps exported: $appsOut"

$summaryOut = Join-Path $backupRoot "backup-summary.csv"
$manifestOut = Join-Path $backupRoot "backup-manifest.json"

$results | Export-Csv -LiteralPath $summaryOut -NoTypeInformation -Encoding UTF8

$failedRequired = ($results | Where-Object { $_.Status -eq "MissingRequiredSource" }).Count
$copyErrors = ($results | Where-Object { $_.Status -eq "CopyError" -or $_.Status -eq "HashMismatch" }).Count
$hashIssues = ($results | Where-Object { $_.HashMismatched -gt 0 -or $_.HashMissingDestination -gt 0 }).Count

$overall = if (($failedRequired -eq 0) -and ($copyErrors -eq 0) -and ($hashIssues -eq 0)) { "PASS" } else { "WARN" }

$manifest = [ordered]@{
    GeneratedAt = (Get-Date).ToString("o")
    GoogleDriveRoot = $GoogleDriveRoot
    BackupRoot = $backupRoot
    BackupName = $BackupName
    IncludeDownloads = [bool]$IncludeDownloads
    HashSamplePercent = $HashSamplePercent
    OverallStatus = $overall
    FailedRequiredSources = $failedRequired
    CopyErrors = $copyErrors
    HashIssues = $hashIssues
    Sources = $results
    Outputs = [ordered]@{
        SummaryCsv = $summaryOut
        ManifestJson = $manifestOut
        InstalledAppsCsv = $appsOut
        LogsDirectory = $logRoot
    }
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestOut -Encoding UTF8

Write-Host ""
Write-Host "=============================================="
Write-Host " Backup Complete"
Write-Host "=============================================="
Write-Host "Status: $overall"
Write-Host "Backup root: $backupRoot"
Write-Host "Summary: $summaryOut"
Write-Host "Manifest: $manifestOut"
Write-Host "Installed apps: $appsOut"

if ($overall -eq "PASS") {
    exit 0
}
else {
    Write-WarnMsg "Backup finished with warnings. Review summary and manifest before cutover."
    exit 2
}
