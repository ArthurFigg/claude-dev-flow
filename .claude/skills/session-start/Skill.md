---
name: session-start
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

Entregar em menos de 25 linhas: estado dos testes, specs concluidas vs pendentes, ultimo commit, mudancas nao commitadas, resumo da seção de status do CLAUDE.md (reconciliada com git/specs) e proximo passo recomendado.

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

CLAUDE.md: {item pendente mais relevante da seção de status, em 1 linha — ou "sem seção de status"}
{⚠️ linha de divergencia — só aparece se o status escrito contradiz git/specs}

PROXIMO PASSO: {acao especifica — ver regras no PASSO 5}
```

# REGRAS DE EXECUCAO

## PASSO 1 — Ler o CLAUDE.md

Leia o CLAUDE.md no diretorio atual. Extraia:
- **Nome do projeto**
- **Seção de status escrita à mão**, se houver — a parte onde o usuario registra o que ja foi feito e o que falta (titulos tipicos: "Status", "Próximos passos", "O que falta", "Estado atual", "Histórico de sessões", "Roadmap", ou um checklist de features). É o registro humano da intencao — vale mais que qualquer inferencia automatica de git/specs.

Se houver seção de status, identifique o item pendente mais relevante (o proximo trabalho declarado por escrito). Se nao houver nenhuma seção assim, registre "sem seção de status" e siga — o proximo passo virá só de specs/git.

Se o CLAUDE.md nao existir, informe e encerre:
```
CLAUDE.md nao encontrado. Este diretorio nao parece ser um projeto configurado.
```

---

## PASSO 2 — Ler as specs

Liste todos os arquivos em `.claude/specs/`. Se o diretorio nao existir ou estiver vazio, registre "nenhuma spec encontrada" e continue.

Execute tambem:
```bash
git log --oneline --all
```
Extraia todas as mensagens de commit que comecem com "implementa " — cada uma corresponde a uma spec fechada pelo `/spec-close`.

Para cada spec, classifique usando as duas fontes:

| Arquivo diz | Git diz | Classificacao | Acao |
|---|---|---|---|
| concluida | commit existe | **concluida** | normal |
| pendente | commit existe | **concluida** (git prevalece) | avisar divergencia no briefing |
| concluida | commit nao existe | **concluida** (arquivo prevalece) | normal |
| pendente | commit nao existe | **pendente** | normal |

Quando o git contradizer o arquivo (linha `**Status:** concluida` ausente mas commit "implementa {nome}" existe), registre no briefing:
```
⚠️  Divergencia detectada: {nome} tem commit de implementacao mas Status ausente no arquivo.
```

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

**CLAUDE.md (seção de status):**
- Se ha seção de status escrita à mao: resuma em 1 linha o item pendente mais relevante. **Nunca copie a seção inteira** — sempre resuma.
- Reconcilie com o estado automatico. Se o status escrito contradiz git/specs, adicione uma linha de divergencia logo abaixo:
  `⚠️  CLAUDE.md diz "{trecho}" mas {o que git/specs mostram} — status pode estar desatualizado`
  Exemplos: status diz "falta implementar X" mas existe commit `implementa X` e a spec esta concluida; status diz "projeto pronto" mas ha spec pendente.
- Se nao ha seção de status: linha `CLAUDE.md: sem seção de status`.

**Proximo passo** (primeira condicao que se aplicar, nesta ordem):
- Testes falhando: `corrigir testes antes de avancar`
- Mudancas nao commitadas de uma spec em andamento: `fechar com /spec-close {nome}`; se forem mudancas avulsas: `commitar com /git-skill`
- Spec pendente com `**Revisão:**` diferente de `aprovada`: `/spec-review antes de implementar {nome}`
- Spec pendente ja aprovada: `/implementar {nome da proxima spec}`
- Todas as specs concluidas: `todas as specs concluidas — considerar /encerrar-projeto`
- Item do status do CLAUDE.md que nao corresponde a nenhuma spec (trabalho ainda nao especificado): `especificar "{item}" com /spec`

# RESTRICOES

- Nunca fazer perguntas
- Nunca exibir output bruto de comandos — sempre processar e resumir
- Nunca ultrapassar 25 linhas no briefing
- Nunca recomendar "proximo passo" generico — sempre especifico e acionavel
- Nunca omitir mudancas nao commitadas — sempre mencionar, mesmo que seja so um arquivo
- Nunca copiar a seção de status do CLAUDE.md inteira — sempre resumir em 1 linha
- Nunca deixar de sinalizar quando o status escrito no CLAUDE.md contradiz o que git/specs mostram

# CRITERIO DE QUALIDADE

Antes de exibir o briefing, verifique:

- [ ] CLAUDE.md foi lido, nome do projeto extraido e a seção de status (se houver) resumida em 1 linha?
- [ ] Divergencia entre o status escrito no CLAUDE.md e o estado real (git/specs) foi sinalizada, se houver?
- [ ] Todas as specs foram classificadas cruzando arquivo E git log?
- [ ] Divergencias entre arquivo e git foram reportadas no briefing?
- [ ] git log e git status foram executados?
- [ ] pytest foi rodado?
- [ ] Testes falhando aparecem no topo em destaque?
- [ ] Mudancas nao commitadas estao mencionadas?
- [ ] O briefing tem no maximo 25 linhas?
- [ ] O "proximo passo" e especifico e acionavel?
