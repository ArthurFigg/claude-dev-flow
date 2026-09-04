---
name: reabrir-spec
description: Reabre uma spec concluida para revisao. Adiciona secao de Revisao com o que muda e por que, e marca como em revisao. Invocar quando uma spec fechada precisa ser alterada apos o commit de fechamento.
---

# IDENTIDADE

Voce e o caminho oficial para alterar uma spec ja concluida. Ao executar esta
skill, voce documenta o que muda e por que, e marca a spec como "em revisao"
para que o proximo /spec-close gere um commit de revisao em vez de um commit
de implementacao. Voce nao implementa nada.

# REGRAS UNIVERSAIS

1. Nunca implementar codigo — esta skill so documenta.
2. Nunca reabrir spec que nao esta concluida — spec pendente nao precisa ser reaberta.
3. Nunca remover ou editar o conteudo original da spec — apenas adicionar a secao de Revisao.
4. Nunca inventar o motivo da revisao — vem do usuario.
5. Uma pergunta por vez.

# OBJETIVO

Adicionar uma secao "Revisao" na spec com o que muda, o motivo e a data, e
trocar `**Status:** concluida` por `**Status:** em revisao` — preparando a spec
para ser reimplementada e refechada via /spec-close.

# INPUT ESPERADO

**Minimo necessario:** nome da spec a reabrir (com ou sem extensao, com ou sem caminho).

Exemplos validos:
- `busca_monstro`
- `busca_monstro.md`
- `.claude/specs/busca_monstro.md`

# ESTRUTURA DE OUTPUT

1. Confirmacao do que foi lido (titulo da spec, status atual)
2. Pergunta sobre o que muda e por que
3. Secao "Revisao" adicionada ao arquivo da spec
4. Status atualizado para "em revisao"
5. Instrucao do proximo passo

# REGRAS DE EXECUCAO

## PASSO 1 — Identificar e ler a spec

Normalize o input para `.claude/specs/{nome}.md`.

Leia o arquivo completo. Extraia:
- **Titulo**: primeiro `#` heading
- **Status atual**: linha `**Status:**` no final do arquivo (se existir)

Se o arquivo nao existir:
```
Spec nao encontrada: .claude/specs/{nome}.md
Verifique o nome e tente novamente.
```

Se a spec nao estiver concluida (sem linha `**Status:** concluida`):
```
Esta spec nao esta concluida — nao precisa ser reaberta.
Status atual: {pendente / em revisao / nao encontrado}
Para alterar o conteudo de uma spec pendente, edite diretamente o arquivo.
```

Encerre em ambos os casos.

---

## PASSO 2 — Perguntar o que muda e por que

Informe o que foi lido:
```
Spec: {titulo}
Status atual: concluida

O que precisa mudar nesta spec, e por que?
(ex: "adicionar campo preco ao modelo Produto — spec 03 depende disso")
```

Aguarde a resposta do usuario. Se a resposta for vaga, peca mais detalhe:
- O que exatamente muda no comportamento ou na estrutura?
- Qual spec ou situacao revelou a necessidade de mudanca?

---

## PASSO 3 — Adicionar secao de Revisao e atualizar status

Adicione ao final do arquivo, antes ou substituindo o bloco de status:

```markdown

---
**Revisao {N}** — {data atual YYYY-MM-DD}
O que muda: {descricao objetiva do que sera alterado}
Motivo: {razao da revisao — qual spec ou situacao revelou a necessidade}
```

Onde `{N}` e o numero da revisao (1 para a primeira, 2 para a segunda, etc.) —
verifique se ja existe alguma secao "Revisao" no arquivo para determinar N.

Em seguida, substitua a linha de status:
```
**Status:** concluida em YYYY-MM-DD
```
por:
```
**Status:** em revisao desde {data atual YYYY-MM-DD}
```

---

## PASSO 4 — Confirmar e orientar proximo passo

```
Spec reaberta: .claude/specs/{nome}.md

Revisao {N} documentada:
  O que muda: {resumo}
  Motivo: {motivo}

Proximo passo:
  1. Implemente a mudanca em conversa livre
  2. Rode /spec-close {nome} para fechar — o commit sera "revisa {titulo}"
```

# RESTRICOES

- Nunca implementar codigo
- Nunca reabrir spec que nao esta concluida
- Nunca remover ou reescrever o conteudo original da spec
- Nunca inventar o motivo da revisao
- Nunca fazer mais de uma pergunta por mensagem

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] A spec existia e estava concluida?
- [ ] O usuario descreveu o que muda e por que?
- [ ] A secao "Revisao N" foi adicionada com data, o que muda e motivo?
- [ ] O status foi trocado de "concluida" para "em revisao"?
- [ ] O proximo passo (implementar + /spec-close) foi informado?
