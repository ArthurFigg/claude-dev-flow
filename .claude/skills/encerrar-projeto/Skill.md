---
name: encerrar-projeto
description: Encerramento formal de projeto. Invocar quando o projeto estiver pronto para release — nao necessariamente quando todas as specs estiverem concluidas. Roda pytest, verifica README, cria tag de versao e registra encerramento no CLAUDE.md.
---

# IDENTIDADE

Voce e o ponto final do projeto. Ao executar esta skill, voce verifica se o
projeto esta em condicoes de ser encerrado formalmente, confirma com o usuario,
e executa os passos de formalizacao: teste final, README, tag de versao e
registro no CLAUDE.md. Voce nao decide se o projeto esta pronto — isso e o
usuario que decide. Voce so formaliza a decisao dele.

# REGRAS UNIVERSAIS

1. Nunca encerrar sem confirmacao explicita do usuario.
2. Nunca criar tag se pytest falhar — sem excecoes.
3. Nunca bloquear por specs pendentes — avisar, mas deixar o usuario decidir.
4. Nunca inventar o numero de versao — sempre perguntar.
5. Nunca pular o registro no CLAUDE.md — e a fonte de verdade do estado do projeto.

# OBJETIVO

Formalizar o encerramento do projeto: pytest verde, README validado (existe e bate
com o projeto), tag de versao criada, encerramento registrado no CLAUDE.md.

# INPUT ESPERADO

Nenhum argumento necessario. A skill le tudo automaticamente.

# ESTRUTURA DE OUTPUT

1. Relatorio de estado (specs, testes, README)
2. Confirmacao explicita do usuario
3. Execucao dos passos de encerramento
4. Confirmacao final com hash da tag

# REGRAS DE EXECUCAO

## PASSO 1 — Ler o estado do projeto

Leia o CLAUDE.md e extraia o nome do projeto.

Liste todos os arquivos em `.claude/specs/` e classifique cada um:
- **concluida**: tem `**Status:** concluida`
- **em revisao**: tem `**Status:** em revisao`
- **pendente**: nenhum dos anteriores

Verifique se `README.md` existe na raiz do projeto.

Exiba o relatorio:
```
ESTADO DO PROJETO — {nome}

Specs:
  Concluidas ({N}): {lista}
  Pendentes  ({N}): {lista}  ← aparece so se houver
  Em revisao ({N}): {lista}  ← aparece so se houver

README.md: {existe / nao encontrado}
```

---

## PASSO 2 — Confirmar com o usuario

Apresente o aviso de specs pendentes se houver:
```
⚠️  {N} spec(s) pendente(s) ou em revisao. O projeto pode ser encerrado mesmo
assim — specs podem ter sido intencionalmente deixadas de fora do escopo.
```

Em seguida, pergunte:
```
Confirma que o projeto esta pronto para encerrar?
Qual sera o numero da versao? (ex: v1.0.0)
```

Aguarde a resposta. Se o usuario nao confirmar, encerre sem fazer nada.

---

## PASSO 3 — Rodar pytest final

Execute:
```bash
uv run pytest -v
```

Se qualquer teste falhar:
```
❌ Encerramento bloqueado — {N} teste(s) falhando.
Corrija os erros e rode /encerrar-projeto novamente.
```
Pare aqui.

Se todos passarem, continue.

---

## PASSO 4 — Verificar e validar o README

Um release nao pode apontar para um README quebrado, entao aqui nao basta checar
existencia — o conteudo tem que bater com o projeto real.

### Se README.md NAO existir
```
README.md nao encontrado.
Rode /readme para gerar antes de continuar, ou confirme que deseja encerrar sem README.
```
Aguarde o usuario. Se ele confirmar sem README, continue e registre a ausencia no CLAUDE.md.

### Se README.md existir — validar contra o projeto
Leia o README e confira as referencias executaveis:
- Extraia os comandos de instalacao/execucao e os arquivos que citam (ex:
  `python bestiario.py`, `python analise_bestiario.py`, `npm run build`).
- Confirme que cada arquivo/entry-point citado existe no repositorio e que o
  gerenciador mencionado bate com o real (ex: README manda `pip install` mas o
  projeto usa `uv`).
- Sinal extra de defasagem: o README nao e tocado ha varios commits de codigo
  (compare `git log -1 --format=%as -- README.md` com o ultimo commit de codigo).

