# Gancho do fluxo /front (visual antes das specs). So AVISA, nunca bloqueia (decisao dele, 25/11).
# Eventos: SessionStart (momentos 2 e 3), UserPromptSubmit (momento 4), PostToolUse Write|Edit (momentos 5 e 6).
# Momento 1 (/front digitado) nao precisa de gancho. Marcas "ja avisei" em hooks\estado\front\.
# So age em projeto "com tela": docs\PRODUTO.md com pelo menos uma decisao marcada [tela].
# Texto sem acento de proposito (mesmo padrao dos outros ganchos).
# Teste: defina $env:FRONT_ESTADO (pasta de marcas) e $env:FRONT_HOJE (ex.: 2026-11-25).
# Uso manual: front-gancho.ps1 -Dispensar "<pasta>"  (para de avisar naquele projeto)

param([string]$Dispensar = '')

$ErrorActionPreference = 'Stop'
$script = (Join-Path $env:USERPROFILE '.claude\hooks\front-gancho.ps1')
$pastaEstado = if ($env:FRONT_ESTADO) { $env:FRONT_ESTADO } else { (Join-Path $env:USERPROFILE '.claude\hooks\estado\front') }
$hoje = if ($env:FRONT_HOJE) { $env:FRONT_HOJE } else { (Get-Date).ToString('yyyy-MM-dd') }

