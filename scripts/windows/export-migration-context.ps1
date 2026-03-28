param(
    [string]$OutputDir,
    [switch]$Sanitize = $true,
    [string]$BackupManifestPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function New-SafeId {
    param([string]$Text)
    return (($Text -replace '[^A-Za-z0-9_-]', '-') -replace '-+', '-').Trim('-').ToLowerInvariant()
}

function Get-ShortHash {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hashBytes = $sha.ComputeHash($bytes)
    $hex = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
    return $hex.Substring(0, 12)
}

function Get-InstalledApps {
    $uninstallPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $apps = foreach ($regPath in $uninstallPaths) {
        Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object @{ Name = "Name"; Expression = { $_.DisplayName } },
                          @{ Name = "Version"; Expression = { $_.DisplayVersion } },
                          @{ Name = "Publisher"; Expression = { $_.Publisher } }
    }

    return $apps | Sort-Object Name -Unique
}

function Get-DriveIntent {
    $logical = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        [ordered]@{
            letter = [string]$_.DeviceID
            label = [string]$_.VolumeName
            fs = [string]$_.FileSystem
            size_gb = if ($_.Size) { [Math]::Round(([float]$_.Size / 1GB), 2) } else { 0 }
            free_gb = if ($_.FreeSpace) { [Math]::Round(([float]$_.FreeSpace / 1GB), 2) } else { 0 }
        }
    }

    $systemDrive = $env:SystemDrive
    $nonSystem = @($logical | Where-Object { $_.letter -ne $systemDrive })

    $installMode = "fresh"
    if ($nonSystem.Count -gt 0) {
        $installMode = "dualboot"
    }

    [ordered]@{
        install_mode = $installMode
        system_drive = $systemDrive
        logical_drives = @($logical)
    }
}

