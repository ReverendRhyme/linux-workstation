param(
    [string]$GoogleDriveRoot = "S:\My Drive",
    [string]$BackupName = "PopOS-Migration-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [switch]$IncludeDownloads,
    [switch]$All,
    [switch]$PlanOnly,
    [switch]$NoCloudSkip,
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

function Get-FileStats {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ FileCount = 0; TotalBytes = 0 }
    }

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item) {
        return [pscustomobject]@{ FileCount = 0; TotalBytes = 0 }
    }

    return [pscustomobject]@{ FileCount = 1; TotalBytes = [int64]$item.Length }
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

function Get-NormalizedPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    try {
        $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
        return $resolved.TrimEnd('\\').ToLowerInvariant()
    }
    catch {
        try {
            return [System.IO.Path]::GetFullPath($Path).TrimEnd('\\').ToLowerInvariant()
        }
        catch {
            return $Path.TrimEnd('\\').ToLowerInvariant()
        }
    }
}

function Test-IsUnderPath {
    param(
        [string]$Child,
        [string]$Parent
    )

    if ([string]::IsNullOrWhiteSpace($Child) -or [string]::IsNullOrWhiteSpace($Parent)) {
        return $false
    }

    $childNorm = Get-NormalizedPath -Path $Child
    $parentNorm = Get-NormalizedPath -Path $Parent

    if ([string]::IsNullOrWhiteSpace($childNorm) -or [string]::IsNullOrWhiteSpace($parentNorm)) {
        return $false
    }

    if ($childNorm -eq $parentNorm) {
        return $true
    }

    return $childNorm.StartsWith("$parentNorm\\")
}

function Get-CloudRoots {
    $roots = @()

    $envCandidates = @(
        $env:OneDrive,
        $env:OneDriveCommercial,
        $env:OneDriveConsumer
    )

    foreach ($candidate in $envCandidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            $roots += $candidate
        }
    }

    $userGoogleCandidates = @(
        (Join-Path $env:USERPROFILE "Google Drive"),
        (Join-Path $env:USERPROFILE "My Drive")
    )

    foreach ($candidate in $userGoogleCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            $roots += $candidate
        }
    }

    $drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue
    foreach ($drive in $drives) {
        $root = [string]$drive.Root
        foreach ($suffix in @("My Drive", "Google Drive", "OneDrive")) {
            $candidate = Join-Path $root $suffix
            if (Test-Path -LiteralPath $candidate) {
                $roots += $candidate
            }
        }
    }

    return @($roots | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-LocalRoots {
    $roots = @(
        $env:USERPROFILE,
        $env:LOCALAPPDATA,
        $env:APPDATA,
        $env:PROGRAMDATA,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)}
    )

    return @($roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique)
}

function Get-CloudState {
    param(
        [string]$Path,
        [string[]]$CloudRoots,
        [string[]]$LocalRoots
    )

    foreach ($root in $CloudRoots) {
        if (Test-IsUnderPath -Child $Path -Parent $root) {
            return [pscustomobject]@{ State = "cloud_managed"; Reason = "under cloud root: $root" }
        }
    }

    $p = $Path.ToLowerInvariant()
    if ($p -match '\\onedrive(\\|$)' -or $p -match '\\google drive(\\|$)' -or $p -match '\\my drive(\\|$)') {
        return [pscustomobject]@{ State = "cloud_managed"; Reason = "path pattern indicates cloud sync" }
    }

    foreach ($root in $LocalRoots) {
        if (Test-IsUnderPath -Child $Path -Parent $root) {
            return [pscustomobject]@{ State = "local_only"; Reason = "under local root: $root" }
        }
    }

    if ($Path -match '^[A-Za-z]:\\') {
        return [pscustomobject]@{ State = "local_only"; Reason = "drive-letter local path" }
    }

    return [pscustomobject]@{ State = "unknown"; Reason = "not matched to known cloud or local roots" }
}

