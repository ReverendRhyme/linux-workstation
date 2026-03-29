param(
    [switch]$IncludeDownloads,
    [switch]$SkipBackup,
    [switch]$PrepareFixBranch,
    [string]$ContextRoot = "migration/context"
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

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Resolve-ContextRoot {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return (Join-Path (Resolve-Path ".") $Path)
}

function Classify-RootCause {
    param([string]$Message)
    $m = $Message.ToLowerInvariant()
    if ($m -match 'access denied|permission|unauthorized') { return 'permissions' }
    if ($m -match 'path|not found|cannot find|does not exist') { return 'path' }
    if ($m -match 'timed out|dns|network|tls|ssl|connection') { return 'network' }
    if ($m -match 'json|schema|parse|invalid') { return 'schema' }
    if ($m -match 'git|checkout|commit|push|branch') { return 'git' }
    return 'script'
}

function Invoke-CheckedStep {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Info "Running: $Name"
    $output = @()
    $exitCode = 0

    try {
        $output = & $Command 2>&1
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
    }
    catch {
        $output += $_.Exception.Message
        $exitCode = 1
    }

    if (@($output).Count -gt 0) {
        $output | ForEach-Object { Write-Host "    $_" }
    }

    if ($exitCode -ne 0) {
        return [ordered]@{
            ok = $false
            name = $Name
            exit_code = $exitCode
            output = ($output -join "`n")
        }
    }

    Write-Ok "$Name"
    return [ordered]@{
        ok = $true
        name = $Name
        exit_code = 0
        output = ($output -join "`n")
    }
}

function Get-LatestContextDir {
    param(
        [string]$Root,
        [string[]]$BeforePaths
    )

    if (-not (Test-Path -LiteralPath $Root)) {
        return $null
    }

    $all = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue
    if (-not $all) { return $null }

    $new = @($all | Where-Object { $_.FullName -notin $BeforePaths })
    if ($new.Count -eq 1) {
        return $new[0].FullName
    }

    if ($new.Count -gt 1) {
        return ($new | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }

    return ($all | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

function Validate-Context {
    param([string]$ContextDir)

    $required = @(
        "machine-profile.json",
        "software-map.json",
        "paths.json",
        "deployment.seed.env",
        "summary.md"
    )

    foreach ($name in $required) {
        $p = Join-Path $ContextDir $name
        if (-not (Test-Path -LiteralPath $p)) {
            throw "Missing required context file: $name"
        }
    }
}

function Append-Incident {
    param(
        [string]$SummaryPath,
        [string]$Step,
        [int]$ExitCode,
        [string]$Output,
        [string]$RootCause
    )

    $ts = (Get-Date).ToString("o")
    $keyLines = ($Output -split "`n" | Select-Object -First 12) -join "`n"

    $block = @(
        "",
        "## Incident $ts",
        "",
        "- Step: $Step",
        "- Exit code: $ExitCode",
        "- Root cause class: $RootCause",
        "",
        "### Key output",
        "",
        '```text',
        $keyLines,
        '```',
        ""
    )

    Add-Content -LiteralPath $SummaryPath -Value ($block -join "`n") -Encoding UTF8
}

function Maybe-PrepareFixBranch {
    param([string]$RootCause)

    if (-not $PrepareFixBranch.IsPresent) {
        return
    }

    $date = Get-Date -Format "yyyyMMdd"
    $topic = ($RootCause -replace '[^a-z0-9-]', '-')
    $branch = "fix/migration-loop/$date-$topic"

    Write-Info "Preparing fix branch: $branch"
    & git checkout -b $branch | Out-Host
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Created fix branch: $branch"
    }
    else {
        Write-Warn "Could not create fix branch automatically. Create it manually if needed."
    }
}

# Start
$repoRoot = (Resolve-Path ".").Path
$contextRootPath = Resolve-ContextRoot -Path $ContextRoot
New-Item -ItemType Directory -Path $contextRootPath -Force | Out-Null

Write-Info "Repo root: $repoRoot"
Write-Info "Context root: $contextRootPath"

$before = @(Get-ChildItem -LiteralPath $contextRootPath -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

if (-not $SkipBackup.IsPresent) {
    $backupArgs = @("-ExecutionPolicy", "Bypass", "-File", ".\scripts\windows\backup-to-gdrive.ps1")
    if ($IncludeDownloads.IsPresent) { $backupArgs += "-IncludeDownloads" }
    $backupResult = Invoke-CheckedStep -Name "backup-to-gdrive.ps1" -Command { powershell @backupArgs }
    if (-not $backupResult.ok) {
        $contextDir = Get-LatestContextDir -Root $contextRootPath -BeforePaths $before
        if (-not $contextDir) {
            $fallback = Join-Path $contextRootPath ("win-failure-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
            New-Item -ItemType Directory -Path $fallback -Force | Out-Null
            $contextDir = $fallback
            Set-Content -LiteralPath (Join-Path $contextDir "summary.md") -Value "# Migration Context Summary" -Encoding UTF8
        }
        $summaryPath = Join-Path $contextDir "summary.md"
        if (-not (Test-Path -LiteralPath $summaryPath)) {
            Set-Content -LiteralPath $summaryPath -Value "# Migration Context Summary" -Encoding UTF8
        }
        $class = Classify-RootCause -Message $backupResult.output
        Append-Incident -SummaryPath $summaryPath -Step $backupResult.name -ExitCode $backupResult.exit_code -Output $backupResult.output -RootCause $class
        Write-Err "BLOCKED: backup step failed"
        Write-Host "Status: BLOCKED"
        Write-Host "Incident logged: $summaryPath"
        Maybe-PrepareFixBranch -RootCause $class
        exit 1
    }
}

$exportResult = Invoke-CheckedStep -Name "export-migration-context.ps1" -Command {
    powershell -ExecutionPolicy Bypass -File .\scripts\windows\export-migration-context.ps1
}

$contextDir = Get-LatestContextDir -Root $contextRootPath -BeforePaths $before
if (-not $contextDir) {
    Write-Err "No migration context directory found after export"
    Write-Host "Status: BLOCKED"
    exit 1
}

$summaryPath = Join-Path $contextDir "summary.md"
if (-not (Test-Path -LiteralPath $summaryPath)) {
    Set-Content -LiteralPath $summaryPath -Value "# Migration Context Summary" -Encoding UTF8
}

if (-not $exportResult.ok) {
    $class = Classify-RootCause -Message $exportResult.output
    Append-Incident -SummaryPath $summaryPath -Step $exportResult.name -ExitCode $exportResult.exit_code -Output $exportResult.output -RootCause $class
    Write-Err "BLOCKED: export step failed"
    Write-Host "Status: BLOCKED"
    Write-Host "Incident logged: $summaryPath"
    Maybe-PrepareFixBranch -RootCause $class
    exit 1
}

$validateResult = Invoke-CheckedStep -Name "validate-context" -Command {
    Validate-Context -ContextDir $contextDir
}

if (-not $validateResult.ok) {
    $class = Classify-RootCause -Message $validateResult.output
    Append-Incident -SummaryPath $summaryPath -Step $validateResult.name -ExitCode $validateResult.exit_code -Output $validateResult.output -RootCause $class
    Write-Err "BLOCKED: context validation failed"
    Write-Host "Status: BLOCKED"
    Write-Host "Incident logged: $summaryPath"
    Maybe-PrepareFixBranch -RootCause $class
    exit 1
}

Write-Ok "Migration loop completed successfully"
Write-Host "Status: PASS"
Write-Host "Context directory: $contextDir"
