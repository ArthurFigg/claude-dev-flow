# Gancho do fluxo /produto (definicao de produto antes do CLAUDE.md). So AVISA, nunca bloqueia.
# Eventos: SessionStart (gatilhos 2, 3, 7), UserPromptSubmit (4, 6), PostToolUse Write|Edit (5, 8).
# Gatilho 1 (/produto digitado) nao precisa de gancho. Marcas "ja avisei" em hooks\estado\produto\.
# Texto sem acento de proposito (mesmo padrao dos outros ganchos).
# Teste: defina $env:PRODUTO_ESTADO (pasta de marcas) e $env:PRODUTO_HOJE (ex.: 2026-11-23).
# Uso manual: produto-gancho.ps1 -Dispensar "<pasta>"  (para de avisar naquele projeto)

param([string]$Dispensar = '')

$ErrorActionPreference = 'Stop'
$script = (Join-Path $env:USERPROFILE '.claude\hooks\produto-gancho.ps1')
$pastaEstado = if ($env:PRODUTO_ESTADO) { $env:PRODUTO_ESTADO } else { (Join-Path $env:USERPROFILE '.claude\hooks\estado\produto') }
$hoje = if ($env:PRODUTO_HOJE) { $env:PRODUTO_HOJE } else { (Get-Date).ToString('yyyy-MM-dd') }

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
function Tem-Produto([string]$pasta) { Test-Path (Join-Path $pasta 'docs\PRODUTO.md') }

function Pasta-Ignorada([string]$pasta) {
    $p = $pasta.TrimEnd('\')
    if ($p -ieq $env:USERPROFILE) { return $true }
    return ($p -match '\\\.claude(\\|$)|\\AppData\\|\\Temp\\|\\Downloads(\\|$)|\\Desktop(\\|$)')
}

function Tem-Sinal-Projeto([string]$pasta) {
    foreach ($s in 'CLAUDE.md', '.claude\specs', 'pyproject.toml', 'package.json', '.git', 'src', 'tests') {
        if (Test-Path (Join-Path $pasta $s)) { return $true }
    }
    return $false
}

function Pasta-Nova([string]$pasta) {
    if (Tem-Sinal-Projeto $pasta) { return $false }
    $itens = @(Get-ChildItem -Path $pasta -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin '.git', '.claude', '.vscode', 'desktop.ini' })
    return ($itens.Count -le 3)
}

