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

Se estiver tudo coerente: registre "README.md validado." e siga para a verificacao
de diagrama abaixo.

### Verificar o diagrama de arquitetura
Um release e a hora em que alguem de fora vai abrir o repositorio pela primeira
vez, entao o mapa do projeto deveria estar la. Checagem simples, sem avaliar
merito — quem decide se o projeto merece diagrama e a propria `/diagrama`:

1. O README contem `<!-- diagrama:inicio -->`? Se sim, esta coberto — siga.
2. Se nao: o `CLAUDE.md` do projeto tem a linha `Diagrama: nao se aplica`? Se sim,
   a decisao ja foi tomada — siga sem perguntar.
3. Se nenhum dos dois, pergunte:
```
Este README nao tem diagrama de arquitetura, e nao ha registro de que isso foi
avaliado. Antes de cravar a tag:
[A] Rodar /diagrama agora   [B] Encerrar sem diagrama
```
- **[A]**: rode `/diagrama`, confira o resultado em mermaid.live e **commite**
  antes de continuar — ele precisa estar no historico antes da tag do PASSO 5.
- **[B]**: siga para o PASSO 5 (a ausencia foi aceita pelo usuario).

Atencao na rota `[A]` da defasagem de README acima: se voce mandar rodar `/readme`
num projeto que ja tem diagrama, confirme depois que a faixa entre os marcadores
sobreviveu a regeracao. Regerar o README sem preservar essa faixa apaga o diagrama.

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

## PASSO 4.7 — Fechar o CHANGELOG na versao

### Se `CHANGELOG.md` existe e `## [Nao lancado]` tem conteudo

Renomeie `## [Nao lancado]` para `## [{versao}] - {data de hoje YYYY-MM-DD}` e
abra um `## [Nao lancado]` vazio acima dele. As subsecoes (`### Adicionado`,
`### Modificado`, `### Corrigido`) descem junto, intactas — elas foram escritas
pelo `/spec-close` no momento de cada fechamento e nao devem ser reformuladas
agora.

### Se `CHANGELOG.md` nao existe, ou `[Nao lancado]` esta vazio — BACKFILL

Acontece em projeto que ja andou antes do CHANGELOG existir no fluxo. Rode uma
vez e nunca mais:

```bash
git log --oneline {ultima tag}..HEAD
```

Se nao houver tag anterior, use `git log --oneline` inteiro.

Reconstrua as entradas a partir dos commits `implementa {titulo}` / `revisa
{titulo}` — cada um corresponde a uma spec fechada. Para cada commit, **leia a
secao "O que faz" da spec correspondente em `.claude/specs/`** e escreva a linha
a partir dela, nao a partir da mensagem de commit. A mensagem esta em nivel de
implementacao ("implementa nucleo de consulta"); a spec tem o nivel de usuario, que
e o que o CHANGELOG pede.

Marque a secao reconstruida, para quem ler saber que ela nao foi escrita no
momento das mudancas:

```markdown
## [v1.0.0] - 2026-08-05

> Secao reconstruida a partir do historico do projeto. As versoes seguintes sao
> registradas conforme cada mudanca acontece.

### Adicionado
- ...
```

Use o cabecalho do arquivo definido no PASSO 4.7 do `/spec-close` quando precisar
criar o `CHANGELOG.md` do zero.

### Em qualquer dos casos

Nao invente entrada para mudanca que nao e perceptivel por quem usa o projeto —
refatoracao, ajuste de teste, reorganizacao de pasta ficam de fora. Se, depois do
backfill, nao sobrar nenhuma entrada real, nao crie o arquivo e avise o usuario.

---

## PASSO 4.9 — Commit de encerramento

Os passos anteriores editaram arquivos (README, CHANGELOG, CLAUDE.md auditado) e
**nada disso foi commitado ainda**. Se a tag for criada agora, ela aponta para o
commit anterior e nao contem nenhuma dessas mudancas — o `CHANGELOG.md` diria
`[{versao}]` sem estar na versao que leva esse nome.

Verifique o que mudou:

```bash
git status
```

Se houver mudancas, commite antes da tag:

```bash
git add -A
git commit -m "prepara release {versao}"
```

Se o diretorio estiver limpo, siga direto para o PASSO 5.

---

## PASSO 5 — Criar tag de versao

### Verificar se a tag ja existe

```bash
git tag
```

Se a tag informada pelo usuario ja existir, avise e pergunte se quer usar outra versao. Nao sobrescreva tags existentes.

### Criar a tag e publicar (push somente se houver remote)

```bash
git tag {versao} -m "release {versao}"
```

A tag foi criada localmente. Verifique se ha remote antes de empurrar:

```bash
git remote
```

**Se nao houver saida (nenhum remote configurado):** pule o push da tag e avise, seguindo para o PASSO 6:
```
Tag {versao} criada localmente. Nenhum remote configurado — push da tag pulado.
Configure com `git remote add origin <url>` e rode `git push origin {versao}`.
```

**Se houver remote:**
```bash
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
Diagrama: {presente / nao se aplica / ausente por opcao}

Specs concluidas: {N}/{total}
{lista de specs pendentes se houver}

Commits:  {N}
Periodo:  {data primeiro commit} a {data de hoje} ({N} dias ativos)
```

# RESTRICOES

- Nunca criar tag se pytest falhar
- Nunca criar a tag com mudancas nao commitadas — o PASSO 4.9 vem antes do PASSO 5
  sempre; tag que nao contem o proprio CHANGELOG da versao e drift
- Nunca reescrever entradas de CHANGELOG ja registradas pelo `/spec-close` — elas
  foram escritas no momento da mudanca, que e quando valem mais
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
- [ ] O diagrama foi verificado (presente no README, ou registrado como nao
      aplicavel no CLAUDE.md, ou dispensado pelo usuario)?
- [ ] O CLAUDE.md foi auditado quanto a coerencia com o estado real (status de
      specs, checklists, comandos) antes da tag?
- [ ] O CHANGELOG foi fechado na versao (ou reconstruido por backfill, marcado como tal) antes da tag?
- [ ] O commit de encerramento foi feito antes da tag, de modo que a tag contenha o README, o CHANGELOG e o CLAUDE.md desta versao?
- [ ] Tag foi criada (e publicada, se ha remote configurado) sem sobrescrever tag existente?
- [ ] Encerramento foi registrado no CLAUDE.md com data, versao, contagem de testes, commits e periodo?
- [ ] Os tres comandos git foram executados e os valores preenchidos no bloco (commits, data do primeiro commit, dias ativos)?
