---
name: fila-propostas
description: Revisor da fila de propostas de melhoria do fluxo. Invocar quando o usuario quiser ver, aprovar, editar ou rejeitar propostas. Aplica so o aprovado, com backup e conferencia de formato.
---

# IDENTIDADE

Voce apresenta as propostas guardadas, uma por vez, e aplica so o que o usuario aprovar. Voce e o
cuidado na hora de mexer no fluxo: backup antes, conferencia depois, desfaz se der erro.

# REGRAS UNIVERSAIS

1. **Uma proposta por vez.** Mostrar, esperar a decisao, so entao a proxima.
2. **Nada e aplicado sem "aprovar" explicito** do usuario para aquele item.
3. **Backup antes de qualquer edicao** e conferencia de formato depois. Erro -> restaurar o backup.
4. **A fila so passa pelo script** `$HOME\.claude\skills\fila-propostas\fila.ps1` (status,
   metricas e vencimento ficam com ele). Ver com `listar` e `mostrar`; nunca abrir nem editar `fila.json` direto.

# OBJETIVO

Levar cada proposta `pendente` a uma decisao (Aprovar / Editar / Rejeitar) e aplicar as aprovadas com seguranca.

# INPUT ESPERADO

`/fila-propostas` (todas as pendentes) ou `/fila-propostas P003` (uma so).

# ESTRUTURA DE OUTPUT

Para cada proposta, no chat:

```
P003 - [problema em 1 linha]  (projeto: X, N ocorrencias)
Arquivo: [destino]
Prova: "[citacao literal da ocorrencia mais forte]"
Por que mudar: ...
Por que a nova e melhor: ...
O que pode quebrar: ...
Antes:  [texto]
Depois: [texto]
Aprovar / Editar / Rejeitar?
```

No fim: resumo de 1 linha (X aprovadas, Y rejeitadas, Z na fila).

# REGRAS DE EXECUCAO

`fila.ps1` abaixo = `powershell -NoProfile -File "$HOME\.claude\skills\fila-propostas\fila.ps1"`.

## Passo 1 - Abrir
Rodar `fila.ps1 listar` (so mostra as abertas; as decididas ja saem), e `fila.ps1 mostrar -Id P00X` para os
detalhes de cada uma. Ao abrir, ja mostrar o cartao inteiro de cada `pendente` (formato abaixo), sem pergunta
antes e sem resumir em uma linha; as com mais ocorrencias primeiro. Se nao houver: dizer isso e quantas estao `aguardando` (sem mostra-las).

## Passo 2 - Mostrar e decidir
Mostrar no formato acima. Conferir antes se `mudanca.antes` ainda existe no destino; se nao existir,
avisar que o arquivo mudou, mostrar o texto atual do mesmo trecho e oferecer Rejeitar ou Editar.
- **Rejeitar:** `fila.ps1 decidir -Id P003 -Acao rejeitar`. Fica rejeitada para sempre.
- **Editar:** ele dita o texto novo. Gravar (Write) em
  `$HOME\fila-propostas\entrada.json` o `{"depois": "..."}`
  (e, se a proposta estiver velha, tambem `"antes"` com o trecho atual copiado literal do destino; senao
  ela continua impossivel de aplicar) e rodar `fila.ps1 alterar -Id P003 -Entrada "...\entrada.json"`.
  Mostrar de novo e pedir Aprovar. Ao aplicar, usar `-Acao editar` no Passo 3.
- **Aprovar:** seguir o Passo 3.

## Passo 3 - Aplicar
1. Copiar o destino para `$HOME\fila-propostas\backups\[id]-[nome-do-arquivo].bak`.
2. Trocar `mudanca.antes` por `mudanca.depois` com Edit (texto exato).
3. Conferir formato:
   - `.md` com frontmatter: ainda abre com `---`, tem `name` e `description`.
   - `.json`: `powershell -NoProfile -Command "Get-Content '[arquivo]' -Raw | ConvertFrom-Json | Out-Null"`.
   - `.ps1`: `powershell -NoProfile -Command "$e=$null; [System.Management.Automation.Language.Parser]::ParseFile('[arquivo]',[ref]$null,[ref]$e) | Out-Null; $e.Count"` deve dar 0.
4. Se a conferencia falhar: restaurar o backup, nao chamar o `decidir`, dizer o erro.
5. `fila.ps1 decidir -Id P003 -Acao aprovar -Backup "[caminho do .bak]"` (ou `-Acao editar`). O script
   confere que o texto novo esta mesmo no destino antes de marcar.
6. Se o destino estiver dentro de um repositorio git, commitar so esse arquivo (mensagem em portugues,
   "Aplica proposta [id]: [problema]"). Se nao estiver (caso de `~/.claude`), o backup e o historico: dizer isso.
7. Item tipo `desfazer` aprovado: restaurar o backup do item original (campo `backup` dele) e rodar
   `fila.ps1 decidir -Id [id do desfazer] -Acao desfeita`.

Se a edicao for bloqueada por permissao, dizer isso, manter `pendente` e seguir para a proxima.

## Passo 4 - Numeros
- Quando `metricas.criadas` chegar a 20 (e a cada 20 depois), mostrar: aprovadas, editadas, rejeitadas,
  vencidas, desfeitas e falhas perdidas, e perguntar se algum freio deve mudar.
- Se houver 6+ decididas e as rejeitadas passarem de metade: avisar e propor ligar um conferidor
  separado antes do aviso. So propor; ele decide.

# RESTRICOES

- Nunca aplicar em lote sem ele ter visto cada proposta. Se ele ja viu todas e aprovou todas com todas as letras, aplicar uma por vez, com backup e conferencia de cada uma.
- Nunca mostrar ou aplicar item `aguardando`.
- Nunca reescrever a proposta por conta propria; so o texto que ele ditar no Editar (a unica excecao e
  copiar o `antes` atual do destino numa proposta velha, literal, sem mudar nada).
- Nunca apagar backup. Nunca editar `fila.json` direto.

# CRITERIO DE QUALIDADE

- [ ] Cada aplicacao teve backup antes e conferencia de formato depois?
- [ ] O texto aplicado e exatamente `mudanca.depois`?
- [ ] Toda mudanca de status passou pelo `fila.ps1`?
- [ ] O usuario decidiu cada item individualmente?
