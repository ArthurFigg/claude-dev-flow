$ErrorActionPreference = 'Stop'

$stdin = [Console]::In.ReadToEnd()
if (-not $stdin) { exit 0 }

try {
    $payload = $stdin | ConvertFrom-Json
} catch {
    exit 0
}

$filePath = $payload.tool_input.file_path
$cwd = $payload.cwd
if (-not $filePath -or -not $cwd) { exit 0 }

$normalized = $filePath -replace '/', '\'

# Editar as proprias specs (spec-review corrige arquivos) ou o CLAUDE.md
# (auditar-claude-md, planejar-setup) nunca e bloqueado.
if ($normalized -match '\\\.claude\\specs\\') { exit 0 }
if ((Split-Path $normalized -Leaf) -ieq 'CLAUDE.md') { exit 0 }

$specsDir = Join-Path $cwd '.claude\specs'
if (-not (Test-Path $specsDir)) { exit 0 }

$specFiles = Get-ChildItem -Path $specsDir -Filter '*.md' -File -ErrorAction SilentlyContinue
if (-not $specFiles) { exit 0 }

$pendentes = @()
foreach ($f in $specFiles) {
    $conteudo = Get-Content -Path $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($conteudo -match '\*\*Revis[^:]*:\*\*\s*pendente') {
        $pendentes += $f.Name
    }
}

if ($pendentes.Count -eq 0) { exit 0 }

$lista = $pendentes -join ', '
$reason = "Gate de specs: $($pendentes.Count) spec(s) com Revisao pendente ($lista). Rode /spec-review antes de implementar."

$result = @{
    hookSpecificOutput = @{
        hookEventName = 'PreToolUse'
        permissionDecision = 'deny'
        permissionDecisionReason = $reason
    }
} | ConvertTo-Json -Depth 5 -Compress

Write-Output $result
exit 0
