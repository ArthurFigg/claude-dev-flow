---
name: spec-close
description: Fechador de spec. Invocar ao terminar a implementacao de uma spec. Roda pytest, e se passar, marca a spec como concluida e commita.
---

# IDENTIDADE

Voce e o gate entre "implementado" e "pronto". Ao executar esta skill, voce roda os testes, e so se todos passarem, marca a spec como concluida e commita. Se qualquer teste falhar, voce para completamente e nao avanca.

# REGRAS UNIVERSAIS

1. Nunca commitar se qualquer teste falhar — sem excecoes.
2. Nunca pedir confirmacao da mensagem de commit — ela e derivada da spec automaticamente.
3. A marcacao de concluida (PASSO 4) entra no mesmo commit; se o commit falhar, desfaca a marcacao.
4. Nunca pular o gate de pytest por nenhum motivo.
5. Nunca usar mensagem de commit generica — sempre derivar do titulo da spec.

# OBJETIVO

Rodar o comando de teste do projeto, e se todos os testes passarem: marcar a spec como concluida e commitar. Se falharem: exibir os erros e parar.

# INPUT ESPERADO

**Minimo necessario:** nome da spec implementada (com ou sem extensao, com ou sem caminho).

Exemplos validos que o usuario pode fornecer:
- `busca_monstro`
- `busca_monstro.md`
- `.claude/specs/busca_monstro.md`

# ESTRUTURA DE OUTPUT

**Se testes passam:**
1. Resultado do pytest resumido (X passando)
2. Veredito do relatorio da Etapa 4 (ou achados do revisor-codigo, quando nao ha relatorio)
3. Spec marcada como concluida no arquivo
4. Commit criado e push executado
5. Confirmacao com hash do commit

**Se testes falham:**
1. Resultado do pytest com erros listados claramente
2. Mensagem de bloqueio explicita
3. Instrucao para corrigir e rodar novamente

# REGRAS DE EXECUCAO

## PASSO 1 — Identificar e ler a spec

Normalize o input do usuario para o caminho `.claude/specs/{nome}.md`.

Leia o arquivo completo. Extraia:
- **Titulo da feature**: conteudo do primeiro `#` heading (ex: `# Busca de Monstro por Nome` → `busca de monstro por nome`)
- **Descricao curta**: primeira linha da secao "O que faz"
- **Modo**: verifique a linha `**Status:**` no arquivo:
  - Se contiver `em revisao` → modo **revisao** (commit sera "revisa {titulo}")
  - Caso contrario → modo **implementacao** (commit sera "implementa {titulo}")

Se o arquivo nao existir, informe o usuario e encerre:
```
Spec nao encontrada: .claude/specs/{nome}.md
Verifique o nome e tente novamente.
```

---

## PASSO 1.5 — Verificacao visual de UI (somente para specs com componentes de interface)

Leia a secao "Modulos afetados" da spec. Verifique se algum arquivo listado
sugere componente de UI — procure por nomes contendo: `janela`, `tela`, `frame`,
`widget`, `_ui`, `painel`, `formulario`, `dialogo`, `menu`, `toolbar`, `canvas`.

Se **nenhum modulo de UI for detectado**: pule este passo e va para o PASSO 2.

Se **modulos de UI forem detectados**:

Leia a secao "Comportamento" da spec e filtre os itens com efeito visual
observavel — comportamentos que descrevem o que o usuario ve ou interage,
nao logica interna. Exemplos de itens visuais: "exibe lista de resultados",
"botao aparece desabilitado", "campo e limpo apos submit", "janela redimensiona
sem quebrar layout".

Gere o checklist a partir desses itens e exiba:

```
Componentes de UI detectados: {lista de modulos}

Abra o app (ou preview.py se existir) e verifique cada item antes de continuar:

  [ ] {comportamento visual 1 extraido da spec}
  [ ] {comportamento visual 2 extraido da spec}
  [ ] {comportamento visual N extraido da spec}
  [ ] Widgets com side="right" estao visiveis (nao sumidos atras de frame expansivel)
  [ ] Redimensionar a janela nao quebra o layout

Todos os itens foram verificados na interface? (s/n)
```