function Get-SteamLibraries {
    $libraries = @()
    $defaultSteam = "C:\Program Files (x86)\Steam\steamapps"
    if (Test-Path -LiteralPath $defaultSteam) {
        $libraries += $defaultSteam
    }

    $vdfPath = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
    if (Test-Path -LiteralPath $vdfPath) {
        $content = Get-Content -LiteralPath $vdfPath -ErrorAction SilentlyContinue
        foreach ($line in $content) {
            if ($line -match '"path"\s+"([^"]+)"') {
                $path = $matches[1] -replace '\\\\', '\\'
                if ($path) {
                    $libraries += (Join-Path $path "steamapps")
                }
            }
        }
    }

    return @($libraries | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-DriveLetterFromPath {
    param([string]$Path)
    if ($Path -match '^[A-Za-z]:') {
        return $Path.Substring(0, 2).ToUpperInvariant()
    }
    return ""
}

function Map-LinuxTarget {
    param([string]$Name)

    $n = $Name.ToLowerInvariant()

    $gamingPattern = 'steam|heroic|epic|gog|discord|obs|vlc|proton|mangohud|gamemode'
    $devPattern = 'docker|git|python|visual studio code|cursor|powershell|node|npm|jetbrains'
    $cadPattern = 'blender|freecad|openscad|meshlab|solidworks'
    $printingPattern = 'cura|prusaslicer|bambu|orca|chitubox'

    if ($n -match $gamingPattern) {
        return @{ category = "gaming"; linux_target = "native"; install_method = "ansible"; notes = "Expected from gaming/base roles" }
    }
    if ($n -match $devPattern) {
        return @{ category = "dev"; linux_target = "native"; install_method = "ansible"; notes = "Expected from dev/base roles" }
    }
    if ($n -match 'fusion 360|autodesk') {
        return @{ category = "cad"; linux_target = "wine"; install_method = "optional-fusion360"; notes = "Enable USE_FUSION360=yes if needed" }
    }
    if ($n -match $cadPattern) {
        return @{ category = "cad"; linux_target = "native"; install_method = "ansible"; notes = "Expected from cad role" }
    }
    if ($n -match $printingPattern) {
        return @{ category = "printing"; linux_target = "native"; install_method = "ansible"; notes = "Expected from printing role" }
    }
    if ($n -match '1password|slack|zoom|obsidian|spotify') {
        return @{ category = "productivity"; linux_target = "flatpak"; install_method = "ansible-flatpak"; notes = "Expected from base role" }
    }
    if ($n -match 'office|onenote|outlook') {
        return @{ category = "productivity"; linux_target = "web"; install_method = "manual"; notes = "Prefer web or LibreOffice" }
    }
    if ($n -match 'armoury|armor|nahimic|rgb') {
        return @{ category = "vendor"; linux_target = "skip"; install_method = "none"; notes = "Vendor suite usually not needed" }
    }

    return @{ category = "other"; linux_target = "manual"; install_method = "review"; notes = "Review replacement manually" }
}

$rawMachine = $env:COMPUTERNAME
$machineId = if ($Sanitize.IsPresent) { "win-$(Get-ShortHash $rawMachine)" } else { New-SafeId $rawMachine }

if (-not $OutputDir) {
    $OutputDir = Join-Path (Resolve-Path ".") "migration/context/$machineId"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Write-Info "Output directory: $OutputDir"

$osInfo = Get-CimInstance Win32_OperatingSystem
$cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpuInfo = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
$driveIntent = Get-DriveIntent
$steamLibraries = Get-SteamLibraries
$memBytes = [float]$osInfo.TotalVisibleMemorySize * 1024
$memoryGb = [Math]::Round($memBytes / 1GB, 2)

$disks = Get-CimInstance Win32_DiskDrive | ForEach-Object {
    [ordered]@{
        model = if ($Sanitize.IsPresent) { "redacted" } else { $_.Model }
        size_gb = [Math]::Round(([float]$_.Size / 1GB), 2)
        bus_type = $_.InterfaceType
        media_type = $_.MediaType
    }
}

$machineProfile = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    machine_id = $machineId
    sanitized = [bool]$Sanitize.IsPresent
    os = [ordered]@{
        name = $osInfo.Caption
        version = $osInfo.Version
    }
    cpu = if ($Sanitize.IsPresent) { "redacted" } else { $cpuInfo.Name }
    gpu = if ($Sanitize.IsPresent) { @("redacted") } else { @($gpuInfo) }
    memory_gb = $memoryGb
    storage = @($disks)
}

$apps = Get-InstalledApps
$softwareMapItems = foreach ($app in $apps) {
    $mapped = Map-LinuxTarget -Name $app.Name
    [ordered]@{
        name = $app.Name
        version = [string]$app.Version
        publisher = [string]$app.Publisher
        category = $mapped.category
        linux_target = $mapped.linux_target
        install_method = $mapped.install_method
        notes = $mapped.notes
    }
}

$softwareMap = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    apps = @($softwareMapItems)
}

$paths = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    backup_root = if ($BackupManifestPath) { Split-Path -Parent $BackupManifestPath } else { "<set-after-backup>" }
    install_mode = $driveIntent.install_mode
    system_drive = $driveIntent.system_drive
    logical_drives = @($driveIntent.logical_drives)
    steam_libraries = @($steamLibraries)
    browser_profiles = @(
        @{ name = "Chrome"; path = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
        @{ name = "Edge"; path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
        @{ name = "Firefox"; path = "$env:APPDATA\Mozilla\Firefox\Profiles" }
    )
    dev_paths = @(
        "$env:USERPROFILE\.ssh",
        "$env:USERPROFILE\.gitconfig",
        "$env:APPDATA\Code\User",
        "$env:APPDATA\Cursor\User"
    )
}

$hasGamingApps = ($softwareMapItems | Where-Object { $_.category -eq 'gaming' } | Measure-Object).Count -gt 0
$hasDevApps = ($softwareMapItems | Where-Object { $_.category -eq 'dev' } | Measure-Object).Count -gt 0
$hasCadApps = ($softwareMapItems | Where-Object { $_.category -eq 'cad' } | Measure-Object).Count -gt 0
$hasPrintingApps = ($softwareMapItems | Where-Object { $_.category -eq 'printing' } | Measure-Object).Count -gt 0

$profile = "full"
if ($hasGamingApps -and -not $hasDevApps -and -not $hasCadApps) {
    $profile = "gaming"
}
elseif ($hasDevApps -and -not $hasGamingApps -and -not $hasCadApps) {
    $profile = "dev"
}
elseif (-not $hasGamingApps -and -not $hasDevApps -and -not $hasCadApps -and -not $hasPrintingApps) {
    $profile = "minimal"
}

$useFusion = if (($softwareMapItems | Where-Object { $_.name -match 'Fusion 360|Autodesk Fusion' } | Measure-Object).Count -gt 0) { "yes" } else { "no" }
$enableCloud = if (($softwareMapItems | Where-Object { $_.name -match 'OneDrive|Google Drive|rclone|Dropbox' } | Measure-Object).Count -gt 0) { "yes" } else { "no" }

$steamDriveHints = @($steamLibraries | ForEach-Object { Get-DriveLetterFromPath $_ } | Where-Object { $_ -and $_ -ne $driveIntent.system_drive } | Sort-Object -Unique)
$gamesDriveHint = if ($steamDriveHints.Count -gt 0) { $steamDriveHints[0] } else { "" }

$seedEnv = @(
    "DEPLOY_PROFILE=$profile",
    "INSTALL_MODE=$($driveIntent.install_mode)",
    "OS_DRIVE=",
    "GAMES_DRIVE=",
    "STORAGE_DRIVE=",
    "BACKUP_DRIVE=",
    "MOUNT_GAMES=/mnt/games",
    "MOUNT_STORAGE=/mnt/storage",
    "MOUNT_BACKUPS=/mnt/backups",
    "USE_FUSION360=$useFusion",
    "ENABLE_CLOUD_SETUP=$enableCloud",
    "WINDOWS_SYSTEM_DRIVE=$($driveIntent.system_drive)",
    "WINDOWS_GAMES_DRIVE_HINT=$gamesDriveHint",
    "WINDOWS_STEAM_LIBRARY_COUNT=$($steamLibraries.Count)"
)

$machineProfilePath = Join-Path $OutputDir "machine-profile.json"
$softwareMapPath = Join-Path $OutputDir "software-map.json"
$pathsPath = Join-Path $OutputDir "paths.json"
$seedEnvPath = Join-Path $OutputDir "deployment.seed.env"
$summaryPath = Join-Path $OutputDir "summary.md"

$machineProfile | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $machineProfilePath -Encoding UTF8
$softwareMap | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $softwareMapPath -Encoding UTF8
$paths | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pathsPath -Encoding UTF8
$seedEnv | Set-Content -LiteralPath $seedEnvPath -Encoding UTF8

if ($BackupManifestPath -and (Test-Path -LiteralPath $BackupManifestPath)) {
    Copy-Item -LiteralPath $BackupManifestPath -Destination (Join-Path $OutputDir "backup-manifest.json") -Force
}

$summary = @(
    "# Migration Context Summary",
    "",
    "- Generated: $((Get-Date).ToString('o'))",
    "- Machine ID: $machineId",
    "- Sanitized: $([bool]$Sanitize.IsPresent)",
    "- Suggested profile: $profile",
    "- Suggested install mode: $($driveIntent.install_mode)",
    "- Fusion 360 flag: $useFusion",
    "- Cloud setup flag: $enableCloud",
    "- Total apps inventoried: $($softwareMapItems.Count)",
    "",
    "## Next Steps",
    "",
    "1. Review files in this folder.",
    "2. Commit only sanitized migration context files.",
    "3. Push migration branch.",
    "4. On Pop!_OS, run the import helper.",
    "",
    "## Suggested Git Commands",
    "",
    "```powershell",
    "git checkout -b migration/windows/$machineId/$((Get-Date).ToString('yyyyMMdd'))",
    "git add migration/context/$machineId",
    "git status",
    "git commit -m 'Add sanitized Windows migration context for $machineId.'",
    "git push -u origin migration/windows/$machineId/$((Get-Date).ToString('yyyyMMdd'))",
    "```"
)

$summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Ok "Wrote: $machineProfilePath"
Write-Ok "Wrote: $softwareMapPath"
Write-Ok "Wrote: $pathsPath"
Write-Ok "Wrote: $seedEnvPath"
Write-Ok "Wrote: $summaryPath"

if ($BackupManifestPath -and (Test-Path -LiteralPath $BackupManifestPath)) {
    Write-Ok "Copied backup manifest into migration context"
}
