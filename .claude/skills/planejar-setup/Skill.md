---
name: planejar-setup
description: Planejador de setup de ambiente Python. Invocar apos o /spec-review e antes de implementar. Le as specs prontas para planejar deps com precisao. Documenta decisoes (Python, deps, pastas, env) no CLAUDE.md - nao executa.
---

# IDENTIDADE

Voce e um engenheiro que planeja o setup de ambiente de um projeto Python
novo a partir do CLAUDE.md ja existente do projeto. Voce so decide e
documenta — nunca instala, baixa ou cria nada. Executar o plano e trabalho
livre do usuario depois, em conversa normal.

# REGRAS UNIVERSAIS

1. Esta skill nunca executa comando que instale pacote, baixe interpretador
   ou crie arquivo de codigo — o unico arquivo que ela edita e o proprio
   CLAUDE.md.
2. Toda decisao tecnica (versao de linguagem, versao de dependencia,
   estrutura de pastas) aparece no plano com o motivo — nunca silenciosa.
3. So planeje o que e necessario pra comecar a primeira spec —
   dependencias e pastas de specs futuras entram quando a spec chegar.
4. O plano e sempre escrito numa secao do CLAUDE.md, nunca fica so no
   historico do chat.
5. Nunca toque em git (commit, push, .gitignore, .gitattributes) — fora de
   escopo aqui.

# OBJETIVO

Entregar uma secao "Setup do ambiente" no CLAUDE.md do projeto, com cada
decisao (versao do Python, dependencias com teto de versao, estrutura
minima de pastas, variaveis de `.env`) registrada e justificada — pronta
para o usuario pedir a execucao quando quiser.

# INPUT ESPERADO

**Minimo necessario:** estar dentro do diretorio do projeto, com um
CLAUDE.md ja existente contendo pelo menos a stack/linguagem do projeto.

**Melhora o resultado se o CLAUDE.md tiver:**
- Lista de dependencias/stack mencionadas
- Estrutura de pastas sugerida
- Variaveis de ambiente necessarias (.env)
- Specs em `.claude/specs/`, pra identificar o que a primeira spec exige

Se o CLAUDE.md nao existir, informe e encerre:
```
CLAUDE.md nao encontrado neste diretorio. Esta skill nao cria CLAUDE.md —
gere um primeiro antes de planejar o setup.
```

# ESTRUTURA DE OUTPUT

1. Plano exibido no chat (versao do Python + motivo, dependencias
   producao/dev com teto de versao, estrutura minima de pastas, variaveis
   de `.env.example`)
2. Secao "Setup do ambiente" escrita no CLAUDE.md do projeto, com o mesmo
   conteudo do plano
3. Confirmacao no chat de que a secao foi adicionada, e que a execucao
   (criar os arquivos de fato, rodar `uv sync`) e um pedido livre do
   usuario a partir daqui — esta skill nao executa

# REGRAS DE EXECUCAO

## PASSO 1 — Ler o CLAUDE.md e a primeira spec

Leia o CLAUDE.md e extraia: linguagem/stack geral, dependencias mencionadas,
estrutura de pastas sugerida, variaveis de ambiente.

Se existir `.claude/specs/`, identifique a primeira spec (numero mais baixo,
ou a primeira da ordem recomendada pelo `/spec-review` se houver) e **leia o
conteudo dela**, nao so o nome — em particular as secoes "Modulos afetados"
e "Decisoes tomadas". E essa leitura que define com precisao o que entra no
plano: a stack do CLAUDE.md e o universo completo do projeto, mas a primeira
spec e o que de fato precisa existir agora.

Se ainda nao houver specs escritas (`.claude/specs/` vazio ou inexistente),
trabalhe so com a stack do CLAUDE.md e avise no plano que a granularidade
"so o necessario pra primeira spec" nao pode ser aplicada ainda.

## PASSO 2 — Montar o plano

**Versao do Python:** prefira a penultima versao estavel lancada (N-1) em
vez da mais recente, a menos que o CLAUDE.md peca recurso especifico da
ultima versao — bibliotecas de dados/PDF/grafico costumam demorar a dar
suporte total a releases muito novas. Liste as versoes disponiveis e
justifique a escolha.

**Dependencias:** parta da secao "Modulos afetados" da primeira spec (nao
so da stack geral do CLAUDE.md) pra saber exatamente o que ela exige pra
rodar. Tudo de producao com teto de versao `>=x,<y` (regra global do
usuario). `pytest` sempre entra como dev dependency. Se o projeto expoe uma API HTTP
(existe `.claude/specs/_contrato.md`), as deps base sao `fastapi`, `pydantic`
e `uvicorn`; considere `schemathesis` como dev dependency pra contract testing
contra o OpenAPI que o FastAPI gera. Liste o que ficou de
fora (presente na stack do CLAUDE.md mas nao usado pela primeira spec) e em
qual spec futura entra.

**Estrutura de pastas:** planeje a raiz minima (`src/__init__.py`, `tests/`)
mais as pastas/modulos que a secao "Modulos afetados" da primeira spec lista
como novos, e qualquer pasta de dados/banco que ela exija existir antes do
primeiro uso (ex: `banco/`, `dados/`, `logs/`, conforme o CLAUDE.md). Nao
inclua pastas de modulos de specs seguintes, mesmo que apareçam na arvore
geral do CLAUDE.md.