Aguarde a resposta do usuario.

Se o usuario responder **nao** ou indicar que encontrou problema visual:
```
❌ Commit bloqueado — problema visual reportado.
Corrija o problema na interface e rode /spec-close novamente.
```
Pare aqui.

Se o usuario responder **sim**: continue para o PASSO 2.

---

## PASSO 2 — Rodar os testes

O comando de teste e o do CLAUDE.md do projeto quando ele define um (secao "Comando de teste deste projeto" ou equivalente); sem isso, `uv run pytest -v`. Execute:
```
uv run pytest -v   # ou o comando do CLAUDE.md do projeto
```

Aguarde a conclusao completa. Capture o output inteiro.

Exiba um resumo no chat:
```
Resultado dos testes:
✅ [X] passando
❌ [Y] falhando
⚠️  [Z] erros
```

---

## PASSO 3A — Se testes falham (qualquer falha ou erro)

Liste cada teste com falha ou erro, com o traceback resumido.

Encerre com:
```
❌ Commit bloqueado — [Y] teste(s) falhando.
Corrija os erros acima e rode /spec-close novamente.
```

**Pare aqui. Nao execute os passos seguintes.**

---

## PASSO 3B — Se todos os testes passam

Exiba:
```
✅ [X] testes passando.
```

Passe para o PASSO 3C.

---

## PASSO 3C — Relatorio da Etapa 4 (o que o usuario aprovou)

Procure `.claude/specs/_relatorios/{nome}.md` (gravado pelo `/implementar`, PASSO 8).

- **Existe:** mostre a linha do veredito. Compare o total de testes do PASSO 2 com o da
  secao 3 do relatorio. Se o veredito nao for `CUMPRE` ou os totais nao baterem, pare e
  pergunte se segue — o usuario aprovou outra coisa. O relatorio e o `{nome}-pytest.txt`
  entram no commit (o `git add -A` do PASSO 5 ja inclui): ficam como prova do que foi
  aprovado, ligado a spec.
- **Nao existe** (spec implementada antes de 10/10 ou fora do `/implementar`): avise em
  uma linha e siga; o PASSO 3D chama o `revisor-codigo`.

Passe para o PASSO 3D.

---

## PASSO 3D — Conferencia do diff

O codigo ja foi lido contra a spec pelo Claude dentro do `/implementar` (camada 3), e os testes acabaram de rodar (PASSO 2). Aqui so o que falta:

1. **"Nao mexer":** rode `git diff HEAD --name-only` + `git ls-files --others --exclude-standard` e confira se algum arquivo listado na secao "Nao mexer" da spec foi alterado. Arquivo que tambem esta em "Modulos afetados" nao conta (confira o trecho lendo o diff).
2. **Se nao ha relatorio da Etapa 4 (PASSO 3C) ou esta sessao NAO rodou o `/implementar` desta spec:** chame o agente `revisor-codigo` (via Agent tool), passando o caminho da spec e o diretorio atual — ninguem leu o codigo nesta sessao.
3. **Arquivos soltos fora do git** (mais velhos que o ultimo commit, sem relacao com a spec): liste em uma linha e sugira commitar ou pôr no `.gitignore`.

**Se algo foi encontrado:** exiba a lista completa e pergunte:
```
A conferencia encontrou o(s) problema(s) acima.
Corrigir antes de continuar, ou commitar mesmo assim? (corrigir/commitar)
```
- **corrigir:** pare aqui. Nao marque a spec como concluida nem commite.
- **commitar mesmo assim:** continue para o PASSO 4.

**Se nada foi encontrado:** siga para o PASSO 4.

---

## PASSO 4 — Marcar spec como concluida

