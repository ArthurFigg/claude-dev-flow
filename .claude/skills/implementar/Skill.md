---
name: implementar
description: Implementa uma spec aprovada, decidindo entre fazer inline (sessao atual) ou delegar a um agente Sonnet isolado, com base no score de tamanho da spec. Invocar apos o /spec-review aprovar a spec, em vez de pedir "implemente seguindo X.md" informalmente.
---

# IDENTIDADE

Voce e o ponto de decisao entre "spec aprovada" e "codigo escrito". Voce nao revisa (isso e o `/spec-review`) nem commita (isso e o `/spec-close`) — voce so decide *como* implementar e garante que a implementacao aconteca, seja voce mesmo ou um agente isolado.

# OBJETIVO

Dado o nome de uma spec aprovada, decidir entre implementar inline (na sessao atual) ou delegar ao agente `implementador-spec`, baseado no score de tamanho da spec — e entregar o codigo implementado e testado ao final, dos dois jeitos.

# INPUT ESPERADO

**Minimo necessario:** nome da spec (com ou sem extensao, com ou sem caminho), igual ao `/spec-close`.

# ESTRUTURA DE OUTPUT

1. Confirmacao do modo escolhido (inline ou agente) com o motivo (score)
2. Resultado da implementacao (arquivos criados/modificados, testes)
3. Instrucao pra proximo passo (`/spec-close`)

# REGRAS DE EXECUCAO

## PASSO 1 — Ler a spec e confirmar aprovacao

Normalize o input pro caminho `.claude/specs/{nome}.md`. Leia o arquivo completo.

Se `**Revisão:**` nao estiver `aprovada`, pare e informe:
```
Esta spec ainda nao foi aprovada (Revisão: {status atual}).
Rode /spec-review antes de implementar.
```

## PASSO 2 — Obter o score de tamanho

Verifique se o campo `**Score:**` existe no cabecalho da spec.

**Se existir:** use o valor direto, nao recalcule.

**Se nao existir** (spec criada antes desta regra): calcule usando os mesmos criterios do `/spec` (PASSO 3.7) a partir da secao "Modulos afetados":

| Item | Pontos |
|---|---|
| Cada arquivo Python significativo (>30 linhas esperadas) | +1 |
| Cada template HTML | +1 |
| Cada arquivo CSS | +1 |
| Arquivo JavaScript nao-trivial (>50 linhas esperadas) | +2 |
| Arquivo JavaScript trivial (<50 linhas) | +1 |

Adicione o campo `**Score:** {valor}` ao cabecalho da spec (junto de `Ordem`/`Depende de`/`Revisão`), pra futuras chamadas nao precisarem recalcular.

## PASSO 3 — Decidir e executar

O score conta arquivos, um proxy grosseiro do volume de escrita. Antes de decidir,
faca um ajuste de bom senso: se o numero de arquivos e o volume real esperado
divergem muito — poucos arquivos mas muito codigo (ex: 1 modulo de ~300 linhas) ou
muitos arquivos triviais (ex: 6 de ~30 linhas) — voce pode mover a decisao em ate
1 ponto na direcao do volume real, anunciando o motivo. O score persistido no
cabecalho NAO muda; so a decisao inline/agente desta execucao. Na duvida, siga o score.

**Score ≤ 5 — implemente inline, voce mesmo:**

Siga a spec diretamente: "Comportamento", "Criterios verificaveis", "Modulos afetados", "Nao mexer". Leia o CLAUDE.md do projeto pras convencoes. Escreva os testes junto com o codigo. Rode os testes antes de reportar.

Anuncie antes de comecar:
```
Score {X} — implementando inline (abaixo do custo de delegar a um agente).
```

**Score ≥ 6 — delegue ao agente:**

Chame o agente `implementador-spec` (via Agent tool), passando o caminho da spec e o diretorio do projeto. Aguarde o relatorio completo.

Anuncie antes de disparar:
```
Score {X} — delegando ao agente implementador-spec (Sonnet).
```

Exiba o relatorio recebido do agente integralmente ao usuario.

## PASSO 4 — Orientar proximo passo

Ao final (inline ou via agente), com os testes passando:
```
Implementacao concluida. Para fechar: /spec-close {nome da spec}
```

Se os testes nao passaram (nem apos autoverificacao, no caso do agente), exiba os erros e nao sugira `/spec-close` ainda — o gate de testes dele vai bloquear mesmo assim, mas nao adianta rodar sabendo que vai falhar.

# RESTRICOES

- Nunca commitar nada — isso e exclusividade do `/spec-close`
- Nunca implementar spec com `Revisão` diferente de `aprovada`
- Nunca recalcular o score se o campo `**Score:**` ja existir no arquivo
- Nunca pular a leitura do CLAUDE.md antes de implementar inline
- Nunca omitir o relatorio do agente quando a implementacao for delegada

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] A spec foi confirmada como `aprovada` antes de qualquer implementacao?
- [ ] O score foi lido do campo existente ou calculado e persistido, nunca recalculado a toa?
- [ ] A decisao inline/agente foi anunciada com o motivo (score, mais o ajuste de bom senso se houve)?
- [ ] Os testes foram rodados e o resultado real (nao suposto) foi reportado?
- [ ] O proximo passo (`/spec-close`) so foi sugerido se os testes passaram?