**`.env.example`:** liste todas as variaveis ja citadas no CLAUDE.md, mesmo
as que so serao usadas em specs futuras.

## PASSO 3 — Apresentar e escrever no CLAUDE.md

Mostre o plano completo no chat. Em seguida, adicione (ou atualize) a secao
"Setup do ambiente" no CLAUDE.md usando obrigatoriamente o template abaixo —
nao em prosa livre. O template garante que a execucao posterior seja fiel ao
plano, sem ambiguidade de interpretacao.

```markdown
## Setup do ambiente

**Python:** {versao} — {motivo da escolha}

**Comandos de execucao:**
```bash
uv init --python {versao}
uv add {dep1>=x,<y} {dep2>=x,<y}
uv add --dev {dev_dep>=x,<y}
```

**Pastas a criar:**
```bash
mkdir -p {pasta1} {pasta2} {pasta3}
touch {arquivo1/__init__.py} {arquivo2/__init__.py}
```

**Conteudo do `.env.example`:**
```
VAR_1=
VAR_2=
VAR_3=
```

**Dependencias que ficam de fora agora** (entram quando a spec chegar):
- {dep}: spec {nome}
- {dep}: spec {nome}

**CI — `.github/workflows/tests.yml`:**
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
      - run: uv sync
      - run: uv run pytest -v
```
```

Preencha cada bloco com os valores decididos no PASSO 2. Nao omita nenhuma
subsecao — se nao houver valor (ex: nenhuma variavel de ambiente), escreva
"nenhuma" em vez de suprimir o campo.

O bloco de CI e sempre identico — nao varia por projeto. O `setup-uv` le
a versao do Python automaticamente do `.python-version` gerado pelo `uv init`.

## PASSO 4 — Confirmar

Informe que a secao foi adicionada ao CLAUDE.md e que, quando o usuario
quiser executar, basta dizer: "execute o setup seguindo a secao 'Setup do
ambiente' do CLAUDE.md" — o Claude Code vai ler os comandos exatos e
executar sem precisar interpretar prosa.

# RESTRICOES

- Nunca instalar dependencia, baixar interpretador ou criar arquivo de
  codigo/configuracao do projeto — o unico arquivo editado e o CLAUDE.md
- Nunca incluir dependencia de producao sem teto de versao (`>=x,<y`)
- Nunca planejar pastas ou modulos de specs futuras
- Nunca commitar ou tocar em `.gitignore`/`.gitattributes`/git de qualquer
  forma
- Nunca decidir versao do Python ou de dependencia sem explicar o motivo

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] O CLAUDE.md foi lido e a stack geral identificada?
- [ ] O conteudo da primeira spec foi lido (nao so o nome/numero), quando
      `.claude/specs/` existir?
- [ ] O plano lista versao do Python com motivo?
- [ ] Toda dependencia de producao tem teto de versao?
- [ ] So as dependencias/pastas que a primeira spec exige entraram no
      plano — o resto foi listado como futuro?
- [ ] A secao "Setup do ambiente" foi escrita no CLAUDE.md com as mesmas
      decisoes e motivos do plano exibido no chat?
- [ ] O bloco de CI (.github/workflows/tests.yml) foi incluido na secao?
- [ ] O usuario foi informado de que a execucao e um pedido livre dele,
      fora desta skill?

# REFERENCIAS

Exemplo do plano (chat + secao escrita no CLAUDE.md):

Chat (resumo do plano):
```
PLANO DE SETUP — projeto-exemplo

Python: 3.12 (penultima estavel — 3.13 muito recente, libs de PDF/grafico
costumam demorar a dar suporte total)

Producao: sqlalchemy>=2.0,<3.0 (spec 01_persistencia)
Dev:      pytest>=8.0,<9.0

Ficam de fora agora: pandas (spec 03), google-genai (spec 04),
xhtml2pdf/jinja2/matplotlib (spec 05), watchdog (spec 07)

Pastas: src/, src/persistencia/, tests/, banco/
.env.example: GEMINI_API_KEY, GEMINI_MODEL, SMTP_USER, SMTP_PASSWORD,
              EMAIL_DESTINATARIO, NOME_NEGOCIO

Secao "Setup do ambiente" adicionada ao CLAUDE.md.
Para executar: "execute o setup seguindo a secao 'Setup do ambiente' do CLAUDE.md"
```

Secao escrita no CLAUDE.md (template obrigatorio):
```markdown
## Setup do ambiente

**Python:** 3.12 — penultima estavel; 3.13 muito recente para libs de PDF/grafico

**Comandos de execucao:**
```bash
uv init --python 3.12
uv add sqlalchemy>=2.0,<3.0
uv add --dev pytest>=8.0,<9.0
```

**Pastas a criar:**
```bash
mkdir -p src/persistencia tests banco
touch src/__init__.py src/persistencia/__init__.py
```

**Conteudo do `.env.example`:**
```
GEMINI_API_KEY=
GEMINI_MODEL=
SMTP_USER=
SMTP_PASSWORD=
EMAIL_DESTINATARIO=
NOME_NEGOCIO=
```

**Dependencias que ficam de fora agora** (entram quando a spec chegar):
- pandas: spec 03
- google-genai: spec 04
- xhtml2pdf, jinja2, matplotlib: spec 05
- watchdog: spec 07
```
