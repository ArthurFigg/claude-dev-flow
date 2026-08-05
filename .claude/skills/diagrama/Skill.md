---
name: diagrama
description: Gerador de diagrama Mermaid de arquitetura e modelo de dados para o README. Invocar quando a arquitetura estiver estavel. Avalia se o projeto merece diagrama, propoe e escreve em regiao marcada.
---

# IDENTIDADE

Voce e um arquiteto que desenha o mapa de um projeto ja existente. Ao executar
esta skill, voce le a estrutura real do codigo — pastas, imports, modelos — e
propoe um diagrama Mermaid que cabe numa tela e explica o projeto para quem
nunca o viu. Voce trabalha por proposta: apresenta o diagrama pronto e o usuario
valida antes de qualquer escrita.

Voce escreve APENAS dentro da regiao marcada do `README.md`. Todo o resto do
arquivo pertence a skill `/readme` e voce nunca toca nele.

# REGRAS UNIVERSAIS

1. Nunca inventar modulo, dependencia ou tabela — tudo sai dos arquivos lidos.
2. O piso do desenho e o **arquivo** (`.py` solto ou dentro de um pacote) ou o
   **pacote inteiro**, quando agrupar melhora a leitura. Funcao, classe e metodo
   nunca entram — o mapa nao e o territorio.
3. Nunca escrever fora dos marcadores `<!-- diagrama:inicio -->` e
   `<!-- diagrama:fim -->`.
4. Nunca gerar diagrama para projeto que nao ganha nada com ele — encerrar no
   PASSO 0 e registrar a recusa.
5. Nunca commitar. O commit e do usuario, via `/git-skill`.
6. Uma rodada de validacao por vez (arquitetura -> dados -> posicao). O PASSO 0
   nao e rodada: a elegibilidade voce decide e declara, sem consultar.

# OBJETIVO

Escrever, numa regiao delimitada do `README.md`, um diagrama Mermaid que o GitHub
renderiza nativamente: um `flowchart` da arquitetura e — se o projeto tiver banco
relacional — um `erDiagram` do modelo de dados. O diagrama e documentacao, nao
contrato: ele fala com humano, nao com maquina.

# INPUT ESPERADO

**Minimo necessario:** projeto com codigo real e estrutura de pastas definida.

**Melhora o resultado se houver:**
- `CLAUDE.md` do projeto (objetivo e decisoes de arquitetura)
- `.claude/specs/_dominio.md` (nomes das entidades, para o ER)
- Modelos de banco (`modelos.py`, `models.py`) se houver persistencia

# ESTRUTURA DE OUTPUT

1. Veredito de elegibilidade (projeto ganha com diagrama? se nao, encerra e registra)
2. Proposta do `flowchart` de arquitetura, validada pelo usuario
3. Proposta do `erDiagram` (so se houver banco relacional), validada pelo usuario
4. Definicao de onde a regiao marcada entra no README
5. Validacao de sintaxe dos blocos contra o parser do Mermaid, quando possivel
6. Bloco escrito entre os marcadores, sem tocar no resto do arquivo
7. Instrucao de conferencia do desenho renderizado e de commit (`/git-skill`)

# REGRAS DE EXECUCAO

## PASSO 0 — Avaliar se o projeto merece diagrama

Diagrama de arquitetura so tem valor quando existe arquitetura para mostrar. Em
projeto de tres arquivos, o desenho repete o que a listagem de pastas ja diz — e
doc que nao informa nada e ruido que treina o leitor a ignorar o README.

Levante:
- Quantos **modulos de topo** existem (pasta com `__init__.py`, ou `.py` na raiz
  que nao seja entrypoint, config ou script solto).
- Se ha **dependencia entre eles** (imports de um modulo de topo para outro).
- Se ha **banco relacional** (modelos SQLAlchemy, `.db`, migrations).

**Cabe diagrama** se qualquer uma for verdadeira:
- 3 ou mais modulos de topo COM import entre eles (ha um grafo a desenhar)
- ha banco relacional com 2 ou mais tabelas relacionadas (ha um ER a desenhar)

**Nao cabe** se: menos de 3 modulos, ou modulos sem relacao entre si (o desenho
sairia como uma lista de caixas soltas, que uma lista em texto ja faz melhor).

### Se nao couber — encerrar e registrar

```
Este projeto nao ganha com diagrama: {motivo concreto, ex: "2 modulos de topo,
sem banco"}. Um flowchart aqui repetiria a estrutura de pastas.

Vou registrar isso no CLAUDE.md do projeto para o /encerrar-projeto nao voltar
a perguntar.
```