Se estiver tudo coerente: registre "README.md validado." e va para o PASSO 5.

Se encontrar referencia quebrada ou defasagem, mostre os pontos concretos e pergunte:
```
O README parece desatualizado (detalhes acima). Antes de cravar a tag:
[A] Atualizar com /readme agora   [B] Encerrar com o README atual mesmo assim
```
- **[A]**: rode `/readme`, revise o resultado e **commite o README novo** — ele
  precisa estar no historico antes de a tag ser criada no PASSO 5. So entao continue.
- **[B]**: siga para o PASSO 5 com o README atual (a defasagem foi aceita pelo usuario).

---

## PASSO 4.5 — Auditar a coerencia do CLAUDE.md

Antes de cravar a tag, garanta que o CLAUDE.md descreve o estado REAL do projeto:
specs fechadas ao longo do tempo deixam o doc a derivar, e um release nao deve
apontar para documentacao que se contradiz. Varra as secoes de status e checklist
e corrija o que nao bate:
- Itens marcados como pendentes/incompletos que ja foram resolvidos (ex:
  "[ ] sem testes automatizados" com a suite verde; "implementacao nao iniciada"
  com todas as specs concluidas).
- Listas de specs que dizem "aprovada"/"pendente" quando o git e os arquivos
  mostram "concluida".
- Comandos, arquivos, schema ou stack que a evolucao do projeto removeu ou renomeou.

Se encontrar divergencias, corrija-as no CLAUDE.md e commite — essas correcoes
entram no historico ANTES da tag do PASSO 5. Se estiver tudo coerente, registre
"CLAUDE.md coerente." e siga.

Reaproveita o espirito do /auditar-claude-md, mas focado so na coerencia com o
estado atual, nao na completude de contexto.

---

## PASSO 5 — Criar tag de versao

### Verificar se a tag ja existe

```bash
git tag
```

Se a tag informada pelo usuario ja existir, avise e pergunte se quer usar outra versao. Nao sobrescreva tags existentes.

### Criar e publicar a tag

```bash
git tag {versao} -m "release {versao}"
git push origin {versao}
```

---

## PASSO 6 — Registrar encerramento no CLAUDE.md

Execute os tres comandos abaixo para coletar as estatisticas do projeto:

```bash
git rev-list --count HEAD
git log --format="%as" --reverse | head -1
git log --format="%as" | sort -u | wc -l
```

- Primeiro retorna o **total de commits**.
- Segundo retorna a **data do primeiro commit** (formato YYYY-MM-DD).
- Terceiro retorna o **numero de dias com pelo menos um commit** (dias ativos).

Use os valores coletados para preencher o bloco. Adicione ao final do CLAUDE.md do projeto:

```markdown

---
**Encerrado em:** {data YYYY-MM-DD}
**Versao:** {versao}
**Testes:** {N} passando
**Specs concluidas:** {N} de {total}
**Commits:** {N}
**Periodo:** {data primeiro commit} a {data de hoje} ({N} dias ativos)
```

---

## PASSO 7 — Confirmacao final

```
✅ Projeto encerrado.

Versao:   {versao}
Tag:      {hash da tag}
Testes:   {N} passando
README:   {existe / ausente}

Specs concluidas: {N}/{total}
{lista de specs pendentes se houver}

Commits:  {N}
Periodo:  {data primeiro commit} a {data de hoje} ({N} dias ativos)
```

# RESTRICOES

- Nunca criar tag se pytest falhar
- Nunca encerrar sem confirmacao explicita do usuario
- Nunca sobrescrever tag existente
- Nunca bloquear por specs pendentes — so avisar
- Nunca pular o registro no CLAUDE.md

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] Estado das specs foi lido e exibido?
- [ ] Usuario confirmou explicitamente e forneceu o numero da versao?
- [ ] pytest passou com zero falhas?
- [ ] README foi validado contra o projeto (existe E as referencias executaveis
      conferem), nao apenas checado por existencia?
- [ ] O CLAUDE.md foi auditado quanto a coerencia com o estado real (status de
      specs, checklists, comandos) antes da tag?
- [ ] Tag foi criada e publicada sem sobrescrever tag existente?
- [ ] Encerramento foi registrado no CLAUDE.md com data, versao, contagem de testes, commits e periodo?
- [ ] Os tres comandos git foram executados e os valores preenchidos no bloco (commits, data do primeiro commit, dias ativos)?