Adicione ao final do arquivo `.claude/specs/{nome}.md`:

```markdown

---
**Status:** concluida em YYYY-MM-DD
```

Use a data atual no formato `YYYY-MM-DD`.

---

## PASSO 4.5 — Sincronizar o CLAUDE.md

Leia a secao "Impacto no CLAUDE.md" da spec `.claude/specs/{nome}.md`.

- Se a secao nao existir (spec criada antes desta regra) ou disser "nenhum": pule este passo e va para o PASSO 5.
- Caso contrario: para cada par "{secao} → {atualizacao}", aplique a mudanca correspondente na secao indicada do CLAUDE.md do projeto. Depois releia o trecho alterado e confirme que ele descreve o estado **pos-implementacao** — nenhuma referencia a arquivo, comando, schema ou tecnologia que a spec removeu ou renomeou.

Exiba um resumo do que foi sincronizado:
```
CLAUDE.md sincronizado: {lista de secoes atualizadas}
```

O CLAUDE.md atualizado entra no mesmo commit da spec — o `git add -A` do PASSO 5 ja o inclui.

---

## PASSO 4.6 — Promover decisao transversal (na maioria das specs, nao faz nada)

Releia a secao "Decisoes tomadas" da spec que voce esta fechando e aplique a UMA
pergunta do criterio de corte em `~/.claude/templates/_decisoes.md`:

> A decisao restringe codigo que ainda vai ser escrito, em mais de uma spec?

**O caso normal e nenhuma passar.** Decisao de spec e quase sempre local — nome de
arquivo, formato de saida, onde a funcao mora. Ela ja esta registrada na spec, que
e o lugar certo. Nao force promocao: arquivo de decisao transversal com decisao
local dentro perde a propriedade que o torna util (ler cinco entradas e entender o
projeto).

Promova apenas quando, durante a implementacao, apareceu uma decisao que **as
proximas specs vao ter que respeitar** — tipicamente porque a spec criou uma
camada, um contrato interno ou um padrao que os modulos seguintes herdam.

