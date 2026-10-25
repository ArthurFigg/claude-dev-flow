# Gancho de lembrete da nota-fila. Roda a cada mensagem dele (UserPromptSubmit) e
# quando uma skill e carregada (PostToolUse do Skill). Existe porque regra so no
# CLAUDE.md pode ser esquecida (decisao 10 da fila); o gancho repete sempre.
# O gancho fila-sinais-commit.ps1 procura as linhas [nota-fila] depois do commit.

$entrada = [Console]::In.ReadToEnd() | ConvertFrom-Json
$evento = $entrada.hook_event_name

$formato = '[nota-fila] arquivo: <caminho> | passo: "<texto literal do passo>" | melhor: <o que mudaria> | por que: <motivo>'

# O filtro "o que nao anotar" veio do teste de 24/10: sem ele, a IA anotou ate na skill boa.
$naoAnotar = "Nao anote: conselho generico (boa pratica que vale pra qualquer skill), preferencia de estilo, regra que ja existe em outro arquivo do fluxo, o que o usuario ja reclamou (isso vira sinal sozinho) ou erro no codigo do projeto. Skill, agente e CLAUDE.md do PROJETO contam como fluxo."

# Rodada 6: a IA via o passo errado (ou ouvia a correcao dele) e tentava corrigir a skill sozinha,
# sem anotar. Por isso o lembrete cobre "passo errado" e proibe a correcao direta.
# Rodada 7: a IA pulou um passo ruim fazendo do jeito certo e nao avisou; o passo ficou errado no arquivo.
$desviou = "Se voce fez um passo de um jeito diferente do que esta escrito (porque o escrito era pior ou errado), anote tambem: o arquivo ficou desatualizado."
# Rede de seguranca que nao depende de idioma: a lista de palavras do gancho nao cobre toda frase
# (rodada 7: sugestao educada e espanhol passaram), mas a IA entende a correcao em qualquer lingua.
$naoEditar = "$desviou Se ele corrigir ou sugerir mudar algo que um arquivo do fluxo mandou fazer (em qualquer lingua, ate em forma de pergunta ou ironia), anote tambem, com 'por que: correcao dele: <frase dele literal>'. Nesses casos, e se um passo do fluxo estiver errado: NAO edite esse arquivo por conta propria (so se ele pedir com todas as letras); isso vira proposta."

$curto = "Lembrete fila: se um passo de skill, agente, CLAUDE.md, gancho ou memoria que voce seguiu agora estava errado, ou funcionou mas teria evitado erro, retrabalho ou passo a mais de outro jeito, escreva numa linha propria: $formato. $naoEditar $naoAnotar"

$completo = "Lembrete fila (skill carregada): ao seguir os passos desta skill, se algum estiver errado ou houver caminho melhor que evite erro, retrabalho ou passo a mais, escreva no seu texto, numa linha propria, no inicio da linha: $formato. " +
    "So com mudanca concreta e o passo citado literal. $naoEditar $naoAnotar Nunca aplique a mudanca: so anote."

if ($evento -eq 'UserPromptSubmit') {
    $texto = $curto
    # Skill chamada com /nome pelo usuario nao passa pela ferramenta Skill.
    if ("$($entrada.prompt)".TrimStart().StartsWith('/')) { $texto = $completo }
}
elseif ($evento -eq 'PostToolUse') {
    $texto = $completo
}
else {
    Write-Output "{}"
    exit 0
}

# O id da sessao vai junto porque o fila.ps1 precisa dele para nao contar a mesma sessao 2x.
[ordered]@{
    hookSpecificOutput = [ordered]@{
        hookEventName     = $evento
        additionalContext = "$texto (sessao atual: $($entrada.session_id))"
    }
} | ConvertTo-Json -Depth 5 -Compress
