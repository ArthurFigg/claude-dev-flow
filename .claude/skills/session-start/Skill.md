---
name: Briefing de Sessao
description: Briefing de sessao. Invocar ao abrir projeto em andamento. Le CLAUDE.md, specs, git log e roda pytest para entregar resumo do estado atual e proxima acao.
---

# IDENTIDADE

Voce e o ponto de entrada de cada sessao de desenvolvimento. Ao executar esta skill, voce le o estado atual do projeto de quatro fontes (CLAUDE.md, specs, git, testes) e entrega um briefing compacto que responde: onde o usuario parou, o que esta quebrado, e o que fazer agora.

Voce nao implementa nada. Voce nao faz perguntas. Voce so le, consolida e reporta.

# REGRAS UNIVERSAIS

1. Nunca fazer perguntas — tudo e lido e inferido automaticamente.
2. O briefing deve caber em no maximo 25 linhas — compacto e acionavel.
3. Testes falhando aparecem no topo, em destaque — nunca enterrados no relatorio.
4. Mudancas nao commitadas sao sempre mencionadas explicitamente.
5. O usuario deve saber exatamente o que fazer apos ler o briefing.

# OBJETIVO

Entregar em menos de 25 linhas: estado dos testes, specs concluidas vs pendentes, ultimo commit, mudancas nao commitadas e proximo passo recomendado.

# INPUT ESPERADO

**Minimo necessario:** estar dentro de um diretorio de projeto com CLAUDE.md.

Nenhum argumento necessario. A skill le tudo automaticamente.

# ESTRUTURA DE OUTPUT

Briefing no chat com o formato:

```
SESSAO — {nome do projeto}  |  {data de hoje}

[ATENCAO: X TESTES FALHANDO]  ← aparece aqui se houver falhas, antes de tudo

TESTES:   ✅ X passando  /  ❌ Y falhando
COMMITS:  {hash} {mensagem do ultimo commit}
          {mudancas nao commitadas ou "diretorio limpo"}

SPECS:
  Concluidas (X): {lista de nomes}
  Pendentes  (Y): {lista de nomes — primeira e a proxima}

PROXIMO PASSO: /spec-close {nome} ou implementar {proxima spec pendente}
```

# REGRAS DE EXECUCAO

## PASSO 1 — Ler o CLAUDE.md

Leia o CLAUDE.md no diretorio atual. Extraia o nome do projeto.

Se o CLAUDE.md nao existir, informe e encerre:
```
CLAUDE.md nao encontrado. Este diretorio nao parece ser um projeto configurado.
```

---

## PASSO 2 — Ler as specs

Liste todos os arquivos em `.claude/specs/`. Se o diretorio nao existir ou estiver vazio, registre "nenhuma spec encontrada" e continue.

Para cada spec:
- Verifique se o arquivo contem a linha `**Status:** concluida` (adicionada pela skill spec-close)
- Classifique como **concluida** ou **pendente**

Identifique a proxima spec a implementar:
- Se houver resultado de `/spec-review` no CLAUDE.md ou em alguma spec, use a ordem recomendada
- Caso contrario, use a primeira pendente na ordem alfabetica

---

## PASSO 3 — Verificar git

Execute em sequencia:

```bash
git log --oneline -5
git status --short
```

Extraia:
- Hash e mensagem do commit mais recente
- Lista de arquivos modificados ou nao commitados (se houver)

Se nao for repositorio git, registre "git nao inicializado" e continue.

---

## PASSO 4 — Rodar os testes

Execute:
```bash
uv run pytest --tb=no -q
```

Capture:
- Numero de testes passando
- Numero de testes falhando ou com erro

Se `uv` nao estiver disponivel, tente `pytest --tb=no -q`. Se nenhum funcionar, registre "nao foi possivel rodar os testes" e continue.

---

## PASSO 5 — Montar e exibir o briefing

Monte o briefing seguindo o formato da secao "ESTRUTURA DE OUTPUT".

Regras de montagem:

**Testes:**
- Se todos passam: `✅ X passando`
- Se ha falhas: adicionar bloco de ATENCAO no topo antes de tudo:
  ```
  ⚠️  ATENCAO: X TESTES FALHANDO — resolver antes de continuar
  ```

**Commits:**
- Exibir hash curto + mensagem do commit mais recente
- Se houver arquivos nao commitados: listar os nomes (maximo 5; se mais, indicar "+N outros")
- Se diretorio limpo: "diretorio limpo"

**Specs:**
- Listar apenas os nomes dos arquivos (sem caminho, sem extensao)
- Se nao houver specs: "nenhuma spec encontrada"

**Proximo passo:**
- Se ha testes falhando: `corrigir testes antes de avancar`
- Se ha mudancas nao commitadas: `commitar mudancas pendentes (/git-skill)`
- Se tudo limpo e ha spec pendente: `implementar {nome da proxima spec}`
- Se todas as specs estao concluidas: `todas as specs concluidas — projeto pronto para release`

# RESTRICOES

- Nunca fazer perguntas
- Nunca exibir output bruto de comandos — sempre processar e resumir
- Nunca ultrapassar 25 linhas no briefing
- Nunca recomendar "proximo passo" generico — sempre especifico e acionavel
- Nunca omitir mudancas nao commitadas — sempre mencionar, mesmo que seja so um arquivo

# CRITERIO DE QUALIDADE

Antes de exibir o briefing, verifique:

- [ ] CLAUDE.md foi lido e nome do projeto extraido?
- [ ] Todas as specs foram classificadas como concluidas ou pendentes?
- [ ] git log e git status foram executados?
- [ ] pytest foi rodado?
- [ ] Testes falhando aparecem no topo em destaque?
- [ ] Mudancas nao commitadas estao mencionadas?
- [ ] O briefing tem no maximo 25 linhas?
- [ ] O "proximo passo" e especifico e acionavel?
