[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("skillz-lattice-test-" + [guid]::NewGuid().ToString('N'))

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

try {
    [void](New-Item -ItemType Directory -Path $testRoot)

    $dryRoot = Join-Path $testRoot 'dry run with spaces'
    $dryOutput = & (Join-Path $repoRoot 'install.ps1') -Target Codex -DestinationRoot $dryRoot -DryRun
    Assert-True (-not (Test-Path -LiteralPath $dryRoot)) 'dry run created files'
    Assert-True (($dryOutput -join "`n") -match '\(dry run\)') 'dry run summary missing'

    $installRoot = Join-Path $testRoot 'install with spaces'
    $firstOutput = & (Join-Path $repoRoot 'install.ps1') -Target Codex -DestinationRoot $installRoot
    $kickOff = Get-Item -LiteralPath (Join-Path $installRoot '.agents/skills/kick-off') -Force
    Assert-True (($kickOff.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) 'skill is not a junction'
    Assert-True (Test-Path -LiteralPath (Join-Path $installRoot '.codex/agents/verify-implementation.toml')) 'review agent missing'
    Assert-True (Test-Path -LiteralPath (Join-Path $installRoot '.codex/agents/research-topic.toml')) 'research agent missing'

    $secondOutput = & (Join-Path $repoRoot 'install.ps1') -Target Codex -DestinationRoot $installRoot
    Assert-True (($secondOutput -join "`n") -match 'ok\s+.*kick-off') 'idempotent install did not report existing skill'

    $protectedRoot = Join-Path $testRoot 'protected'
    $protectedSkill = Join-Path $protectedRoot '.agents/skills/kick-off'
    [void](New-Item -ItemType Directory -Path $protectedSkill -Force)
    Set-Content -LiteralPath (Join-Path $protectedSkill 'owned.txt') -Value 'user-owned'
    $protectedAgent = Join-Path $protectedRoot '.codex/agents/research-topic.toml'
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $protectedAgent) -Force)
    Set-Content -LiteralPath $protectedAgent -Value '# user-owned agent'
    & (Join-Path $repoRoot 'install.ps1') -Target Codex -DestinationRoot $protectedRoot -Force 3>$null | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $protectedSkill 'owned.txt')) 'force overwrote a real directory'
    Assert-True ((Get-Content -Raw -LiteralPath $protectedAgent) -match 'user-owned') 'force overwrote an unmanaged agent file'

    & (Join-Path $repoRoot 'install.ps1') -Target Codex -DestinationRoot $installRoot -Uninstall | Out-Null
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $installRoot '.agents/skills/kick-off'))) 'uninstall left a managed junction'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $installRoot '.codex/agents/verify-implementation.toml'))) 'uninstall left a managed agent'

    $claudeDryRoot = Join-Path $testRoot 'claude-dry'
    $claudeOutput = & (Join-Path $repoRoot 'install.ps1') -Target Claude -DestinationRoot $claudeDryRoot -DryRun
    Assert-True (-not (Test-Path -LiteralPath $claudeDryRoot)) 'Claude dry run created files'
    Assert-True (($claudeOutput -join "`n") -match '\.claude.*skills') 'Claude skills destination missing from dry run'
    Assert-True (($claudeOutput -join "`n") -match '\.claude.*agents') 'Claude agents destination missing from dry run'

    Write-Output 'PowerShell installer tests passed.'
} finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $resolvedTest = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolvedTest.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTest)) {
        Remove-Item -LiteralPath $resolvedTest -Recurse -Force
    }
}