function Resolve-BackupAction {
    param(
        [bool]$AllMode,
        [string]$Tier,
        [string]$CloudState,
        [bool]$NoCloudSkipMode
    )

    if ($AllMode) {
        return [pscustomobject]@{ Action = "backup"; Reason = "all mode enabled" }
    }

    if ($Tier -eq "all") {
        return [pscustomobject]@{ Action = "skip"; Reason = "minimal mode excludes this source" }
    }

    if ($CloudState -eq "cloud_managed") {
        if ($NoCloudSkipMode) {
            return [pscustomobject]@{ Action = "backup"; Reason = "cloud skip override enabled" }
        }

        return [pscustomobject]@{ Action = "metadata_only"; Reason = "cloud-managed source; metadata-only by policy" }
    }

    if ($CloudState -eq "local_only") {
        return [pscustomobject]@{ Action = "backup"; Reason = "local-only source in minimal policy" }
    }

    return [pscustomobject]@{ Action = "skip"; Reason = "unknown source skipped by policy" }
}

function Write-DecisionPlan {
    param(
        [string]$JsonPath,
        [string]$MarkdownPath,
        [object[]]$Decisions,
        [string]$Mode,
        [bool]$AllMode,
        [bool]$PlanOnlyMode,
        [bool]$NoCloudSkipMode
    )

    $payload = [ordered]@{
        generated_at = (Get-Date).ToString("o")
        policy_mode = $Mode
        all_mode = $AllMode
        plan_only = $PlanOnlyMode
        no_cloud_skip = $NoCloudSkipMode
        decisions = $Decisions
    }

    $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $JsonPath -Encoding UTF8

    $md = @(
        "# Backup Decision Plan",
        "",
        "- Generated: $((Get-Date).ToString('o'))",
        "- Policy mode: $Mode",
        "- All mode: $AllMode",
        "- Plan only: $PlanOnlyMode",
        "- Cloud skip override: $NoCloudSkipMode",
        "",
        "| Name | Tier | Exists | Cloud state | Action | Reason |",
        "|---|---|---:|---|---|---|"
    )

    foreach ($d in $Decisions) {
        $md += "| $($d.Name) | $($d.Tier) | $($d.Exists) | $($d.CloudState) | $($d.Action) | $($d.DecisionReason) |"
    }

    $md | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8
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
Write-Info "Backup policy mode: $(if ($All.IsPresent) { 'all' } else { 'minimal' })"
if ($PlanOnly.IsPresent) {
    Write-WarnMsg "Plan-only mode enabled. No file copies will be performed."
}

$browserProcesses = @("chrome", "msedge", "firefox", "brave")
$runningBrowsers = Get-Process -ErrorAction SilentlyContinue | Where-Object { $browserProcesses -contains $_.ProcessName.ToLowerInvariant() }
if (($runningBrowsers | Measure-Object).Count -gt 0) {
    $names = ($runningBrowsers | Select-Object -ExpandProperty ProcessName -Unique) -join ", "
    Write-WarnMsg "Detected running browsers: $names"
    Write-WarnMsg "For best bookmark/profile consistency, close browsers and rerun this script."
}

$cloudRoots = Get-CloudRoots
$localRoots = Get-LocalRoots

Write-Info "Detected cloud roots: $((@($cloudRoots) -join '; '))"

$sources = @(
    # All mode only: likely already cloud-managed user folders and bulk payloads
    @{ Name = "Desktop"; Path = Join-Path $env:USERPROFILE "Desktop"; Required = $false; Type = "Directory"; Tier = "all" },
    @{ Name = "Documents"; Path = Join-Path $env:USERPROFILE "Documents"; Required = $false; Type = "Directory"; Tier = "all" },
    @{ Name = "Pictures"; Path = Join-Path $env:USERPROFILE "Pictures"; Required = $false; Type = "Directory"; Tier = "all" },
    @{ Name = "Videos"; Path = Join-Path $env:USERPROFILE "Videos"; Required = $false; Type = "Directory"; Tier = "all" },
    @{ Name = "OneDrive-Local"; Path = Join-Path $env:USERPROFILE "OneDrive"; Required = $false; Type = "Directory"; Tier = "all" },
    @{ Name = "Chrome-User-Data"; Path = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"; Required = $false; Type = "Directory"; Tier = "all" },
    @{ Name = "Edge-User-Data"; Path = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data"; Required = $false; Type = "Directory"; Tier = "all" },
    @{ Name = "Brave-User-Data"; Path = Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data"; Required = $false; Type = "Directory"; Tier = "all" },
    @{ Name = "Firefox-Profiles"; Path = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles"; Required = $false; Type = "Directory"; Tier = "all" },

    # Minimal policy: migration-critical settings and metadata
    @{ Name = "Saved-Games"; Path = Join-Path $env:USERPROFILE "Saved Games"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "Chrome-Bookmarks-Default"; Path = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Bookmarks"; Required = $false; Type = "File"; Tier = "minimal" },
    @{ Name = "Edge-Bookmarks-Default"; Path = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Default\Bookmarks"; Required = $false; Type = "File"; Tier = "minimal" },
    @{ Name = "Brave-Bookmarks-Default"; Path = Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data\Default\Bookmarks"; Required = $false; Type = "File"; Tier = "minimal" },
    @{ Name = "Steam-Userdata"; Path = Join-Path ${env:ProgramFiles(x86)} "Steam\userdata"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "Steam-Library-Metadata"; Path = Join-Path ${env:ProgramFiles(x86)} "Steam\steamapps"; Required = $false; Type = "Directory"; Tier = "minimal"; ExcludeDirsMinimal = @("common", "downloading", "shadercache", "workshop", "compatdata", "music") },
    @{ Name = "Epic-Data"; Path = Join-Path $env:PROGRAMDATA "Epic"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "Epic-Launcher-Saved"; Path = Join-Path $env:LOCALAPPDATA "EpicGamesLauncher\Saved"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "GOG-Galaxy"; Path = Join-Path $env:PROGRAMDATA "GOG.com\Galaxy\storage"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "Autodesk-Documents"; Path = Join-Path $env:USERPROFILE "Documents\Autodesk"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "Fusion360-LocalData"; Path = Join-Path $env:LOCALAPPDATA "Autodesk\Autodesk Fusion 360"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "Blender-Config"; Path = Join-Path $env:APPDATA "Blender Foundation\Blender"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "OrcaSlicer"; Path = Join-Path $env:APPDATA "OrcaSlicer"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "PrusaSlicer"; Path = Join-Path $env:APPDATA "PrusaSlicer"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "Cura"; Path = Join-Path $env:APPDATA "cura"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "SSH"; Path = Join-Path $env:USERPROFILE ".ssh"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "GitConfig"; Path = Join-Path $env:USERPROFILE ".gitconfig"; Required = $false; Type = "File"; Tier = "minimal" },
    @{ Name = "PowerShell-Profile"; Path = Join-Path $env:USERPROFILE "Documents\PowerShell"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "VSCode-User"; Path = Join-Path $env:APPDATA "Code\User"; Required = $false; Type = "Directory"; Tier = "minimal" },
    @{ Name = "Cursor-User"; Path = Join-Path $env:APPDATA "Cursor\User"; Required = $false; Type = "Directory"; Tier = "minimal" }
)

if ($IncludeDownloads.IsPresent) {
    $downloadsTier = if ($All.IsPresent) { "all" } else { "minimal" }
    $sources += @{ Name = "Downloads"; Path = Join-Path $env:USERPROFILE "Downloads"; Required = $false; Type = "Directory"; Tier = $downloadsTier }
}

$decisionPlan = @()
$results = @()

foreach ($src in $sources) {
    $name = $src.Name
    $path = $src.Path
    $required = [bool]$src.Required
    $itemType = $src.Type
    $tier = [string]$src.Tier

    $safeName = ($name -replace '[^A-Za-z0-9._-]', '_')
    $destPath = Join-Path $dataRoot $safeName
    $logPath = Join-Path $logRoot "$safeName-robocopy.log"

    $exists = Test-Path -LiteralPath $path
    $cloudInfo = Get-CloudState -Path $path -CloudRoots $cloudRoots -LocalRoots $localRoots
    $decision = Resolve-BackupAction -AllMode ([bool]$All.IsPresent) -Tier $tier -CloudState $cloudInfo.State -NoCloudSkipMode ([bool]$NoCloudSkip.IsPresent)

    $decisionPlan += [pscustomobject]@{
        Name = $name
        Source = $path
        Tier = $tier
        Exists = [bool]$exists
        CloudState = $cloudInfo.State
        CloudReason = $cloudInfo.Reason
        Action = $decision.Action
        DecisionReason = $decision.Reason
    }

    if (-not $exists) {
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
            Tier = $tier
            CloudState = $cloudInfo.State
            Action = $decision.Action
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
            DecisionReason = "$($cloudInfo.Reason); $($decision.Reason)"
        }
        continue
    }

    if ($decision.Action -eq "skip") {
        Write-Info "$name skipped by policy ($($decision.Reason))"

        $results += [pscustomobject]@{
            Name = $name
            Source = $path
            Destination = $destPath
            ItemType = $itemType
            Tier = $tier
            CloudState = $cloudInfo.State
            Action = $decision.Action
            Status = if ($PlanOnly.IsPresent) { "PlannedSkip" } else { "SkippedByPolicy" }
            SourceFileCount = 0
            SourceBytes = 0
            DestinationFileCount = 0
            DestinationBytes = 0
            HashSampled = 0
            HashMatched = 0
            HashMismatched = 0
            HashMissingDestination = 0
            RobocopyExitCode = $null
            DecisionReason = "$($cloudInfo.Reason); $($decision.Reason)"
        }
        continue
    }

    if ($decision.Action -eq "metadata_only") {
        Write-Info "$name metadata-only by policy"

        $srcStats = if ($itemType -eq "Directory") { Get-DirStats -Path $path } else { Get-FileStats -Path $path }

        $results += [pscustomobject]@{
            Name = $name
            Source = $path
            Destination = $destPath
            ItemType = $itemType
            Tier = $tier
            CloudState = $cloudInfo.State
            Action = $decision.Action
            Status = if ($PlanOnly.IsPresent) { "PlannedMetadataOnly" } else { "MetadataOnly" }
            SourceFileCount = $srcStats.FileCount
            SourceBytes = $srcStats.TotalBytes
            DestinationFileCount = 0
            DestinationBytes = 0
            HashSampled = 0
            HashMatched = 0
            HashMismatched = 0
            HashMissingDestination = 0
            RobocopyExitCode = $null
            DecisionReason = "$($cloudInfo.Reason); $($decision.Reason)"
        }
        continue
    }

    if ($PlanOnly.IsPresent) {
        Write-Info "$name planned for backup"
        $srcStats = if ($itemType -eq "Directory") { Get-DirStats -Path $path } else { Get-FileStats -Path $path }

        $results += [pscustomobject]@{
            Name = $name
            Source = $path
            Destination = $destPath
            ItemType = $itemType
            Tier = $tier
            CloudState = $cloudInfo.State
            Action = $decision.Action
            Status = "PlannedBackup"
            SourceFileCount = $srcStats.FileCount
            SourceBytes = $srcStats.TotalBytes
            DestinationFileCount = 0
            DestinationBytes = 0
            HashSampled = 0
            HashMatched = 0
            HashMismatched = 0
            HashMissingDestination = 0
            RobocopyExitCode = $null
            DecisionReason = "$($cloudInfo.Reason); $($decision.Reason)"
        }
        continue
    }

    if ($itemType -eq "Directory") {
        New-Item -ItemType Directory -Path $destPath -Force | Out-Null

        Write-Info "Copying $name"

        $robocopyArgs = @(
            $path,
            $destPath,
            "/E",
            "/Z",
            "/R:2",
            "/W:2",
            "/MT:16",
            "/COPY:DAT",
            "/DCOPY:DAT",
            "/XJ",
            "/NFL",
            "/NDL",
            "/NP",
            "/LOG+:$logPath"
        )

        if ((-not $All.IsPresent) -and $src.ContainsKey("ExcludeDirsMinimal")) {
            $excludePaths = @($src.ExcludeDirsMinimal | ForEach-Object { Join-Path $path $_ })
            if ($excludePaths.Count -gt 0) {
                $robocopyArgs += "/XD"
                $robocopyArgs += $excludePaths
            }
        }

        & robocopy @robocopyArgs | Out-Null
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
            Tier = $tier
            CloudState = $cloudInfo.State
            Action = $decision.Action
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
            DecisionReason = "$($cloudInfo.Reason); $($decision.Reason)"
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
            Tier = $tier
            CloudState = $cloudInfo.State
            Action = $decision.Action
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
            DecisionReason = "$($cloudInfo.Reason); $($decision.Reason)"
        }
    }
}

$decisionPlanOutJson = Join-Path $backupRoot "backup-decision-plan.json"
$decisionPlanOutMd = Join-Path $backupRoot "backup-decision-plan.md"
Write-DecisionPlan -JsonPath $decisionPlanOutJson -MarkdownPath $decisionPlanOutMd -Decisions $decisionPlan -Mode $(if ($All.IsPresent) { "all" } else { "minimal" }) -AllMode ([bool]$All.IsPresent) -PlanOnlyMode ([bool]$PlanOnly.IsPresent) -NoCloudSkipMode ([bool]$NoCloudSkip.IsPresent)

$appsOut = Join-Path $backupRoot "installed-apps.csv"
$uninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$apps = foreach ($regPath in $uninstallPaths) {
    Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PSObject.Properties['DisplayName'] -and
            -not [string]::IsNullOrWhiteSpace([string]$_.DisplayName)
        } |
        Select-Object @{ Name = "DisplayName"; Expression = { $_.DisplayName } },
                      @{ Name = "DisplayVersion"; Expression = { $_.DisplayVersion } },
                      @{ Name = "Publisher"; Expression = { $_.Publisher } }
}

$apps | Sort-Object DisplayName -Unique | Export-Csv -LiteralPath $appsOut -NoTypeInformation -Encoding UTF8
Write-Ok "Installed apps exported: $appsOut"

$summaryOut = Join-Path $backupRoot "backup-summary.csv"
$manifestOut = Join-Path $backupRoot "backup-manifest.json"

$results | Export-Csv -LiteralPath $summaryOut -NoTypeInformation -Encoding UTF8

$failedRequired = @($results | Where-Object { $_.Status -eq "MissingRequiredSource" }).Count
$copyErrors = @($results | Where-Object { $_.Status -eq "CopyError" -or $_.Status -eq "HashMismatch" }).Count
$hashIssues = @($results | Where-Object { $_.HashMismatched -gt 0 -or $_.HashMissingDestination -gt 0 }).Count

$overall = if ($PlanOnly.IsPresent) {
    "PLAN"
}
elseif (($failedRequired -eq 0) -and ($copyErrors -eq 0) -and ($hashIssues -eq 0)) {
    "PASS"
}
else {
    "WARN"
}

$manifest = [ordered]@{
    GeneratedAt = (Get-Date).ToString("o")
    GoogleDriveRoot = $GoogleDriveRoot
    BackupRoot = $backupRoot
    BackupName = $BackupName
    IncludeDownloads = [bool]$IncludeDownloads
    AllMode = [bool]$All.IsPresent
    PlanOnly = [bool]$PlanOnly.IsPresent
    NoCloudSkip = [bool]$NoCloudSkip.IsPresent
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
        DecisionPlanJson = $decisionPlanOutJson
        DecisionPlanMarkdown = $decisionPlanOutMd
        LogsDirectory = $logRoot
    }
}

$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestOut -Encoding UTF8

Write-Host ""
Write-Host "=============================================="
Write-Host " Backup Complete"
Write-Host "=============================================="
Write-Host "Status: $overall"
Write-Host "Backup root: $backupRoot"
Write-Host "Summary: $summaryOut"
Write-Host "Manifest: $manifestOut"
Write-Host "Decision plan (json): $decisionPlanOutJson"
Write-Host "Decision plan (md): $decisionPlanOutMd"
Write-Host "Installed apps: $appsOut"

if ($PlanOnly.IsPresent -or $overall -eq "PASS") {
    exit 0
}
else {
    Write-WarnMsg "Backup finished with warnings. Review summary and manifest before cutover."
    exit 2
}
