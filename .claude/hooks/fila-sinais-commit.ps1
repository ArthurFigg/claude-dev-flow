# Gancho PostToolUse da fila de propostas. Depois de um git commit, procura sinais
# fixos de atrito no trecho da sessao desde o commit anterior e, se achar, obriga a
# IA a avaliar com a skill propor-melhoria. Sem sinal, fica quieto.
# Sinais sao regras fixas de proposito: na pesquisa de 23/10, checagem fixa pegou
# falha com 0 alarme falso, e juiz que le a sessao inteira de uma vez foi o pior.
# O que acontece DEPOIS do ultimo commit fica com o fila-notas-fim.ps1 (gancho Stop).

. (Join-Path $PSScriptRoot 'fila-sinais-comum.ps1')

$entrada = [Console]::In.ReadToEnd() | ConvertFrom-Json

function Fica-Quieto {
    Write-Output "{}"
    exit 0
}

$cmd = $entrada.tool_input.command
if ($null -eq $cmd) { Fica-Quieto }
if ($cmd -notmatch $PadraoCommitFila) { Fica-Quieto }

$caminho = $entrada.transcript_path
if (-not $caminho -or -not (Test-Path $caminho)) { Fica-Quieto }

$estado = Ler-EstadoFila $entrada.session_id
$eventos = Ler-EventosFila $caminho

# Janela = depois do commit anterior. O ultimo commit da lista e o atual.
$indicesCommit = @()
for ($i = 0; $i -lt $eventos.Count; $i++) {
    foreach ($bloco in @($eventos[$i].message.content)) {
        if ($bloco.type -eq 'tool_use' -and $bloco.input.command -match $PadraoCommitFila) {
            $indicesCommit += $i
        }
    }
}
# Se o commit atual ainda nao foi gravado na sessao, o anterior e o ultimo da lista.
$inicio = 0
$atualGravado = $false
if ($indicesCommit.Count -ge 1) {
    foreach ($bloco in @($eventos[$indicesCommit[-1]].message.content)) {
        if ($bloco.type -eq 'tool_use' -and $bloco.input.command -eq $cmd) { $atualGravado = $true }
    }
}
if ($atualGravado -and $indicesCommit.Count -ge 2) { $inicio = $indicesCommit[-2] + 1 }
if (-not $atualGravado -and $indicesCommit.Count -ge 1) { $inicio = $indicesCommit[-1] + 1 }

$r = Achar-SinaisFila $eventos $inicio $estado.Ja

$sinais = @(Sinais-PontuaisFila $r)
if ($r.TesteRefeito) { $sinais += "Teste falhou e foi refeito ($($r.TestesFalhos) falha(s) em $($r.TestesRodados) rodada(s))" }
foreach ($arq in $r.Edicoes.Keys) {
    if ($r.Edicoes[$arq] -ge 3) { $sinais += "Arquivo editado $($r.Edicoes[$arq])x: $arq" }
}
if ($r.Mensagens -ge 10) { $sinais += "Conversa longa: $($r.Mensagens) mensagens suas desde o ultimo commit" }

if ($sinais.Count -eq 0) { Fica-Quieto }
if ($r.Chaves.Count -gt 0) { $r.Chaves | Add-Content $estado.Arquivo -Encoding UTF8 }

$aviso = "[fila-propostas] Commit feito. Sinais fixos achados desde o commit anterior:`n- " +
    ($sinais -join "`n- ") +
    "`nSessao atual: $($entrada.session_id)" +
    "`nAvalie AGORA com a skill propor-melhoria: revise so o trecho perto de cada sinal, passo a passo, registre pelo script e avise o usuario no formato da skill. Se nenhum sinal virar proposta, diga isso em uma linha."

$resultado = [ordered]@{
    hookSpecificOutput = [ordered]@{
        hookEventName     = "PostToolUse"
        additionalContext = $aviso
    }
} | ConvertTo-Json -Depth 5 -Compress

Write-Output $resultado
