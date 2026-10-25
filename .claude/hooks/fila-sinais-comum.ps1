# Parte comum dos ganchos da fila (fila-sinais-commit.ps1 e fila-notas-fim.ps1):
# ler a sessao, achar os sinais fixos e lembrar o que ja foi mandado avaliar.
# Cada sinal pontual (correcao, recusa, desfazer, nota) tem uma chave; a chave vai pro
# arquivo de estado da sessao quando e avisada, e nenhum dos dois ganchos repete.

$PastaEstadoFila = (Join-Path $HOME 'fila-propostas\estado')

# { e ( entram por causa do PowerShell: "if ($?) { git commit ... }".
# revert entra porque cria commit (teste de 24/10: desfazer com git revert nao acionava nada).
$PadraoCommitFila = '(?:^|[;&|\n{(]\s*)git\s+(?:-C\s+\S+\s+)?(?:commit|revert)\b'

# Larga de proposito: so aciona a avaliacao, quem julga e a IA + fila.ps1. Na rodada 6,
# a lista curta deixou passar "nao, daqui pra frente...", "de novo veio..." e "wrong, never...".
$padraoCorrecao = '(?i)(^\s*(n[aã]o|nope|no)\b|\b(errad[oa]|errou|wrong|incorrect|desfa[zc]|reverte|volta atr[aá]s|n[aã]o era isso|n[aã]o foi isso|eu (j[aá] )?(disse|falei|pedi)|de novo|again|t[aá] errado|corrige|para com isso|n[aã]o fa[cç]a|era pra|era para|tem que ser|deveria|should|instead|em vez de|nunca|never|sempre|always|daqui pra frente|daqui para frente|de agora em diante|from now on|por enquanto|devia ter virado|melhor|mejor|better|prefiro|preferia|i.d rather|prefer)\b)'
# A propria IA dizendo que um arquivo do fluxo usado na sessao esta errado (rodada 6: ela percebia
# e oferecia corrigir, sem anotar).
$padraoProblemaFluxo = '(?i)(manda|mandava|precisa (dizer|mudar|trocar)|vale corrigir|est[aá] errad|n[aã]o existe|falhou|errou|deveria|segui literalmente)'
$padraoTeste = '\bpytest\b'
$padraoDesfazer = '\bgit\s+(revert|reset|restore|checkout\s+--)\b'
# So no inicio da linha: a IA citando a marca no meio de uma explicacao nao conta.
$padraoNota = '(?m)^\[nota-fila\][ \t]*(\S.*)$'

function Ler-EventosFila([string]$caminho) {
    # So linhas user/assistant: as linhas api-request-blob repetem o mesmo conteudo
    # e contariam tudo em dobro.
    $eventos = @()
    foreach ($linha in Get-Content $caminho -Encoding UTF8) {
        if ($linha -notmatch '^\{"(?:parentUuid|type)') { continue }
        try { $obj = $linha | ConvertFrom-Json } catch { continue }
        if ($obj.type -ne 'user' -and $obj.type -ne 'assistant') { continue }
        # isMeta = texto injetado (corpo de skill, aviso do sistema), nao mensagem dele.
        if ($obj.isSidechain -or $obj.isMeta) { continue }
        $eventos += $obj
    }
    return $eventos
}

function Ler-EstadoFila([string]$sessao) {
    New-Item -ItemType Directory -Force $PastaEstadoFila | Out-Null
    $arq = Join-Path $PastaEstadoFila "$sessao.txt"
    $ja = @()
    if (Test-Path $arq) { $ja = @(Get-Content $arq -Encoding UTF8) }
    return @{ Arquivo = $arq; Ja = $ja }
}

function Skills-UsadasFila($eventos) {
    # Nomes das skills usadas na sessao inteira (ferramenta Skill ou "/nome" dele).
    $nomes = @()
    foreach ($ev in $eventos) {
        $c = $ev.message.content
        if ($ev.type -eq 'user' -and $c -is [string] -and $c -match '<command-name>/([\w:-]+)') { $nomes += $Matches[1] }
        foreach ($b in @($c)) {
            if ($b.type -eq 'tool_use' -and $b.name -eq 'Skill' -and $b.input.skill) { $nomes += $b.input.skill }
            if ($b.type -eq 'text' -and $ev.type -eq 'user' -and $b.text -match '<command-name>/([\w:-]+)') { $nomes += $Matches[1] }
        }
    }
    # A skill da propria fila nao entra: avaliar/aplicar proposta e o trabalho normal dela.
    return @($nomes | ForEach-Object { ($_ -split ':')[-1] } | Where-Object { $_ -notin @('propor-melhoria', 'fila-propostas') } | Select-Object -Unique)
}

function Eh-ArquivoUsadoFila([string]$caminho, $skills) {
    $n = $caminho.ToLowerInvariant() -replace '/', '\'
    if ($n -match 'fila-propostas|\\memory\\') { return $false }
    if ([IO.Path]::GetFileName($n) -eq 'claude.md') { return $true }
    foreach ($s in $skills) { if ($n -match ('\\skills\\' + [regex]::Escape($s.ToLowerInvariant()) + '\\skill\.md$')) { return $true } }
    return $false
}

