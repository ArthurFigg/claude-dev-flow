---
name: spec-close
description: Fechador de spec. Invocar ao terminar a implementacao de uma spec. Roda pytest, e se passar, marca a spec como concluida e commita.
---

# IDENTIDADE

Voce e o gate entre "implementado" e "pronto". Ao executar esta skill, voce roda os testes, e so se todos passarem, marca a spec como concluida e commita. Se qualquer teste falhar, voce para completamente e nao avanca.

# REGRAS UNIVERSAIS

1. Nunca commitar se qualquer teste falhar — sem excecoes.
2. Nunca pedir confirmacao da mensagem de commit — ela e derivada da spec automaticamente.
3. Nunca marcar a spec como concluida antes do commit ser bem-sucedido.
4. Nunca pular o gate de pytest por nenhum motivo.
5. Nunca usar mensagem de commit generica — sempre derivar do titulo da spec.

# OBJETIVO

Rodar `uv run pytest -v`, e se todos os testes passarem: marcar a spec como concluida e commitar. Se falharem: exibir os erros e parar.

# INPUT ESPERADO

**Minimo necessario:** nome da spec implementada (com ou sem extensao, com ou sem caminho).

Exemplos validos que o usuario pode fornecer:
- `busca_monstro`
- `busca_monstro.md`
- `.claude/specs/busca_monstro.md`

# ESTRUTURA DE OUTPUT

**Se testes passam:**
1. Resultado do pytest resumido (X passando)
2. Relatorio do revisor-codigo (achados ou "nenhum problema")
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

Execute:
```
uv run pytest -v
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

Passe para o PASSO 3D.

---

## PASSO 3D — Revisao automatica do diff (revisor-codigo ou inline)

Antes de marcar a spec como concluida, o diff precisa ser revisado contra quatro criterios, nesta ordem de prioridade:

1. **Correcao**: o codigo faz o que a secao "Comportamento" da spec descreve? Ha caso de borda descrito na spec que nao foi tratado?
2. **Seguranca**: ha segredo hardcoded (chave de API, senha, token)? Input de usuario usado sem validacao em query, comando de shell ou path de arquivo?
3. **Escopo**: algum arquivo da secao "Nao mexer" foi alterado sem necessidade?
4. **Convencao do projeto**: se houver CLAUDE.md no diretorio, o codigo segue as convencoes dele (idioma, estrutura, tratamento de erro)?

**Decida como revisar:**
- **Se voce implementou esta spec nesta mesma sessao** (o codigo que vai ser commitado foi escrito ou editado por voce agora, nos passos anteriores desta conversa — o conteudo ja esta no seu contexto): revise inline, voce mesmo, sem chamar o agente. A leitura ja foi paga; chamar o subagente pagaria de novo um custo fixo de inicializacao por um conteudo que voce ja tem.
- **Caso contrario** (sessao retomada, implementacao nao foi feita por voce nesta conversa, ou voce nao tem certeza de ter visto o diff inteiro): chame o agente `revisor-codigo` (via Agent tool), passando o caminho da spec (`.claude/specs/{nome}.md`) e o diretorio atual.

**Ao revisar inline, combata vies de confirmacao explicitamente** — voce acabou de escrever esse codigo, entao nao assuma que esta certo so porque foi voce quem fez. Releia o diff de verdade (`git diff HEAD` + arquivos untracked, exatamente como o agente faria) como se estivesse vendo pela primeira vez, procurando ativamente motivo pra estar errado em cada um dos quatro criterios acima, nao so confirmando o que ja pensava. Nao aponte estilo subjetivo, nomes de variavel que voce faria diferente, ou reorganizacoes que nao mudam comportamento.

Aguarde o resultado (do agente ou da sua propria revisao) antes de continuar.

**Se nada for encontrado:** exiba a confirmacao e passe direto para o PASSO 4, sem perguntar nada ao usuario.

**Se um ou mais problemas forem encontrados:** exiba a lista completa e pergunte:
```
Revisao automatica encontrou o(s) problema(s) acima.
Corrigir antes de continuar, ou commitar mesmo assim? (corrigir/commitar)
```
Aguarde a resposta do usuario.

- Se o usuario responder **corrigir** (ou equivalente): pare aqui. Nao marque a spec como concluida nem commite. O usuario vai corrigir e rodar `/spec-close` novamente.
- Se o usuario responder **commitar mesmo assim** (ou equivalente): continue para o PASSO 4 normalmente.

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
- Nunca marcar spec como concluida antes do commit ter sucesso
- Nunca usar `git push --force`
- Nunca commitar arquivos `.env`, `*.key`, `secrets.*`
- Nunca executar `git add -A` sem antes verificar arquivos untracked com padroes suspeitos (`*.db`, `*.sqlite*`, `*.log`, `*.csv`, dados gerados em runtime)
- Nunca pular a verificacao visual (PASSO 1.5) quando modulos de UI forem detectados na spec
- Nunca commitar se o usuario reportar problema visual no checklist de UI
- Nunca pular a revisao do diff (PASSO 3D) antes de marcar a spec como concluida, seja ela via agente ou inline
- Nunca revisar inline assumindo que o codigo ja esta certo so porque foi voce quem escreveu — reler o diff de verdade contra os quatro criterios
- Nunca commitar se o usuario escolher "corrigir" apos ver os achados do revisor-codigo
- Nunca usar mensagem generica como "atualiza codigo" ou "correcoes"
- Nunca pular o PASSO 4.5 quando a spec tem "Impacto no CLAUDE.md" diferente de "nenhum" — o CLAUDE.md nao pode ficar descrevendo arquivos/comandos que a spec removeu

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] O arquivo da spec foi encontrado e o titulo extraido corretamente?
- [ ] O modo (implementacao ou revisao) foi detectado pelo status da spec?
- [ ] Modulos de UI foram verificados na secao "Modulos afetados"?
- [ ] Se UI detectada: checklist visual foi gerado a partir da secao "Comportamento" e confirmado pelo usuario?
- [ ] `uv run pytest -v` foi executado com output completo capturado?
- [ ] O commit foi bloqueado se houve qualquer falha ou erro nos testes?
- [ ] A revisao do diff foi feita (agente, se a implementacao nao foi feita nesta sessao, ou inline, se foi) e o relatorio exibido antes do PASSO 4?
- [ ] Se a revisao foi inline, o diff foi relido de verdade contra os quatro criterios, sem assumir que ja estava correto?
- [ ] Se o revisor encontrou problemas, o usuario foi perguntado e a escolha dele respeitada?
- [ ] Arquivos untracked com padroes suspeitos foram verificados antes do `git add -A`?
- [ ] A decisao do usuario sobre arquivos suspeitos foi aplicada antes de continuar?
- [ ] A spec foi marcada como concluida no arquivo?
- [ ] A secao "Impacto no CLAUDE.md" foi lida e, se diferente de "nenhum", as secoes indicadas foram sincronizadas antes do commit (PASSO 4.5)?
- [ ] A mensagem de commit usa "implementa" ou "revisa" conforme o modo?
- [ ] O push foi executado (ou pulado com aviso, se nao ha remote configurado)?
- [ ] Specs pendentes foram listadas na confirmacao final?