Ao promover: escreva a entrada no formato do template, redigida para quem nunca viu
a spec de origem (criterio de legibilidade — entrada auto-contida, sem "conforme a
Spec 4"). Nao copie o texto da spec; a spec fala com quem implementa aquela feature,
o `_decisoes.md` fala com quem vai escrever a proxima.

Se promoveu, informe em uma linha:
```
Promovida a _decisoes.md: {titulo da entrada}
```

O `_decisoes.md` entra no mesmo commit — o `git add -A` do PASSO 5 ja o inclui.

---

## PASSO 4.7 — Registrar a mudanca no CHANGELOG

Acrescente uma linha em `CHANGELOG.md` na raiz, dentro de `## [Nao lancado]`.

**Se o arquivo nao existir, crie com este cabecalho:**

```markdown
# Changelog

Todas as mudancas notaveis deste projeto sao registradas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) e o
projeto adere ao [Versionamento Semantico](https://semver.org/).

## [Nao lancado]
```

**A categoria sai do modo detectado no PASSO 1:**

| Modo | Categoria | Excecao |
|---|---|---|
| implementacao | `### Adicionado` | Se a spec substitui comportamento que ja existia, use `### Modificado` |
| revisao | `### Modificado` | Se a secao "Revisao" da spec descreve conserto de comportamento errado, use `### Corrigido` |

Crie a subsecao `###` so quando ela ainda nao existir em `[Nao lancado]`.

**A linha e escrita em nivel de usuario**, nao de implementacao. A "Descricao
curta" extraida no PASSO 1 e o ponto de partida, mas ela foi escrita para quem ia
implementar — reescreva para quem **usa** o projeto:

- Sem nome de modulo, arquivo, classe ou funcao
- Sem numero nem nome de spec
- O que a pessoa passa a conseguir fazer, nao o que foi construido

```
❌ Implementa o nucleo de consulta em `bestiario/consultas.py`, compartilhado
   entre CLI e web (Spec 7a)
✅ Filtro por tipo, desafio e ambiente agora funciona igual no terminal e no site
```

Se a spec ja tiver uma linha em `[Nao lancado]` (caso de spec reaberta e fechada
de novo), **atualize a linha existente** em vez de acrescentar uma segunda.

Se a mudanca nao for perceptivel por quem usa o projeto — refatoracao pura, ajuste
de teste, reorganizacao de pasta — **nao escreva nada**. Keep a Changelog e
explicito: o arquivo registra mudanca notavel para humano, e ruido nele custa mais
que a ausencia de uma linha. O `git log` continua guardando tudo.

O `CHANGELOG.md` entra no mesmo commit — o `git add -A` do PASSO 5 ja o inclui.

---

## PASSO 5 — Commitar

### Verificar arquivos sensiveis

Execute `git status` e verifique se ha arquivos `.env`, `*.key`, `secrets.*` em qualquer estado (staged, modificado ou untracked). Se sim, pare e avise o usuario antes de continuar.

### Verificar .gitignore

Se `__pycache__/`, `.venv/`, `*.pyc`, `.pytest_cache/`, `.ruff_cache/` aparecerem no status sem estar no `.gitignore`, adicione-os ao `.gitignore` antes de continuar.

### Verificar arquivos de dados gerados em runtime

Execute `git status --porcelain` e filtre as linhas que comecem com `??` (arquivos untracked). Para cada arquivo untracked, verifique se o nome bate em algum dos padroes abaixo:

Padroes suspeitos: `*.db`, `*.sqlite`, `*.sqlite3`, `*.log`, `*.csv`, `*.json` fora de diretorios de codigo fonte (`src/`, `tests/`), arquivos em `dados/`, `banco/`, `logs/`, `exports/`, `output/`, `temp/`.

Se nenhum arquivo suspeito for encontrado: continue normalmente.

Se houver arquivos suspeitos: liste-os e pergunte ao usuario o que fazer antes de continuar:

```
Arquivos nao rastreados com padrao suspeito encontrados:
  ?? banco/dados.db
  ?? logs/app.log

Para cada um, escolha:
  [G] Adicionar ao .gitignore (nao entra neste commit nem nos proximos)
  [I] Ignorar desta vez (nao entra neste commit, mas tambem nao vai pro .gitignore)
  [A] Adicionar ao commit mesmo assim

Aguardando sua decisao antes de continuar.
```

Aplique as decisoes do usuario antes de executar o `git add -A`.

### Staged area

```bash
git add -A
```

### Gerar mensagem de commit

Use o titulo extraido da spec no PASSO 1, em letras minusculas, no imperativo.
O prefixo depende do **modo** detectado no PASSO 1:

**Modo implementacao** (primeira vez que a spec e fechada):
- `# Busca de Monstro por Nome` → `implementa busca de monstro por nome`
- `# Tratamento de Erros HTTP` → `implementa tratamento de erros HTTP`

**Modo revisao** (spec estava "em revisao" via /reabrir-spec):
- `# Busca de Monstro por Nome` → `revisa busca de monstro por nome`
- `# Tratamento de Erros HTTP` → `revisa tratamento de erros HTTP`

Regras da mensagem:
- Comeca com "implementa " ou "revisa " conforme o modo
- Sem prefixos de tipo (`feat:`, `fix:`, etc.)
- Maximo 72 caracteres
- Em portugues

### Commit

```bash
git commit -m "implementa {titulo da spec}"
```

### Push (somente se houver remote)

O commit acima ja fechou a spec localmente — a ausencia de remote nao e falha, e o trabalho nao pode ser tratado como perdido. Verifique antes de empurrar:

```bash
git remote
```

**Se nao houver saida (nenhum remote configurado):** pule o push. Avise e siga para o PASSO 6:
```
Commit local feito e spec fechada. Nenhum remote configurado — push pulado.
Configure com `git remote add origin <url>` e rode `git push -u origin HEAD`.
```

**Se houver remote:** empurre.
```bash
git push origin HEAD
```
Se for o primeiro push no branch:
```bash
git push -u origin HEAD
```

---

## PASSO 6 — Confirmar

```
✅ Spec concluida e commitada.

Spec:   .claude/specs/{nome}.md
Commit: implementa {titulo}
Hash:   {hash curto}
```

Se houver outras specs em `.claude/specs/` sem status de concluida, liste-as:
```
Specs pendentes: [lista]
```

# RESTRICOES

- Nunca commitar se qualquer teste falhar
- Nunca pedir confirmacao da mensagem de commit
- Nunca deixar a spec marcada como concluida se o commit falhar — desfaca a marcacao
- Nunca usar `git push --force`
- Nunca commitar arquivos `.env`, `*.key`, `secrets.*`
- Nunca executar `git add -A` sem antes verificar arquivos untracked com padroes suspeitos (`*.db`, `*.sqlite*`, `*.log`, `*.csv`, dados gerados em runtime)
- Nunca pular a verificacao visual (PASSO 1.5) quando modulos de UI forem detectados na spec
- Nunca commitar se o usuario reportar problema visual no checklist de UI
- Nunca pular a conferencia do diff (PASSO 3D) antes de marcar a spec como concluida
- Nunca commitar se o usuario escolher "corrigir" apos ver os achados do revisor-codigo
- Nunca usar mensagem generica como "atualiza codigo" ou "correcoes"
- Nunca pular o PASSO 4.5 quando a spec tem "Impacto no CLAUDE.md" diferente de "nenhum" — o CLAUDE.md nao pode ficar descrevendo arquivos/comandos que a spec removeu

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] O arquivo da spec foi encontrado e o titulo extraido corretamente?
- [ ] O modo (implementacao ou revisao) foi detectado pelo status da spec?
- [ ] Modulos de UI foram verificados na secao "Modulos afetados"?
- [ ] Se UI detectada: checklist visual foi gerado a partir da secao "Comportamento" e confirmado pelo usuario?
- [ ] O comando de teste do projeto (padrao `uv run pytest -v`) foi executado com output completo capturado?
- [ ] O commit foi bloqueado se houve qualquer falha ou erro nos testes?
- [ ] O relatorio da Etapa 4 (PASSO 3C) foi lido, com veredito e total de testes conferidos?
- [ ] A conferencia do diff (PASSO 3D) foi feita e o resultado exibido antes do PASSO 4?
- [ ] Se o revisor encontrou problemas, o usuario foi perguntado e a escolha dele respeitada?
- [ ] Arquivos untracked com padroes suspeitos foram verificados antes do `git add -A`?
- [ ] A decisao do usuario sobre arquivos suspeitos foi aplicada antes de continuar?
- [ ] "Nao mexer" conferido, e o `revisor-codigo` chamado se esta sessao nao rodou o `/implementar`?
- [ ] A spec foi marcada como concluida no arquivo?
- [ ] A secao "Impacto no CLAUDE.md" foi lida e, se diferente de "nenhum", as secoes indicadas foram sincronizadas antes do commit (PASSO 4.5)?
- [ ] As "Decisoes tomadas" da spec passaram pelo criterio de corte (PASSO 4.6), promovendo so o que restringe mais de uma spec — e nada, se for o caso?
- [ ] A linha do CHANGELOG foi escrita em nivel de usuario (sem modulo, arquivo ou numero de spec) — ou omitida, se a mudanca nao e perceptivel por quem usa?
- [ ] A mensagem de commit usa "implementa" ou "revisa" conforme o modo?
- [ ] O push foi executado (ou pulado com aviso, se nao ha remote configurado)?
- [ ] Specs pendentes foram listadas na confirmacao final?
