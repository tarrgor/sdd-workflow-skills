[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Uninstall,

    [string]$DestinationRoot = $env:USERPROFILE
)

$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$skillsSource = Join-Path $repoRoot 'skills'
$codexAgentsSource = Join-Path $repoRoot 'agents\codex'
$installRoot = [System.IO.Path]::GetFullPath($DestinationRoot)
$managedHeader = '# Managed by sdd-workflow-skills; local edits to installed copies may be replaced.'
$script:linked = 0
$script:copied = 0
$script:removed = 0
$script:skipped = 0

if (-not (Test-Path -LiteralPath $skillsSource -PathType Container)) {
    throw "No skills directory found at $skillsSource"
}

function Test-UnderInstallRoot {
    param([Parameter(Mandatory)][string]$Path)

    $candidate = [System.IO.Path]::GetFullPath($Path)
    $prefix = $installRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    return $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Container) { return }
    if ($DryRun) {
        Write-Output "create   $Path"
        return
    }
    [void](New-Item -ItemType Directory -Path $Path -Force)
}

function Get-NormalizedTarget {
    param([Parameter(Mandatory)]$Item)

    $rawTarget = $Item.Target
    if ($rawTarget -is [array]) { $rawTarget = $rawTarget[0] }
    if (-not $rawTarget) { return $null }
    return [System.IO.Path]::GetFullPath([string]$rawTarget)
}

function Remove-LinkOnly {
    param([Parameter(Mandatory)]$Item)

    if ($Item.PSIsContainer) {
        [System.IO.Directory]::Delete($Item.FullName)
    } else {
        [System.IO.File]::Delete($Item.FullName)
    }
}

function Install-SkillJunction {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    if (-not (Test-UnderInstallRoot $Destination)) {
        throw "Refusing destination outside install root: $Destination"
    }

    $sourceFull = [System.IO.Path]::GetFullPath($Source)
    $existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if ($existing) {
        $isReparsePoint = ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        $existingTarget = if ($isReparsePoint) { Get-NormalizedTarget $existing } else { $null }
        if ($existingTarget -and $existingTarget.Equals($sourceFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Output "ok       $Destination"
            return
        }
        if (-not $isReparsePoint) {
            Write-Warning "skip     $Destination exists and is not a link; remove it yourself"
            $script:skipped++
            return
        }
        if (-not $Force) {
            Write-Warning "skip     $Destination points elsewhere (use -Force to replace the link)"
            $script:skipped++
            return
        }
        Write-Output "replace  $Destination"
        if (-not $DryRun) { Remove-LinkOnly $existing }
    }

    Ensure-Directory (Split-Path -Parent $Destination)
    Write-Output "link     $Destination -> $sourceFull"
    if (-not $DryRun) {
        [void](New-Item -ItemType Junction -Path $Destination -Target $sourceFull)
    }
    $script:linked++
}

function Install-ManagedFile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    if (-not (Test-UnderInstallRoot $Destination)) {
        throw "Refusing destination outside install root: $Destination"
    }

    $existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.PSIsContainer) {
            Write-Warning "skip     $Destination exists and is a directory"
            $script:skipped++
            return
        }
        $firstLine = Get-Content -LiteralPath $Destination -TotalCount 1 -ErrorAction SilentlyContinue
        $sameHash = (Get-FileHash -LiteralPath $Source).Hash -eq (Get-FileHash -LiteralPath $Destination).Hash
        if ($sameHash) {
            Write-Output "ok       $Destination"
            return
        }
        if ($firstLine -ne $managedHeader) {
            Write-Warning "skip     $Destination is not managed by sdd-workflow-skills; remove it yourself"
            $script:skipped++
            return
        }
        Write-Output "update   $Destination"
    } else {
        Write-Output "copy     $Destination"
    }

    Ensure-Directory (Split-Path -Parent $Destination)
    if (-not $DryRun) { Copy-Item -LiteralPath $Source -Destination $Destination -Force }
    $script:copied++
}

function Remove-ManagedSkillJunction {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    if (-not (Test-UnderInstallRoot $Destination)) {
        throw "Refusing destination outside install root: $Destination"
    }
    $existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if (-not $existing) { return }
    $isReparsePoint = ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    $existingTarget = if ($isReparsePoint) { Get-NormalizedTarget $existing } else { $null }
    $sourceFull = [System.IO.Path]::GetFullPath($Source)
    if (-not $existingTarget -or -not $existingTarget.Equals($sourceFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "skip     $Destination is not this repository's managed link"
        $script:skipped++
        return
    }
    Write-Output "remove   $Destination"
    if (-not $DryRun) { Remove-LinkOnly $existing }
    $script:removed++
}

function Remove-ManagedFile {
    param([Parameter(Mandatory)][string]$Destination)

    if (-not (Test-UnderInstallRoot $Destination)) {
        throw "Refusing destination outside install root: $Destination"
    }
    $existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if (-not $existing) { return }
    if ($existing.PSIsContainer -or (Get-Content -LiteralPath $Destination -TotalCount 1 -ErrorAction SilentlyContinue) -ne $managedHeader) {
        Write-Warning "skip     $Destination is not a managed sdd-workflow-skills file"
        $script:skipped++
        return
    }
    Write-Output "remove   $Destination"
    if (-not $DryRun) { Remove-Item -LiteralPath $Destination -Force }
    $script:removed++
}

$skillTarget = Join-Path $installRoot '.agents\skills'
foreach ($skillDirectory in Get-ChildItem -LiteralPath $skillsSource -Directory) {
    $destination = Join-Path $skillTarget $skillDirectory.Name
    if ($Uninstall) {
        Remove-ManagedSkillJunction -Source $skillDirectory.FullName -Destination $destination
    } else {
        Install-SkillJunction -Source $skillDirectory.FullName -Destination $destination
    }
}

foreach ($agentFile in Get-ChildItem -LiteralPath $codexAgentsSource -Filter '*.toml' -File) {
    $destination = Join-Path (Join-Path $installRoot '.codex\agents') $agentFile.Name
    if ($Uninstall) { Remove-ManagedFile $destination } else { Install-ManagedFile -Source $agentFile.FullName -Destination $destination }
}

Write-Output "linked: $script:linked  copied: $script:copied  removed: $script:removed  skipped: $script:skipped$($(if ($DryRun) { '  (dry run)' } else { '' }))"
