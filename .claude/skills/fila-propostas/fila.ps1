# Script da fila de propostas. Faz toda a parte de contas da fila, para nao depender
# do julgamento da IA: status, soma de ocorrencias, marca de regra, conferencia do
# destino e metricas. A IA so decide o que e o problema e qual texto muda.
# Motivo: nos testes de 24/10 (5 rodadas), cada ajuste no TEXTO da skill tirava um erro
# e criava outro; as falhas eram justamente nessas contas.
#
# Uso (a entrada JSON vai num arquivo UTF-8 passado em -Entrada):
#   fila.ps1 listar
#   fila.ps1 mostrar -Id P001
#   fila.ps1 registrar -Entrada x.json   {sinal, destino, problema, prova, projeto, sessao, mudanca, por_que_*, o_que_pode_quebrar, mesmo_que}
#   fila.ps1 decidir -Id P001 -Acao rejeitar|aprovar|editar|desfeita [-Backup caminho]
#   fila.ps1 alterar -Id P001 -Entrada x.json   {antes?, depois?}

param(
    [Parameter(Position = 0)][string]$Comando,
    [string]$Id,
    [string]$Acao,
    [string]$Backup,
    [switch]$Todas,
    # Entrada em arquivo UTF-8: pela entrada padrao o PowerShell 5.1 estraga acento ("nao" vira "n?o").
    [string]$Entrada,
    [string]$Arquivo = (Join-Path $HOME 'fila-propostas\fila.json')
)

$ErrorActionPreference = 'Stop'

# Teste usa outra fila (variavel de ambiente), para nunca misturar com a fila real: no teste de 24/10
# uma sessao real dele gravou proposta na fila que o teste estava zerando.
if ($env:FILA_PROPOSTAS_ARQUIVO -and -not $PSBoundParameters.ContainsKey('Arquivo')) { $Arquivo = $env:FILA_PROPOSTAS_ARQUIVO }

# Decididas por principio antes da rodada 6 nao a partir dos casos.
$marcasRegra = @('nunca', 'sempre', 'jamais', 'toda vez', 'todas as vezes', 'de agora em diante',
    'daqui pra frente', 'daqui para frente', 'sempre que', 'nunca mais',
    'always', 'never', 'every time', 'from now on')
$marcasMomento = @('hoje', 'dessa vez', 'desta vez', 'agora', 'nesse caso', 'neste caso', 'so essa',
    'por enquanto', 'this time', 'today', 'for now')