function Achar-SinaisFila($eventos, [int]$inicio, $ja) {
    $r = @{
        Correcoes = @(); Recusas = @(); Desfazer = @(); Notas = @(); Chaves = @()
        TentouEditar = @(); ApontouProblema = @()
        Edicoes = @{}; TestesFalhos = 0; TestesRodados = 0; TesteRefeito = $false; Mensagens = 0
    }
    $comandoPorId = @{}
    $skills = Skills-UsadasFila $eventos

    for ($i = $inicio; $i -lt $eventos.Count; $i++) {
        $ev = $eventos[$i]
        $blocos = @($ev.message.content)
        if ($ev.type -eq 'user' -and $ev.message.content -is [string]) {
            $blocos = @([pscustomobject]@{ type = 'text'; text = $ev.message.content })
        }

        foreach ($bloco in $blocos) {
            if ($null -eq $bloco) { continue }
            if ($ev.type -eq 'user' -and $bloco.type -eq 'text') {
                $texto = $bloco.text
                # "/skill" dele chega como <command-name>: conta como mensagem, nao como correcao.
                if ($texto -match '<command-name>/') { $r.Mensagens++; continue }
                if ($texto.TrimStart().StartsWith('<')) { continue }
                $r.Mensagens++
                $chave = "msg:$($ev.uuid)"
                if ($texto -match $padraoCorrecao -and $ja -notcontains $chave) {
                    $trecho = $texto.Substring(0, [Math]::Min(120, $texto.Length)) -replace '\s+', ' '
                    $r.Correcoes += "`"$trecho`""
                    $r.Chaves += $chave
                }
            }
            if ($ev.type -eq 'assistant' -and $bloco.type -eq 'text') {
                $k = 0
                foreach ($paragrafo in ($bloco.text -split "\n\s*\n")) {
                    $k++
                    # Fala sobre a propria fila (avaliacao, aviso) nao conta: senao o aviso se realimenta.
                    if ($paragrafo -match '(?i)proposta|fila|nota-fila|\bP\d{3}\b') { continue }
                    if ($paragrafo -notmatch $padraoProblemaFluxo) { continue }
                    $citaFluxo = $paragrafo -match '(?i)claude\.md'
                    foreach ($s in $skills) { if ($paragrafo -match ('(?i)(?<![\w-])' + [regex]::Escape($s) + '(?![\w-])')) { $citaFluxo = $true } }
                    $chave = "txt:$($ev.uuid):$k"
                    if ($citaFluxo -and $ja -notcontains $chave) {
                        $trecho = $paragrafo.Substring(0, [Math]::Min(150, $paragrafo.Length)) -replace '\s+', ' '
                        $r.ApontouProblema += "`"$trecho`""
                        $r.Chaves += $chave
                    }
                }
                foreach ($achado in [regex]::Matches($bloco.text, $padraoNota)) {
                    $nota = $achado.Groups[1].Value.Trim()
                    $chave = "nota:$nota"
                    if ($ja -notcontains $chave -and $r.Chaves -notcontains $chave) {
                        $r.Notas += $nota
                        $r.Chaves += $chave
                    }
                }
            }
            if ($bloco.type -eq 'tool_use') {
                if ($bloco.name -in @('Edit', 'Write', 'NotebookEdit') -and $bloco.input.file_path) {
                    $arq = $bloco.input.file_path
                    $r.Edicoes[$arq] = 1 + [int]$r.Edicoes[$arq]
                    $chave = "edit:$($bloco.id)"
                    if ((Eh-ArquivoUsadoFila $arq $skills) -and $ja -notcontains $chave) {
                        $r.TentouEditar += $arq
                        $r.Chaves += $chave
                    }
                }
                $c = $bloco.input.command
                if ($c) {
                    $comandoPorId[$bloco.id] = $c
                    if ($c -match $padraoTeste) {
                        $r.TestesRodados++
                        if ($r.TestesFalhos -gt 0) { $r.TesteRefeito = $true }
                    }
                    $chave = "cmd:$($bloco.id)"
                    if ($c -match $padraoDesfazer -and $ja -notcontains $chave) {
                        $r.Desfazer += $c.Substring(0, [Math]::Min(80, $c.Length))
                        $r.Chaves += $chave
                    }
                }
            }
            if ($bloco.type -eq 'tool_result') {
                $texto = ($bloco.content | Out-String)
                $chave = "recusa:$($bloco.tool_use_id)"
                if ($bloco.is_error -and $texto -match "The user doesn't want to proceed with this tool use" -and $ja -notcontains $chave) {
                    $r.Recusas += $bloco.tool_use_id
                    $r.Chaves += $chave
                }
                if ($bloco.is_error -and $comandoPorId[$bloco.tool_use_id] -match $padraoTeste) { $r.TestesFalhos++ }
            }
        }
    }
    return $r
}

function Sinais-PontuaisFila($r) {
    $s = @()
    if ($r.Correcoes.Count -gt 0) { $s += "Correcao sua (pendente na 1a vez so com marca de regra: nunca, sempre...): " + ($r.Correcoes -join ' | ') }
    if ($r.Recusas.Count -gt 0) { $s += "Voce recusou $($r.Recusas.Count) acao(oes) da IA" }
    if ($r.Desfazer.Count -gt 0) { $s += "Algo foi desfeito: " + ($r.Desfazer -join ' | ') }
    if ($r.Notas.Count -gt 0) { $s += "Nota da IA, caminho melhor (conta como atrito): " + ($r.Notas -join ' || ') }
    if ($r.TentouEditar.Count -gt 0) { $s += "A IA tentou mudar sozinha arquivo do fluxo usado na sessao (isso devia virar proposta, nao edicao): " + (($r.TentouEditar | Select-Object -Unique) -join ' | ') }
    if ($r.ApontouProblema.Count -gt 0) { $s += "A IA apontou problema num arquivo do fluxo usado na sessao: " + ($r.ApontouProblema -join ' | ') }
    return $s
}