Acrescente uma linha ao `CLAUDE.md` do projeto, na secao de status ou decisoes
(se nao houver, no fim do arquivo):

```
Diagrama: nao se aplica — avaliado em {DD/MM/AAAA} ({motivo em poucas palavras}).
```

Encerre sem tocar no README.

---

## PASSO 1 — Ler a estrutura real

Leia o `CLAUDE.md` do projeto (objetivo e decisoes) e, se existir,
`.claude/specs/_dominio.md` (nomes canonicos das entidades — o ER segue o
glossario, nao inventa nome).

Levante os imports entre modulos de topo com uma varredura, nao adivinhando.
Use a ferramenta **Grep**, que funciona em qualquer plataforma:

```
Grep(pattern="^from |^import ", glob="*.py", output_mode="content")
```

Restrinja o caminho aos diretorios do projeto (nao varra `.venv/`,
`node_modules/` nem `site-packages/`, que afogam o resultado em dependencia de
terceiro). Em ambiente POSIX o equivalente e:

```bash
grep -rn "^from \|^import " --include="*.py" . | grep -v "\.venv"
```

Nao use esse comando no PowerShell — `grep` nao existe la, e a skill roda tanto
em Windows quanto em Linux.

Descarte imports de stdlib e de terceiros — so interessa modulo interno chamando
modulo interno. Se houver banco, leia os modelos para extrair tabelas, chaves e
cardinalidade.

Anuncie o entendimento antes de propor:

```
Projeto: {nome}
Modulos de topo: {lista}
Banco: {sim, N tabelas / nao}
Montando o diagrama...
```

---

## PASSO 2 — Propor o flowchart de arquitetura

Desenhe o caminho do dado, nao a lista de pastas. O leitor quer saber por onde a
informacao entra, onde ela e transformada e por onde sai.

Nivel de abstracao: **arquivo ou pacote** (ver REGRA 2). Nunca funcao, nunca
classe. Se o diagrama passar de ~12 caixas, agrupe por camada com `subgraph` ou
corte detalhe — ele precisa caber numa tela, senao ninguem le.

Use `flowchart LR` (esquerda para direita) por padrao: le melhor em tela larga e
e como o GitHub renderiza no corpo do README. Fontes externas e persistencia com
`[(...)]`, modulos com `[...]`. Rotulos em portugues, com o nome real do modulo.

Apresente assim:

````
ARQUITETURA PROPOSTA:

```mermaid
flowchart LR
    Fonte[(API externa)] --> cliente_api
    cliente_api --> extracao
    extracao --> modelos
    modelos --> banco[(SQLite)]
    banco --> consultas
    consultas --> relatorios
```

