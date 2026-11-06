[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError([string]$Message) {
    $errors.Add($Message)
}

$skillNames = @{}
$skillRoot = Join-Path $repoRoot 'skills'
foreach ($directory in Get-ChildItem -LiteralPath $skillRoot -Directory | Where-Object Name -ne '_shared') {
    $skillFile = Join-Path $directory.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        Add-ValidationError "Missing SKILL.md: $($directory.Name)"
        continue
    }
    $content = Get-Content -Raw -LiteralPath $skillFile
    if ($content -notmatch '(?s)^---\r?\n(?<frontmatter>.*?)\r?\n---') {
        Add-ValidationError "Invalid frontmatter block: $($directory.Name)"
        continue
    }
    $frontmatter = $Matches.frontmatter
    if ($frontmatter -notmatch '(?m)^name:\s*(?<name>[a-z0-9-]+)\s*$') {
        Add-ValidationError "Missing or invalid skill name: $($directory.Name)"
    } else {
        $name = $Matches.name
        if ($name -ne $directory.Name) { Add-ValidationError "Skill name/folder mismatch: $($directory.Name) -> $name" }
        if ($skillNames.ContainsKey($name)) { Add-ValidationError "Duplicate skill name: $name" } else { $skillNames[$name] = $true }
    }
    if ($frontmatter -notmatch '(?m)^description:\s*\S') {
        Add-ValidationError "Missing skill description: $($directory.Name)"
    }

    foreach ($match in [regex]::Matches($content, '\.\./_shared/(?<file>[a-z0-9-]+\.md)')) {
        $reference = Join-Path (Join-Path $directory.FullName '..\_shared') $match.Groups['file'].Value
        if (-not (Test-Path -LiteralPath $reference -PathType Leaf)) {
            Add-ValidationError "Broken shared reference in $($directory.Name): $($match.Value)"
        }
    }
    foreach ($match in [regex]::Matches($content, 'references/(?<file>[A-Za-z0-9_./-]+)')) {
        $relative = $match.Groups['file'].Value.TrimEnd('.', ',', ')', '`', '/')
        $reference = Join-Path (Join-Path $directory.FullName 'references') ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $reference)) {
            Add-ValidationError "Broken skill reference in $($directory.Name): references/$relative"
        }
    }
}

foreach ($agentFile in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'agents/codex') -Filter '*.toml' -File) {
    $content = Get-Content -Raw -LiteralPath $agentFile.FullName
    if (-not $content.StartsWith('# Managed by sdd-workflow-skills;')) {
        Add-ValidationError "Codex agent lacks managed header: $($agentFile.Name)"
    }
    foreach ($field in @('name', 'description', 'developer_instructions')) {
        if ($content -notmatch "(?m)^$field\s*=") {
            Add-ValidationError "Codex agent lacks $field`: $($agentFile.Name)"
        }
    }
    if ($content -notmatch '(?m)^sandbox_mode\s*=\s*"read-only"\s*$') {
        Add-ValidationError "Codex agent must be read-only: $($agentFile.Name)"
    }
    if (([regex]::Matches($content, '"""')).Count % 2 -ne 0) {
        Add-ValidationError "Unbalanced TOML multiline string: $($agentFile.Name)"
    }
}

foreach ($skillName in @('check-pr-comments', 'create-obsidian-vault', 'research-topic', 'run-milestone')) {
    $metadata = Join-Path $skillRoot "$skillName/agents/openai.yaml"
    if (-not (Test-Path -LiteralPath $metadata -PathType Leaf)) {
        Add-ValidationError "Missing Codex invocation policy: $skillName"
    } elseif ((Get-Content -Raw -LiteralPath $metadata) -notmatch '(?m)^\s*allow_implicit_invocation:\s*false\s*$') {
        Add-ValidationError "Invalid Codex invocation policy: $skillName"
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Validated $($skillNames.Count) skills, $((Get-ChildItem (Join-Path $repoRoot 'agents/codex') -Filter '*.toml').Count) Codex agents, and their shared references."