function Saida([string]$evento, [string]$texto) {
    if (-not $texto) { Write-Output '{}'; exit 0 }
    [ordered]@{
        hookSpecificOutput = [ordered]@{ hookEventName = $evento; additionalContext = $texto }
    } | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

function Texto-Pergunta([string]$pasta, [string]$motivo) {
    return "AVISO DO FLUXO /produto: $motivo " +
        "Diga ao usuario em 1 linha e pergunte UMA vez: rodar /produto? (sim / nao). Nao rode nada antes da resposta. " +
        "Se ele disser nao, rode: powershell -NoProfile -File `"$script`" -Dispensar `"$pasta`" (para de avisar neste projeto)."
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

    switch ($evento) {
        'SessionStart' {
            if (Tem-Produto $cwd) {
                # Gatilho 7: modo Retomar
                Saida $evento ("FLUXO /produto, modo RETOMAR (Passo 0): este projeto tem docs\PRODUTO.md. Antes de qualquer outra coisa, leia o indice de decisoes, o Estado agora, a lista aberta e as ultimas decisoes. " +
                    "Diga em ate 5 linhas onde paramos, a ultima decisao, o que esta aberto e o proximo ponto, e termine com 'e esse o assunto?'. " +
                    "Nao pesquise nem pergunte de produto antes de ele confirmar. Se a mensagem dele ja trouxer um assunto claro e simples, responda a ele e deixe o resumo para depois.")
            }
            if ((Esta-Dispensado $cwd) -or (Pasta-Ignorada $cwd)) { Saida $evento '' }
            if ((Pasta-Nova $cwd) -and -not (Ja-Avisou $cwd 'nova' $false)) {
                # Gatilho 2: pasta nova
                Marcar $cwd 'nova'
                Saida $evento (Texto-Pergunta $cwd 'a pasta parece de um projeto novo (quase vazia, sem CLAUDE.md nem PRODUTO.md). A etapa de definicao de produto vem antes do CLAUDE.md.')
            }
            if ((Tem-Sinal-Projeto $cwd) -and -not (Ja-Avisou $cwd 'meio' $false)) {
                # Gatilho 3: projeto comecado sem aviso
                Marcar $cwd 'meio'
                Saida $evento (Texto-Pergunta $cwd 'este projeto ja tem codigo, specs ou CLAUDE.md mas nao tem docs\PRODUTO.md. O /produto roda em modo Retomar: le o que ja existe e reconstroi o PRODUTO.md so com o que ja foi decidido, e ele confirma antes de gravar.')
            }
            Saida $evento ''
        }
        'UserPromptSubmit' {
            $prompt = [string]$entrada.prompt
            if ($prompt -match '^\s*/produto\b') { Saida $evento '' }
            if ((Esta-Dispensado $cwd) -or (Tem-Produto $cwd)) { Saida $evento '' }
            if (($prompt -match '^\s*/(spec|dominio)\b') -and -not (Ja-Avisou $cwd 'spec' $true)) {
                # Gatilho 6: /spec ou /dominio sem PRODUTO.md
                Marcar $cwd 'spec'
                Saida $evento (Texto-Pergunta $cwd 'ele chamou /spec ou /dominio e este projeto nao tem docs\PRODUTO.md. Avise antes de seguir; se ele recusar, siga com a skill normalmente.')
            }
            $ideia = '(?i)\b(quero|queria|vou|vamos|preciso|pensei em|tive uma ideia).{0,40}\b(criar|fazer|montar|construir|desenvolver)\b.{0,40}\b(um|uma) (novo |nova )?(app|aplicativo|site|sistema|projeto|bot|ferramenta|jogo|plataforma|programa)\b'
            $ideia2 = '(?i)\bideia (de|para|nova).{0,40}\b(app|aplicativo|site|sistema|projeto|bot|ferramenta|jogo|plataforma|programa)\b'
            if ((($prompt -match $ideia) -or ($prompt -match $ideia2)) -and -not (Tem-Sinal-Projeto $cwd) -and -not (Ja-Avisou $cwd 'ideia' $true)) {
                # Gatilho 4: ideia nova na mensagem (por palavra: pode errar)
                Marcar $cwd 'ideia'
                Saida $evento (Texto-Pergunta $cwd 'a mensagem parece trazer uma ideia nova de projeto (deteccao por palavra, pode ser engano; se for engano, ignore e nao comente).')
            }
            Saida $evento ''
        }
        'PostToolUse' {
            $arquivo = ([string]$entrada.tool_input.file_path) -replace '/', '\'
            if (-not $arquivo) { Saida $evento '' }
            if ($arquivo -match '(?i)\\pre-projeto\.md$') {
                # Gatilho 5: fim do /pesquisar-projeto
                Saida $evento ("AVISO DO FLUXO /produto: o pre-projeto.md foi gravado ($arquivo). Se a decisao dele foi 'seguir', o proximo passo e o /produto (o Passo 1 importa o pre-projeto.md). " +
                    "Quando a pesquisa terminar, diga em 1 linha e pergunte UMA vez: rodar /produto? (sim / nao). Se a decisao foi largar, nao diga nada.")
            }
            if ($arquivo -match '(?i)\\docs\\PRODUTO\.md$') {
                $texto = [string]$entrada.tool_input.new_string + [string]$entrada.tool_input.content
                foreach ($e in @($entrada.tool_input.edits)) { $texto += [string]$e.new_string }
                if ($texto -match '\*\*Decis') {
                    # Gatilho 8: decisao gravada
                    Saida $evento ("FLUXO /produto: uma decisao foi gravada no PRODUTO.md. Ela e GRANDE se restringe mais de uma tela ou modulo, muda algo ja decidido, envolve dado sensivel, dinheiro ou seguranca, ou ele disse que e. " +
                        "Se for grande: rode o agente de conferencia pelo agy (Passo 3B da skill produto) so para esta decisao e mostre o resultado antes do proximo ponto. Se nao for, nao faca nada e nao comente.")
                }
            }
            Saida $evento ''
        }
        default { Write-Output '{}'; exit 0 }
    }
} catch {
    Write-Output '{}'
    exit 0
}