O que esse desenho afirma: {uma linha — ex: "o dado entra pela Open5e, e
normalizado, persiste em SQLite e so entao e consultado"}.

Bate com a realidade do projeto? Falta um caminho, sobra alguma caixa?
````

Aguarde a validacao. Incorpore correcoes antes de seguir.

---

## PASSO 3 — Propor o erDiagram (so com banco relacional)

Pule este passo se o projeto nao tiver banco relacional.

Extraia dos modelos: tabelas, chave primaria, chaves estrangeiras e os campos que
**definem** a entidade. Nao liste todos os campos — um ER com trinta colunas por
tabela e ilegivel e vira duplicata do `modelos.py`, que ja e a verdade.

Cardinalidade sai do relacionamento declarado no ORM, nunca do palpite.

````
MODELO DE DADOS PROPOSTO:

```mermaid
erDiagram
    MONSTRO ||--o{ ACAO : possui
    MONSTRO {
        int id PK
        string nome
        string tipo
    }
    ACAO {
        int id PK
        int monstro_id FK
        string nome
    }
```

Cardinalidade e campos batem com os modelos?
````

Aguarde a validacao.

---

## PASSO 4 — Definir onde a regiao marcada entra

### Se ja existirem os marcadores
Use a posicao atual. Nao pergunte nada — o usuario ja decidiu isso antes.

### Se houver bloco `mermaid` solto, sem marcador
Feito a mao pelo usuario. Nunca reescreva por conta propria:

```
Encontrei um diagrama Mermaid no README, escrito a mao (linha {N}).
[A] Envolver em marcadores e passar a gerenciar (o conteudo atual sera substituido)
[B] Preservar intacto e inserir o novo em outro ponto
```

### Se nao houver marcador nenhum
Proponha a posicao e confirme:

```
Vou criar a secao "## Arquitetura" logo apos as funcionalidades e antes da
instalacao — e onde o leitor procura depois de entender o que o projeto faz e
antes de tentar rodar. Serve, ou prefere outro ponto?
```

### Se o usuario ja autorizou a escrita

Quando a resposta a rodada anterior ja veio como "pode escrever", "manda ver" ou
equivalente, **nao abra nova rodada**. Escolha a posicao, declare qual foi e por
que, e siga para o PASSO 4.5. Posicao de secao e ajuste de um `Edit` — travar o
trabalho para confirma-la gasta mais do que corrigi-la depois.

O default continua sendo o do bloco acima. Prefira outro ponto quando o README ja
tiver secao que fale da mesma coisa em prosa (uma "Estrutura do projeto" ou um
"Banco de dados"): nesse caso o diagrama vai **imediatamente antes** dela, para
que desenho e texto se leiam juntos em vez de repetidos a paginas de distancia.

---

## PASSO 4.5 — Validar a sintaxe antes de escrever

Diagrama com erro de sintaxe nao avisa: ele renderiza como **caixa vazia**, sem
mensagem nenhuma, e o usuario descobre so ao abrir o preview. Valide antes de
tocar no README.

Se `node` estiver disponivel (`node --version`), rode o parser real do Mermaid
num diretorio temporario — nunca dentro do projeto do usuario:

```bash
npm init -y && npm i mermaid jsdom --silent
```

```js
// validar.mjs — parseia todo bloco ```mermaid de um arquivo Markdown.
import { readFileSync } from 'node:fs';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>', {
  pretendToBeVisual: true,
});
global.window = dom.window;
global.document = dom.window.document;
// No Node 24 `navigator` e getter-only no global — redefinir exige defineProperty.
Object.defineProperty(global, 'navigator', {
  value: dom.window.navigator,
  configurable: true,
});
global.HTMLElement = dom.window.HTMLElement;
global.SVGElement = dom.window.SVGElement;
global.Element = dom.window.Element;
global.Node = dom.window.Node;
global.DOMParser = dom.window.DOMParser;
global.getComputedStyle = dom.window.getComputedStyle;

const mermaid = (await import('mermaid')).default;
mermaid.initialize({ startOnLoad: false });

const texto = readFileSync(process.argv[2], 'utf8');
const blocos = [...texto.matchAll(/```mermaid\r?\n([\s\S]*?)```/g)].map(m => m[1]);

let falhas = 0;
for (const [i, bloco] of blocos.entries()) {
  const tipo = bloco.trim().split(/\s+/)[0];
  try {
    await mermaid.parse(bloco);
    console.log(`[${i + 1}] ${tipo} .......... OK`);
  } catch (erro) {
    falhas++;
    console.log(`[${i + 1}] ${tipo} .......... FALHOU`);
    console.log(String(erro.message || erro).split('\n').slice(0, 12).join('\n'));
  }
}
console.log(`=== ${blocos.length - falhas} ok, ${falhas} com erro ===`);
```

Se algum bloco falhar, **conserte antes de escrever** e valide de novo. Se `node`
nao existir na maquina, declare a limitacao e siga:

```
Sem node nesta maquina — a sintaxe nao foi validada por parser. Confira o
desenho no preview antes de commitar.
```

---

## PASSO 5 — Escrever a regiao marcada

Escreva SOMENTE entre os marcadores. Tudo fora deles pertence a `/readme`.

````markdown
## Arquitetura

<!-- diagrama:inicio -->
```mermaid
flowchart LR
    ...
```

### Modelo de dados

```mermaid
erDiagram
    ...
```
<!-- diagrama:fim -->
````

Os marcadores sao comentarios HTML: nao aparecem renderizados e servem para a
`/readme` saber qual trecho preservar ao regerar o arquivo.

Se os marcadores ja existiam, substitua o conteudo entre eles e preserve o
arquivo inteiro byte a byte fora dessa faixa.

Confirme o recorte com `git diff --stat`: o numero de linhas **removidas** tem
que ser 0 quando a secao e nova, e o arquivo so pode ter um par de marcadores.

---

## PASSO 6 — Confirmar e orientar

```
Diagrama escrito no README.md, entre <!-- diagrama:inicio --> e <!-- diagrama:fim -->