function Sair($obj) {
    $obj | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

function Sem-Acento([string]$t) {
    $d = $t.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    return (-join ($d.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' }))
}

function Tem-Marca([string]$texto, $marcas) {
    foreach ($m in $marcas) {
        if ($texto -match ('(?<![a-z])' + [regex]::Escape($m) + '(?![a-z])')) { return $true }
    }
    return $false
}

function Escopo-Correcao([string]$prova) {
    $t = Sem-Acento $prova
    $regra = Tem-Marca $t $marcasRegra
    # "agora" sozinho e momento, mas dentro de "de agora em diante" e regra.
    $semRegra = $t -replace 'de agora em diante', ''
    $momento = Tem-Marca $semRegra $marcasMomento
    if ($regra -and -not $momento) { return 'regra' }
    if ($momento -and -not $regra) { return 'momento' }
    return 'geral'
}

function Normalizar-Texto([string]$t) { return ($t -replace "`r`n", "`n").Trim() }

function Normalizar-Caminho([string]$c) {
    try { return [IO.Path]::GetFullPath($c).ToLowerInvariant() } catch { return $c.ToLowerInvariant() }
}

function Eh-Fluxo([string]$c) {
    $n = Normalizar-Caminho $c
    $nome = [IO.Path]::GetFileName($n)
    if ($nome -in @('claude.md', 'fluxo.md', 'gemini.md')) { return $true }
    # Qualquer coisa dentro de uma pasta .claude: skills, agentes, ganchos, memoria,
    # tanto a global (~/.claude) quanto a de cada projeto.
    return ($n -match '\\\.claude\\')
}

function Ler-Fila {
    if (-not (Test-Path $Arquivo)) {
        return [pscustomobject]@{
            versao = 1
            metricas = [pscustomobject]@{ criadas = 0; aprovadas = 0; editadas = 0; rejeitadas = 0; vencidas = 0; desfeitas = 0 }
            falhas_perdidas = @()
            propostas = @()
        }
    }
    $f = Get-Content $Arquivo -Raw -Encoding UTF8 | ConvertFrom-Json
    $f.propostas = @($f.propostas | Where-Object { $_ })
    $f.falhas_perdidas = @($f.falhas_perdidas | Where-Object { $_ })
    return $f
}

function Gravar-Fila($f) {
    $hoje = Get-Date
    foreach ($p in $f.propostas) {
        if ($p.status -in @('pendente', 'aguardando') -and ($hoje - [datetime]$p.criada).TotalDays -gt 90) {
            $p.status = 'vencida'
        }
    }
    # Metricas recalculadas dos status a cada gravacao: nunca descolam da fila.
    $st = @($f.propostas | ForEach-Object { $_.status })
    $f.metricas = [pscustomobject]@{
        criadas    = @($f.propostas).Count
        aprovadas  = @($st | Where-Object { $_ -eq 'aprovada' }).Count
        editadas   = @($st | Where-Object { $_ -eq 'editada' }).Count
        rejeitadas = @($st | Where-Object { $_ -eq 'rejeitada' }).Count
        vencidas   = @($st | Where-Object { $_ -eq 'vencida' }).Count
        desfeitas  = @($st | Where-Object { $_ -eq 'desfeita' }).Count
    }
    $json = $f | ConvertTo-Json -Depth 10
    $null = $json | ConvertFrom-Json
    New-Item -ItemType Directory -Force (Split-Path $Arquivo) | Out-Null
    [IO.File]::WriteAllText($Arquivo, $json, (New-Object Text.UTF8Encoding $false))
}

function Proximo-Id($f) {
    $max = 0
    foreach ($p in $f.propostas) { $n = [int]($p.id -replace '\D', ''); if ($n -gt $max) { $max = $n } }
    return 'P{0:D3}' -f ($max + 1)
}

function Ler-Entrada {
    if ($Entrada) {
        if (-not (Test-Path $Entrada)) { Sair @{ acao = 'erro'; motivo = "arquivo de entrada nao existe: $Entrada" } }
        $bruto = Get-Content $Entrada -Raw -Encoding UTF8
    }
    else { $bruto = [Console]::In.ReadToEnd() }
    if (-not $bruto.Trim()) { Sair @{ acao = 'erro'; motivo = 'entrada JSON vazia' } }
    return ($bruto | ConvertFrom-Json)
}

switch ($Comando) {
    'listar' {
        $f = Ler-Fila
        # Decididas (aprovada, rejeitada...) saem da lista; -Todas mostra tudo.
        $mostrar = @($f.propostas | Where-Object { $Todas -or $_.status -in @('pendente', 'aguardando') })
        foreach ($p in $mostrar) {
            $antes = (Normalizar-Texto $p.mudanca.antes) -replace '\s+', ' '
            "$($p.id) [$($p.status), $(@($p.ocorrencias).Count) ocorr.] $($p.destino) | $($p.problema) | antes: $($antes.Substring(0, [Math]::Min(70, $antes.Length)))"
        }
        if ($mostrar.Count -eq 0) { 'fila vazia' }
        exit 0
    }

    'mostrar' {
        $f = Ler-Fila
        $p = $f.propostas | Where-Object { $_.id -eq $Id } | Select-Object -First 1
        if (-not $p) { Sair @{ acao = 'erro'; motivo = "$Id nao existe" } }
        $p | ConvertTo-Json -Depth 6
        exit 0
    }

    'registrar' {
        $e = Ler-Entrada
        $f = Ler-Fila
        $sinaisValidos = @('correcao', 'devia', 'nota', 'desfazer', 'recusa', 'teste', 'edicao', 'conversa')
        if ($e.sinal -notin $sinaisValidos) { Sair @{ acao = 'recusado'; motivo = "sinal invalido: $($e.sinal). Use: $($sinaisValidos -join ', ')" } }
        if (-not "$($e.prova)".Trim()) { Sair @{ acao = 'recusado'; motivo = 'sem prova literal' } }
        if (-not $e.sessao) { Sair @{ acao = 'recusado'; motivo = 'falta o id da sessao (sessao)' } }

        $escopo = $null
        if ($e.sinal -eq 'correcao') { $escopo = Escopo-Correcao $e.prova }
        if ($escopo -eq 'momento') {
            Sair @{ acao = 'descartado'; motivo = 'correcao com marca de momento (hoje, dessa vez, por enquanto...): vale so para aquele caso' }
        }
        # Correcao dele sempre vira pendente: ele decide na /fila-propostas (aprova ou rejeita).
        # So a nota da IA espera repetir. Pedido em 25/10: com "aguardando" o erro pego nao chegava a ele.
        $statusNovo = 'aguardando'
        if ($e.sinal -in @('devia', 'correcao')) { $statusNovo = 'pendente' }

        # Mesmo problema: o id que a IA apontou, ou o mesmo destino com o mesmo texto 'antes'.
        $existente = $null
        if ($e.mesmo_que) {
            $existente = $f.propostas | Where-Object { $_.id -eq $e.mesmo_que } | Select-Object -First 1
            if (-not $existente) { Sair @{ acao = 'recusado'; motivo = "mesmo_que $($e.mesmo_que) nao existe na fila" } }
        }
        if (-not $existente -and $e.destino -and $e.mudanca.antes) {
            $existente = $f.propostas | Where-Object {
                (Normalizar-Caminho $_.destino) -eq (Normalizar-Caminho $e.destino) -and
                (Normalizar-Texto $_.mudanca.antes) -eq (Normalizar-Texto $e.mudanca.antes)
            } | Select-Object -First 1
        }

        $ocorrencia = [pscustomobject]@{
            data = (Get-Date -Format 'yyyy-MM-dd'); projeto = $e.projeto; sessao = $e.sessao
            sinal = $e.sinal; prova = $e.prova
        }
        if ($e.sinal -eq 'devia') {
            $f.falhas_perdidas = @($f.falhas_perdidas) + [pscustomobject]@{
                data = $ocorrencia.data; projeto = $e.projeto; frase = $e.prova; revisado = $false }
        }

        if ($existente) {
            # Correcao dele sobre problema que so a IA tinha anotado: sobe para pendente na hora.
            if ($statusNovo -eq 'pendente' -and $existente.status -eq 'aguardando') {
                $existente.status = 'pendente'
                $existente.ocorrencias = @($existente.ocorrencias) + $ocorrencia
                Gravar-Fila $f
                Sair @{ acao = 'somado'; id = $existente.id; status = 'pendente'; antes = 'aguardando'
                    ocorrencias = @($existente.ocorrencias).Count; avisar = $true }
            }
            # Ocorrencia nova = sessao diferente. Mesma sessao com outra frase nao conta 2x.
            if (@($existente.ocorrencias | Where-Object { $_.sessao -eq $e.sessao }).Count -gt 0) {
                if ($e.sinal -eq 'devia') { Gravar-Fila $f }
                Sair @{ acao = 'mesma_sessao'; id = $existente.id; status = $existente.status; avisar = $false
                    motivo = 'este problema ja tem ocorrencia desta sessao' }
            }
            $antesStatus = $existente.status
            $existente.ocorrencias = @($existente.ocorrencias) + $ocorrencia
            if ($antesStatus -in @('aprovada', 'editada')) {
                $novoId = Proximo-Id $f
                $f.propostas = @($f.propostas) + [pscustomobject]@{
                    id = $novoId; criada = $ocorrencia.data; tipo = 'desfazer'; status = 'pendente'
                    destino = $existente.destino; problema = "O atrito voltou depois de aplicar $($existente.id): $($existente.problema)"
                    ocorrencias = @($ocorrencia); mudanca = [pscustomobject]@{ antes = $existente.mudanca.depois; depois = $existente.mudanca.antes }
                    por_que_mudar = 'o problema apareceu de novo depois da mudanca aplicada'
                    por_que_melhor = 'volta ao texto anterior pelo backup'
                    o_que_pode_quebrar = 'perde o ganho da mudanca original, se ele existia'
                    desfaz = $existente.id; aplicada_em = $null; backup = $null
                }
                Gravar-Fila $f
                Sair @{ acao = 'desfazer_criado'; id = $novoId; desfaz = $existente.id; status = 'pendente'; avisar = $true }
            }
            if ($antesStatus -in @('aguardando', 'vencida')) { $existente.status = 'pendente' }
            if ($antesStatus -eq 'vencida' -and $statusNovo -eq 'aguardando') { $existente.status = 'aguardando' }
            Gravar-Fila $f
            $avisar = ($existente.status -eq 'pendente' -and $antesStatus -ne 'pendente')
            Sair @{ acao = 'somado'; id = $existente.id; status = $existente.status; antes = $antesStatus
                ocorrencias = @($existente.ocorrencias).Count; avisar = $avisar }
        }

        if (-not $e.destino -or -not (Test-Path $e.destino)) { Sair @{ acao = 'recusado'; motivo = "destino nao existe: $($e.destino)" } }
        if (-not (Eh-Fluxo $e.destino)) { Sair @{ acao = 'recusado'; motivo = 'destino nao e arquivo do fluxo (skill, agente, gancho, CLAUDE.md, memoria)' } }
        $conteudo = Normalizar-Texto (Get-Content $e.destino -Raw -Encoding UTF8)
        $antesTxt = Normalizar-Texto $e.mudanca.antes
        if (-not $antesTxt -or -not $conteudo.Contains($antesTxt)) {
            Sair @{ acao = 'recusado'; motivo = 'mudanca.antes nao existe literal no destino; copie o trecho exato do arquivo' }
        }
        if (-not "$($e.mudanca.depois)".Trim()) { Sair @{ acao = 'recusado'; motivo = 'falta mudanca.depois' } }

        $novoId = Proximo-Id $f
        $tipo = 'atrito'
        if ($e.sinal -in @('correcao', 'devia')) { $tipo = 'correcao' }
        $f.propostas = @($f.propostas) + [pscustomobject]@{
            id = $novoId; criada = $ocorrencia.data; tipo = $tipo; status = $statusNovo
            destino = $e.destino; problema = $e.problema; ocorrencias = @($ocorrencia)
            mudanca = [pscustomobject]@{ antes = $e.mudanca.antes; depois = $e.mudanca.depois }
            por_que_mudar = $e.por_que_mudar; por_que_melhor = $e.por_que_melhor
            o_que_pode_quebrar = $e.o_que_pode_quebrar
            desfaz = $null; aplicada_em = $null; backup = $null
        }
        Gravar-Fila $f
        Sair @{ acao = 'criado'; id = $novoId; status = $statusNovo; escopo = $escopo; avisar = ($statusNovo -eq 'pendente') }
    }

    'decidir' {
        $f = Ler-Fila
        $p = $f.propostas | Where-Object { $_.id -eq $Id } | Select-Object -First 1
        if (-not $p) { Sair @{ acao = 'erro'; motivo = "$Id nao existe" } }
        # Aguardando tambem pode ser decidido quando o usuario manda: quem nao mostra nem aplica
        # sozinha e a skill. Aprovar/editar continuam exigindo backup e o texto novo ja no destino.
        switch ($Acao) {
            'rejeitar' { $p.status = 'rejeitada' }
            { $_ -in @('aprovar', 'editar') } {
                if (-not $Backup -or -not (Test-Path $Backup)) { Sair @{ acao = 'erro'; motivo = 'aprovar/editar exige -Backup com a copia ja feita' } }
                $conteudo = Normalizar-Texto (Get-Content $p.destino -Raw -Encoding UTF8)
                if (-not $conteudo.Contains((Normalizar-Texto $p.mudanca.depois))) {
                    Sair @{ acao = 'erro'; motivo = 'o texto depois nao esta no destino: aplique a troca antes de decidir' }
                }
                $p.status = 'editada'
                if ($Acao -eq 'aprovar') { $p.status = 'aprovada' }
                $p.aplicada_em = (Get-Date -Format 'yyyy-MM-dd'); $p.backup = $Backup
            }
            'desfeita' {
                $orig = $f.propostas | Where-Object { $_.id -eq $p.desfaz } | Select-Object -First 1
                if ($orig) { $orig.status = 'desfeita' }
                $p.status = 'aprovada'; $p.aplicada_em = (Get-Date -Format 'yyyy-MM-dd')
            }
            default { Sair @{ acao = 'erro'; motivo = "acao invalida: $Acao" } }
        }
        Gravar-Fila $f
        Sair @{ acao = 'decidido'; id = $Id; status = $p.status; metricas = $f.metricas }
    }

    'alterar' {
        $e = Ler-Entrada
        $f = Ler-Fila
        $p = $f.propostas | Where-Object { $_.id -eq $Id } | Select-Object -First 1
        if (-not $p) { Sair @{ acao = 'erro'; motivo = "$Id nao existe" } }
        if ($e.antes) {
            $conteudo = Normalizar-Texto (Get-Content $p.destino -Raw -Encoding UTF8)
            if (-not $conteudo.Contains((Normalizar-Texto $e.antes))) { Sair @{ acao = 'erro'; motivo = 'antes novo nao existe literal no destino' } }
            $p.mudanca.antes = $e.antes
        }
        if ($e.depois) { $p.mudanca.depois = $e.depois }
        Gravar-Fila $f
        Sair @{ acao = 'alterado'; id = $Id; antes = $p.mudanca.antes; depois = $p.mudanca.depois }
    }

    default {
        'Uso: fila.ps1 listar | registrar | decidir -Id -Acao | alterar -Id'
        exit 1
    }
}
