[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError([string]$Message) {
    $errors.Add($Message)
}

$legacyHashes = @{
    'install.sh' = 'D9A3001DDA81B4F6F2CEA308DF012E8C3CB48B1CB4DB967E58A7E9BE64EC8C53'
    'agents/research-topic.md' = '43CEC65810C9EC014A22BAB5ECAE23DBE62DC0088EEE5172DAE4D2353946DD13'
    'agents/verify-implementation.md' = '01B562851B61F557E74F3544D8D3319B28E8F9A484A0BC8D7E8C93490A2E6BFA'
    'AGENTS.md' = '4F675380999B9470F86A381A73B9AB7EEBB85216283B46EF2A1F26BF90D45977'
    'CLAUDE.md' = '22C73726A8E5106DD03DFF77F13E8BF063F0E236EBFF81811EDB6DD608C96988'
    'skills/kick-off/references/CLAUDE.md.template' = 'EDBDD342195555C3F487FC8B1A99D09F985BB73507CD2E7B56DCF436A47A290A'
}

foreach ($entry in $legacyHashes.GetEnumerator()) {
    $path = Join-Path $repoRoot $entry.Key
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-ValidationError "Missing Claude compatibility file: $($entry.Key)"
        continue
    }
    $text = [System.IO.File]::ReadAllText($path) -replace "`r`n", "`n"
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($text)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try { $hashBytes = $sha256.ComputeHash($bytes) } finally { $sha256.Dispose() }
    $actual = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '')
    if ($actual -ne $entry.Value) {
        Add-ValidationError "Claude compatibility file changed: $($entry.Key)"
    }
}

$claudeSkillContracts = @{
    'skills/implement-issue/SKILL.md' = @('subagent_type: verify-implementation', 'run_in_background: false')
    'skills/verify-implementation/SKILL.md' = @('subagent_type: verify-implementation', 'run_in_background: false')
    'skills/research-topic/SKILL.md' = @('subagent_type: research-topic', 'run_in_background: false')
    'skills/kick-off/SKILL.md' = @('root `AGENTS.md` containing just `Read CLAUDE.md.`')
    'skills/create-obsidian-vault/SKILL.md' = @('disable-model-invocation: true', 'run it with `/create-obsidian-vault`')
}
foreach ($entry in $claudeSkillContracts.GetEnumerator()) {
    $content = Get-Content -Raw -LiteralPath (Join-Path $repoRoot $entry.Key)
    foreach ($snippet in $entry.Value) {
        if (-not $content.Contains($snippet)) {
            Add-ValidationError "Claude skill contract missing from $($entry.Key): $snippet"
        }
    }
}

$installSh = Get-Content -Raw (Join-Path $repoRoot 'install.sh')
foreach ($contract in @('$HOME/.claude/skills', '$HOME/.agents/skills', '$HOME/.claude/agents')) {
    if (-not $installSh.Contains($contract)) {
        Add-ValidationError "Legacy install.sh destination missing: $contract"
    }
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
    if (-not $content.StartsWith('# Managed by skillz-lattice;')) {
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

foreach ($skillName in @('check-pr-comments', 'create-obsidian-vault', 'research-topic')) {
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

Write-Output "Validated $($skillNames.Count) skills, $((Get-ChildItem (Join-Path $repoRoot 'agents/codex') -Filter '*.toml').Count) Codex agents, and the unchanged Claude installation contract."