function Obter-Chave([string]$pasta) {
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($pasta.TrimEnd('\').ToLowerInvariant())
    $hash = $sha.ComputeHash($bytes)
    return -join ($hash[0..5] | ForEach-Object { $_.ToString('x2') })
}

function Arquivo-Marca([string]$pasta, [string]$tipo) {
    return Join-Path $pastaEstado ((Obter-Chave $pasta) + '.' + $tipo)
}

function Marcar([string]$pasta, [string]$tipo) {
    New-Item -ItemType Directory -Force -Path $pastaEstado | Out-Null
    Set-Content -Path (Arquivo-Marca $pasta $tipo) -Value $hoje -Encoding ASCII
}

# diario = avisa no maximo 1 vez por dia; senao, 1 vez so por projeto
function Ja-Avisou([string]$pasta, [string]$tipo, [bool]$diario) {
    $arq = Arquivo-Marca $pasta $tipo
    if (-not (Test-Path $arq)) { return $false }
    if (-not $diario) { return $true }
    return ((Get-Content $arq -Raw).Trim() -eq $hoje)
}

function Esta-Dispensado([string]$pasta) { Test-Path (Arquivo-Marca $pasta 'dispensado') }

function Pasta-Ignorada([string]$pasta) {
    $p = $pasta.TrimEnd('\')
    if ($p -ieq $env:USERPROFILE) { return $true }
    return ($p -match '\\\.claude(\\|$)|\\AppData\\|\\Temp\\|\\Downloads(\\|$)|\\Desktop(\\|$)')
}

# Projeto com tela = PRODUTO.md com decisao marcada [tela]
function Tem-Tela([string]$pasta) {
    $arq = Join-Path $pasta 'docs\PRODUTO.md'
    if (-not (Test-Path $arq)) { return $false }
    return [bool](Select-String -Path $arq -Pattern '[tela]' -SimpleMatch -Quiet)
}

function Tem-Front([string]$pasta) { Test-Path (Join-Path $pasta 'docs\FRONT.md') }

# Le o valor da linha **Estado:** do FRONT.md; vazio se nao existir
function Estado-Front([string]$pasta) {
    $arq = Join-Path $pasta 'docs\FRONT.md'
    if (-not (Test-Path $arq)) { return '' }
    $achado = Select-String -Path $arq -Pattern '^\*\*Estado:\*\*\s*([^\r\n(]+)' | Select-Object -First 1
    if (-not $achado) { return '' }
    return $achado.Matches[0].Groups[1].Value.Trim()
}

function Visual-Aprovado([string]$pasta) { return ((Estado-Front $pasta) -ieq 'casca aprovada') }

function Saida([string]$evento, [string]$texto) {
    if (-not $texto) { Write-Output '{}'; exit 0 }
    [ordered]@{
        hookSpecificOutput = [ordered]@{ hookEventName = $evento; additionalContext = $texto }
    } | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

try {
    if ($Dispensar) {
        Marcar $Dispensar 'dispensado'
        Write-Output "Dispensado: $Dispensar"
        exit 0
    }

    $bruto = [Console]::In.ReadToEnd()
    if (-not $bruto) { Write-Output '{}'; exit 0 }
    $entrada = $bruto | ConvertFrom-Json
    $evento = $entrada.hook_event_name
    $cwd = [string]$entrada.cwd
    if (-not $cwd) { Write-Output '{}'; exit 0 }
    if ((Pasta-Ignorada $cwd) -or (Esta-Dispensado $cwd) -or -not (Tem-Tela $cwd)) { Saida $evento '' }

    $estado = Estado-Front $cwd

    switch ($evento) {
        'SessionStart' {
            if (Tem-Front $cwd) {
                if (Visual-Aprovado $cwd) { Saida $evento '' }
                # Momento 3: retomar
                Saida $evento ("FLUXO /front, modo RETOMAR: este projeto tem docs\FRONT.md com Estado `"$estado`". Antes de qualquer outra coisa, leia o FRONT.md e a pasta docs\front\. " +
                    "Diga em ate 5 linhas em que passo paramos, o que falta e o proximo passo, e termine com 'e esse o assunto?'. " +
                    "Nao comece nada antes de ele confirmar. Se a mensagem dele ja trouxer um assunto claro, responda a ele e deixe o resumo para depois.")
            }
            if (-not (Ja-Avisou $cwd 'novo' $false)) {
                # Momento 2: projeto com tela sem FRONT.md
                Marcar $cwd 'novo'
                Saida $evento ("AVISO DO FLUXO /front: este projeto tem tela (o PRODUTO.md tem decisao marcada [tela]) e ainda nao tem docs\FRONT.md. " +
                    "O /front define o visual antes das specs: brief, referencias, direcoes, identidade e casca. " +
                    "Diga ao usuario em 1 linha e pergunte UMA vez: rodar /front? (sim / nao). Nao rode nada antes da resposta. " +
                    "Se ele disser nao, rode: powershell -NoProfile -File `"$script`" -Dispensar `"$cwd`" (para de avisar neste projeto).")
            }
            Saida $evento ''
        }
        'UserPromptSubmit' {
            $prompt = [string]$entrada.prompt
            if ($prompt -match '^\s*/front\b') { Saida $evento '' }
            if (($prompt -match '^\s*/spec(\s|$)') -and -not (Visual-Aprovado $cwd) -and -not (Ja-Avisou $cwd 'spec' $true)) {
                # Momento 4: /spec com o visual nao aprovado
                Marcar $cwd 'spec'
                $quando = if ($estado) { "Estado do FRONT.md: `"$estado`"" } else { 'docs\FRONT.md ausente' }
                Saida $evento ("AVISO DO FLUXO /front: ele chamou /spec em projeto com tela, mas o visual ainda nao foi aprovado ($quando). " +
                    "Avise em 1 linha e pergunte UMA vez: rodar /front antes? (sim / nao). Se ele recusar, siga com a spec normalmente. " +
                    "Se ele disser nao, rode: powershell -NoProfile -File `"$script`" -Dispensar `"$cwd`".")
            }
            Saida $evento ''
        }
        'PostToolUse' {
            $arquivo = ([string]$entrada.tool_input.file_path) -replace '/', '\'
            if (-not $arquivo) { Saida $evento '' }
            if ($arquivo -match '(?i)\\docs\\FRONT\.md$') {
                # Momento 6: FRONT.md gravado
                Saida $evento ("FLUXO /front: o FRONT.md foi alterado (Estado atual: `"$estado`"). Gere de novo a pagina visual em docs\front\front.html a partir dele (a pagina nunca e editada a mao). " +
                    "Se o Estado passou a 'identidade aprovada', o proximo passo e a casca completa; se passou a 'casca aprovada', o /front terminou e o proximo passo e o /spec.")
            }
            if (($arquivo -match '(?i)\.(html|css|scss|jsx|tsx|vue|svelte)$') -and ($arquivo -notmatch '(?i)\\docs\\front\\') -and -not (Visual-Aprovado $cwd) -and -not (Ja-Avisou $cwd 'edicao' $true)) {
                # Momento 5: edicao de interface com o visual nao aprovado
                Marcar $cwd 'edicao'
                $quando = if ($estado) { "Estado: `"$estado`"" } else { 'sem FRONT.md' }
                Saida $evento ("AVISO DO FLUXO /front: voce editou arquivo de interface ($arquivo) e o visual deste projeto ainda nao foi aprovado ($quando). " +
                    "Diga em 1 linha, uma vez, e siga com a edicao; o /front so avisa, nao bloqueia. Se for uma edicao pequena e sem relacao com o visual, nao comente.")
            }
            Saida $evento ''
        }
        default { Write-Output '{}'; exit 0 }
    }
} catch {
    Write-Output '{}'
    exit 0
}