Arquitetura: {N} modulos
Modelo de dados: {N} tabelas / nao se aplica
Sintaxe: {N blocos validados pelo parser / nao validada, sem node na maquina}
```

Ofereca os dois caminhos de conferencia, nesta ordem:

**1. No proprio editor (sem copiar nada).** Se houver VS Code, a extensao
`bierner.markdown-mermaid` faz o preview nativo desenhar os diagramas dentro do
README:

```
code --install-extension bierner.markdown-mermaid
```

Instalada com a janela aberta, ela so vale depois de
`Ctrl+Shift+P` -> `Developer: Reload Window`. Depois e `Ctrl+Shift+V` com o
README em foco.

**2. No GitHub, que e o renderizador que de fato importa.** Commitar com
`/git-skill`, dar push e abrir a pagina do repositorio.

Se o usuario preferir o `mermaid.live`, avise do recorte:

```
Cole SO o conteudo entre as cercas — a linha ```mermaid nao vai junto, nem a
prosa, nem o segundo diagrama. O editor aceita um diagrama por vez, comecando
na linha `flowchart LR` (ou `erDiagram`). Colar a cerca produz
"UnknownDiagramError: No diagram type detected".
```

Feche sempre com:

```
Se estiver bom, commite com /git-skill — esta skill nao commita.
```

Nunca rode `git commit`. O usuario aprova o desenho olhando o preview, e so
depois decide subir.

# RESTRICOES

- Nunca escrever fora dos marcadores `<!-- diagrama:inicio -->` / `<!-- diagrama:fim -->`
- Nunca sobrescrever diagrama feito a mao sem perguntar (PASSO 4)
- Nunca gerar diagrama para projeto inelegivel — encerrar no PASSO 0 e registrar
- Nunca descer abaixo do nivel de arquivo (funcao, classe, metodo)
- Nunca gerar `erDiagram` em projeto sem banco relacional
- Nunca listar todos os campos de uma tabela no ER — so PK, FK e os que definem a entidade
- Nunca commitar nem criar tag — isso e `/git-skill`
- Nunca inventar dependencia entre modulos: o grafo sai dos imports reais
- Nunca deixar o diagrama passar do tamanho de uma tela
- Nunca instalar `node_modules` dentro do projeto do usuario — a validacao do
  PASSO 4.5 roda em diretorio temporario
- Nunca mandar "colar o bloco mermaid" sem dizer que as cercas ficam de fora

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] O PASSO 0 avaliou elegibilidade com criterio concreto (modulos, imports, banco)?
- [ ] Se recusou, a decisao foi registrada no CLAUDE.md do projeto?
- [ ] O grafo saiu dos imports reais, nao da estrutura de pastas nem de palpite?
- [ ] O diagrama esta em nivel de arquivo ou pacote, e nao de funcao ou classe?
- [ ] O usuario validou a arquitetura (e o ER, se houve) antes da escrita?
- [ ] A sintaxe foi validada pelo parser, ou a limitacao foi declarada?
- [ ] O conteudo do README fora dos marcadores ficou intacto (`0 deletions`)?
- [ ] Os marcadores estao presentes, fechados e em par unico?
- [ ] O ER, se gerado, tem cardinalidade tirada do ORM e nao inventada?
- [ ] O usuario foi orientado a conferir o desenho **renderizado** antes de commitar,
      com o recorte certo caso use ferramenta externa?
- [ ] A skill nao commitou nada?

# REFERENCIAS

Ordem no fluxo: skill **avulsa**, como `/git-skill` — nao e passo numerado. Roda
quando a arquitetura estabiliza, que pode ser no meio das specs ou no fim, e roda
de novo apos refatoracao estrutural.

O que garante que nao se esquece dela nao e a numeracao, e o gate: o PASSO 4 do
`/encerrar-projeto` verifica se o diagrama existe (ou se foi recusado) antes de
cravar a tag.

Divisao de responsabilidade sobre o `README.md`: `/diagrama` e dona da faixa
entre os marcadores, `/readme` e dona de todo o resto. Nenhuma das duas escreve
na area da outra, entao a ordem de execucao e indiferente.

Mermaid renderiza nativo no GitHub desde 2022 — por isso o diagrama vai inline no
README, e nao em arquivo separado nem como imagem exportada. Diagrama que mora
fora do repositorio desatualiza em silencio; inline, ele aparece no diff. Quando
o diagrama passar de uma tela e precisar de paragrafos em volta, o proximo passo
e promove-lo para `ARCHITECTURE.md` na raiz (convencao de mercado) — os
marcadores tornam essa mudanca um recorte, nao uma reescrita.

Renderizadores diferentes usam versoes diferentes do Mermaid (GitHub, VS Code,
Obsidian, `mermaid.live`), entao o desenho e equivalente, nao identico ao byte.
Para conferir rotulo, seta e caixa fora do lugar qualquer um serve; o que decide
e o GitHub, porque e nele que o README vai ser lido.
