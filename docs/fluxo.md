# Guia do Fluxo de Desenvolvimento com Claude Code

---

## Parte 1 — O Fluxo Completo

Este é o fluxo padrão para todo projeto Python novo. Cada etapa tem uma skill específica. Seguir a ordem evita retrabalho.

O fluxo usa dois modelos. O **Claude** conversa com você, escreve as specs e os testes e confere o resultado. O **Gemini**, chamado pelo `agy` (Antigravity CLI), escreve o código e confere as specs, na cota dele. O motivo está na seção 3.9; as pesquisas e os testes de cada peça, em [`provas.md`](provas.md). Sem o `agy`, use `variantes/so-claude/`.

---

### Etapa 0 — `/pesquisar-projeto` (opcional, só para ideia nova)

**Quando:** antes de criar o `CLAUDE.md`, quando você tem uma ideia e ainda não sabe se vale a pena nem qual o melhor jeito de fazer. Pode chamar pelo comando ou, se você disser que tem uma ideia nova, a skill pergunta se você quer rodar a etapa (você pode recusar).

**O que faz:**
- Faz até 3 perguntas, uma por vez: o problema nas suas palavras, para quem é e como você saberia que deu certo.
- Propõe um **peso** (leve, médio ou pesado) e você ajusta. Leve: "já existe algo pronto?" e decisão. Médio: soma como outros fizeram, comparação de caminhos e a peça mais arriscada. Pesado: soma provas de que o problema é real, com a régua do que conta como "passou" definida antes de pesquisar.
- Pesquisa o que pode mudar a decisão e separa fato (com fonte) de suposição. Sempre procura o que fala **contra** a ideia.
- **Para e pergunta:** seguir, pesquisar mais ou largar. Largar é um resultado válido.
- Grava um `pre-projeto.md` com a decisão, o MVP e o que fica de fora, com o motivo.

**O que não faz:** não escreve código, não cria o `CLAUDE.md` e não bloqueia nada por hook. Você pode mudar o peso, pular um passo ou largar a ideia a qualquer momento.

**Estado:** em uso e ajustada conforme os projetos; ainda não foi medida. Ao rodar o `/auditar-claude-md`, passe o caminho do `pre-projeto.md`.

---

### Etapa 1 — Criar o CLAUDE.md do projeto

**Onde:** no Claude.ai (claude.ai), antes de abrir o Claude Code.

**O que é:** um arquivo de configuração do projeto que define o que o projeto faz, como o código deve ser escrito, quais módulos existem, convenções específicas, próximos passos planejados. É o "briefing" que a IA lê antes de qualquer tarefa.

**O que colocar:**
- Nome e objetivo do projeto
- Tipo (CLI, Web API, Desktop, Script, etc.)
- Estrutura de módulos prevista
- Convenções específicas do projeto (se diferirem do padrão global)
- Lista de features planejadas

**Onde salvar:** na raiz do projeto, como `.claude/CLAUDE.md` ou `CLAUDE.md`.

Quando terminar, abra o Claude Code dentro da pasta do projeto.

---

### Etapa 2 — `/auditar-claude-md`

**Quando:** logo após abrir o projeto no Claude Code, antes de qualquer código.

**O que faz:**
- Lê o CLAUDE.md e detecta inconsistências (regras que se contradizem)
- Detecta contexto insuficiente (algo definido de forma vaga demais)
- Verifica conflitos entre o CLAUDE.md do projeto e o CLAUDE.md global
- Se specs existirem em `.claude/specs/`, verifica consistência com elas
- Faz perguntas para preencher as lacunas (uma por vez)
- Atualiza o CLAUDE.md com as decisões
- **Relê o arquivo atualizado do zero e repete a verificação inteira**, sem exigir que você rode a skill de novo manualmente. Continua perguntando e corrigindo até uma passada completa não encontrar mais nada.
- Se a mesma contradição reaparecer em qualquer passada anterior (corrigir um lado reabre o outro — mesmo que passando por outras regras no meio do caminho), para e reporta como "loop detectado" — nesse caso a decisão de qual regra prevalece é sua, não da IA.

**Por que é importante:** um CLAUDE.md com gaps faz a IA adivinhar durante a implementação. Corrigir antes é muito mais barato que corrigir depois. Sem o reloop automático, cada correção que gerasse uma inconsistência nova (ou cada erro que passasse batido na primeira leitura) exigia rodar `/auditar-claude-md` de novo manualmente.

---

### Etapa 3 — `/dominio` (uma vez por projeto)

**Quando:** logo após o `/auditar-claude-md` aprovar o CLAUDE.md, antes da primeira `/spec`.

**O que faz:**
- Lê o CLAUDE.md e deriva candidatos a entidade a partir das features e módulos descritos (não pergunta em aberto — sempre propõe primeiro)
- Propõe as entidades ("as coisas principais que o projeto cria, armazena ou manipula") para você validar
- Propõe um glossário de termos — qual nome usar sempre e qual evitar, para não haver sinônimo divergente entre specs
- Avalia se o projeto precisa de mais de um bounded context (vocabulário e regras próprias e separadas) ou se contexto único basta — a maioria dos projetos de portfólio cai em contexto único, e isso é o esperado, não uma limitação
- Gera `.claude/specs/_dominio.md`, que o `/spec` passa a ler automaticamente

**Por que é importante:** sem isso, specs geradas em conversas separadas podem nomear a mesma coisa de dois jeitos diferentes (ex: uma spec chama de "usuário", outra de "conta"). O `_dominio.md` trava o vocabulário uma vez, no início, para todas as specs seguintes.

---

### Etapa 3.5 — `/contrato` (só projeto web, uma vez)

**Quando:** logo após o `/dominio`, **se o projeto expõe uma API HTTP** (é provedor de endpoints, não um CLI nem um consumidor de API externa). Projetos que não servem API pulam esta etapa.

**O que faz:**
- Verifica que o projeto realmente expõe uma API — senão encerra, explicando a diferença entre provedor e consumidor
- Deriva os **recursos** da API das entidades do `_dominio.md`
- Propõe, para você confirmar (nunca decide sozinho): endpoints (método + caminho + schemas de request/response), formato de erro (RFC 7807), status codes, paginação, autenticação e versionamento (`/api/v1`)
- Gera e valida `openapi.yaml` (OpenAPI 3.1) na raiz do projeto — o contrato no padrão de mercado

**Por que é importante:** define a superfície da API **antes** de implementar os endpoints (contract-first). O `openapi.yaml` é o artefato de mercado: abre no Swagger UI (cole em `editor.swagger.io`), alimenta client SDKs e contract testing, e é ele mesmo a documentação da API. Cada `/spec` de endpoint depois implementa uma fatia do contrato, referenciando `operationId`/schema em vez de redefinir — o que dá ao `verificador-spec` uma fonte de verdade para pegar divergência de interface.

A implementação é **code-first com FastAPI** (idiomático em Python): os modelos Pydantic materializam os schemas do contrato e o FastAPI serve o Swagger em `/docs`. Para não haver **duas fontes de verdade** divergindo, um **teste de contrato** compara o OpenAPI que o FastAPI gera com o `openapi.yaml` commitado — se o código sair do contrato, o pytest falha (é o `schemathesis` que roda esses casos). Pact e afins só fariam sentido com times de consumidor separados, que um projeto solo não tem.

---

### Etapa 4 — `/spec` (repetir para cada feature)

**Quando:** para cada feature que você quer implementar.

**O que faz:**
- Lê o CLAUDE.md do projeto para entender a arquitetura
- Lê specs existentes em `.claude/specs/` para evitar conflitos
- Lê o `openapi.yaml` (se houver): specs de endpoint implementam fatias do contrato, referenciando operationId/schema sem redefinir
- Faz perguntas sobre o comportamento da feature (uma por vez)
- Verifica casos negativos (o que acontece com input inválido, estado errado)
- Gera o arquivo `.claude/specs/{nome_da_feature}.md`

**O que a spec contém:**
- O que a feature faz (uma frase)
- Comportamentos específicos (quando X acontece, Y deve ocorrer)
- **Regras**, uma por linha, no formato "QUANDO {situação}, o {componente} DEVE {ação}" — somadas ao comportamento, não no lugar dele
- **Interfaces públicas**: só o que outras specs vão usar desta, com a assinatura exata, escrita uma vez só aqui
- **Usa de outras specs**: só o nome e a spec de origem, nunca a assinatura repetida
- Critérios verificáveis por comando (`pytest`, `curl`, execução direta)
- Módulos afetados e o que muda em cada um
- O que NÃO mexer
- Decisões tomadas durante a conversa

**Por que interfaces escritas uma vez só:** quando a mesma assinatura aparece em duas specs, uma delas fica velha na primeira mudança. Num teste com 12 erros escondidos entre 4 specs, o formato antigo deixava passar 70%; com as três seções novas, o `/spec-review` pegou 11 de 12.

Repita esta etapa para cada feature antes de implementar qualquer uma.

---

### Etapa 5 — `/spec-review`

**Quando:** antes de implementar qualquer spec. Pode ser chamada depois de gerar todas as specs de uma vez, ou depois de cada spec individual — o comportamento se adapta aos dois usos.

**O que faz:**
- Lista as specs em `.claude/specs/` e separa em dois grupos pelo campo `**Revisão:**`: `aprovada` (já verificada numa chamada anterior, sem mudança desde então) e `pendente` (nova ou reaberta via `/reabrir-spec`)
- Se não há nenhuma spec pendente, encerra avisando — não repete verificação nem relatório de specs já aprovadas
- Manda o **Gemini** conferir **só cada spec pendente, em paralelo** — nunca as já aprovadas — com o mesmo texto do agente `verificador-spec`. Cada conferência lê a spec pendente, cruza com o CLAUDE.md e compara contra **todas** as specs aprovadas mais as pendentes que vêm depois dela na lista (assim nenhum par é verificado duas vezes). Se a chamada do Gemini falhar ou a cota acabar, aquela spec cai no subagente `verificador-spec` (Claude)
- Enquanto isso, um **script** (`conferir_specs.py`) acha por busca exata, sem IA: spec que contradiz a própria interface, uso de algo que a spec de origem não publica, assinatura repetida e nome fora do glossário. Ele também separa os pares de regras "QUANDO…, o X DEVE…" sobre o mesmo componente em specs diferentes, e o **Claude** julga cada par: existe um caso que cai nas duas regras e as ações se chocam?
- Consolida os relatórios do Gemini, do script e dos pares
- Corrige automaticamente inconsistências resolúveis (nomenclatura divergente, referências cruzadas faltando)
- Para conflitos reais que exigem decisão: reporta e pergunta
- Mapeia dependências combinando o que os subagentes detectaram agora com o campo `Depende de` já registrado nas specs aprovadas
- Propõe ordem de implementação com justificativa arquitetural

**Por que é importante:** specs geradas em chamadas separadas não se conhecem. Esta etapa garante que o conjunto é coeso antes de escrever código. Verificar em paralelo evita carregar o texto de todas as specs na conversa principal — só os relatórios resumidos voltam para quem chamou.

**Por que o Gemini confere e não o Claude:** quem escreveu as specs foi o Claude, e um modelo tende a aprovar o próprio texto. Num teste com erros escondidos, o Gemini achou 22 de 24 e o Claude 12 de 12 — mas o Claude gastava cerca de 59 mil tokens por spec. A troca aceita é cerca de 1 erro em 12 pela economia; o script e os pares julgados pelo Claude seguram parte do resto. E não reverificar specs já aprovadas importa de verdade em fluxo incremental: cada subagente paga um custo fixo de inicialização (não reaproveita cache entre chamadas), então revisar uma spec de cada vez sem essa otimização significa pagar esse custo de novo, para as mesmas specs já confirmadas, a cada nova spec criada.

**Camada de gate opcional:** se o hook `check-spec-revisao.ps1` estiver ativo no projeto (ver seção 3.8), enquanto qualquer spec estiver com `Revisão: pendente`, o Claude Code recusa tecnicamente qualquer edição de código fora de `.claude/specs/` e do CLAUDE.md — não depende mais só da IA lembrar de checar o campo por instrução.

---

### Etapa 6 — Implementar cada spec + `/spec-close`

Para cada spec, na ordem recomendada pelo spec-review:

**a)** Rode: `/implementar {nome_da_spec}`

A skill passa por atores diferentes, nesta ordem:

1. **Spec expandida.** Se a spec usa algo de outras, um script junta a spec com só as interfaces que ela usa, copiadas das specs de origem. Quem escreve teste e quem implementa recebem tudo de que precisam, sem a spec inchar.
2. **Testes primeiro.** O subagente `escritor-testes` lê só a spec e as convenções — nunca o código, que ainda não existe — e escreve os testes a partir dos "Critérios verificáveis". Para cada conta ou regra, escolhe valores em que uma leitura errada da spec daria resultado diferente do certo. Devolve o mapa de qual critério virou qual teste.
3. **Foto dos testes.** A skill guarda uma impressão digital (hash) de cada arquivo de teste.
4. **Código pelo Gemini.** O `agy` chama o Gemini com a spec, os testes (só leitura) e as regras do `GEMINI.md`. As permissões do `agy` negam escrever em `tests/`, rodar `git` e instalar dependência. Se travar, o Gemini responde `PRECISO DE AJUDA` em vez de forçar.
5. **Conferência do Claude, em 3 camadas.** O hash dos testes bate? Os testes passam rodados pelo Claude (não pelo relato do Gemini)? E a leitura do código contra a spec, procurando atalho para o teste passar, comportamento da spec que nenhum teste cobre e erro sutil de lógica.
6. **Testar os testes.** O Gemini propõe 5 erros pequenos no código; um script aplica cada um, roda os testes e desfaz. Erro que sobrevive vira aviso: os testes não protegem aquele ponto.
7. **Correção, no máximo 2 voltas.** Cada volta é uma conversa nova com o Gemini, com a lista curta do que está errado. Depois da segunda sem resolver, a skill para e chama você.
8. **Relatório "cumpre a spec?"** em `.claude/specs/_relatorios/{nome}.md`: veredito, critério → evidência, a saída real do pytest, arquivos → critério, decisões que a spec não cobria, riscos e o resultado do passo 6. É isso que você aprova.

Se a cota do Gemini acabar, a skill para e pergunta: esperar ou usar o subagente `implementador-spec` (Claude), que gasta a cota do Claude. Nunca decide sozinha.

**Por que os dois papéis são separados:** quando a mesma passada escreve o código e o teste, o teste confirma o código, não a spec. Se um critério foi entendido errado, ele é entendido errado nos dois lugares, o `pytest` fica verde e o gate do `/spec-close` não detecta nada — o teste passa a provar apenas que o código concorda consigo mesmo. Escrever o teste antes, a partir da spec, e proibir a implementação de editá-lo é o que devolve sentido ao gate.

Se um teste parecer errado durante a implementação, ele **não é consertado**: vira um bloco `TESTE EM CONFLITO` no relatório, e você decide se o errado é o teste ou a spec. Conflito assim quase sempre é ambiguidade da spec aparecendo — no lugar barato de corrigir.

**b)** Quando terminar, rode: `/spec-close {nome_da_spec}`

**O que o `/spec-close` faz:**
- Lê a spec para extrair o título
- Roda: `uv run pytest -v`
- Se testes **passam**:
  - Lê o relatório "cumpre a spec?" do `/implementar`. Se o veredito não for `CUMPRE`, ou se o total de testes de agora não bater com o do relatório, para e pergunta: você aprovou outra coisa
  - Confere se algum arquivo da lista "Não mexer" foi alterado
  - Chama o subagente `revisor-codigo` (só leitura) quando ninguém leu o código nesta sessão, para revisar o diff contra quatro critérios que o pytest não pega: correção, segurança, escopo e convenção (ex: caso de borda que a spec exige mas nenhum teste cobre, segredo escrito no código)
  - Sincroniza o CLAUDE.md do projeto quando a spec declarou impacto (seção "Impacto no CLAUDE.md"), no mesmo commit
  - Se o revisor achar algo: mostra o achado e pergunta se você quer corrigir antes ou commitar mesmo assim — a decisão final é sua, o agente nunca corrige nem decide sozinho
  - Marca a spec como concluída no arquivo (adiciona data)
  - Faz o commit com mensagem derivada do título da spec
  - Faz push para o repositório remoto
- Se testes **falham**:
  - Lista os erros claramente
  - Bloqueia o commit
  - Você corrige e roda `/spec-close` novamente

Não commite manualmente durante o ciclo de specs. O `/spec-close` é o único caminho de commit nesta fase.

**Por que o `revisor-codigo` existe:** pytest só prova que o código roda e os asserts passam — não prova que o código faz tudo que a spec pediu. É comum os testes cobrirem o caminho feliz e esquecerem um caso de borda que a spec descreveu explicitamente. O `revisor-codigo` lê o diff a frio, sem o viés de quem acabou de escrever o código, e só tem permissão de leitura (`Read`, `Grep`, `Glob`, `Bash` restrito a comandos git de leitura) — ele fisicamente não consegue editar nada, mesmo que "quisesse".

---

### Etapa 7 — `/session-start` (sessões subsequentes)

**Quando:** toda vez que abrir o Claude Code em um projeto em andamento.

**O que faz** (tudo automaticamente, sem perguntas):
- Lê o CLAUDE.md do projeto
- Separa specs concluídas das pendentes
- Roda `git log` e `git status`
- Roda: `uv run pytest --tb=no -q`
- Entrega um briefing em menos de 25 linhas com:
  - Estado dos testes (destaque se houver falhas)
  - Último commit e mudanças não commitadas
  - Specs concluídas vs pendentes
  - Próximo passo específico e acionável

**Por que é importante:** elimina os primeiros minutos de "onde eu estava?". A IA não precisa reconstruir contexto manualmente.

---

### Etapa 7.5 — `/diagrama` (quando a arquitetura estabilizar)

**Quando:** com código real no lugar e a estrutura de pastas já estável — não antes. Um diagrama de arquitetura que ainda vai mudar é retrabalho garantido.

**O que faz:**
- Lê a estrutura real do projeto (pastas, imports, modelos) e decide se o projeto ganha algo com um diagrama; se não ganhar, recusa e registra a recusa
- Propõe um `flowchart` da arquitetura e, se houver banco relacional, um `erDiagram` do modelo de dados
- Escreve **apenas** dentro dos marcadores `<!-- diagrama:inicio -->` e `<!-- diagrama:fim -->` do README

**Por que Mermaid:** o GitHub renderiza nativamente, sem ferramenta externa nem imagem para manter atualizada. É a primeira coisa que alguém vê ao abrir o repositório.

**Por que uma região marcada:** o README pertence à skill `/readme`, e o diagrama à `/diagrama`. Sem uma fronteira explícita, uma regeneração do README apagaria o trabalho da outra sem aviso. O `/readme` copia essa faixa literalmente e a reinjeta intacta; o `/diagrama` nunca escreve fora dela. Dois donos no mesmo arquivo só convivem com a fronteira declarada.

O piso do desenho é o arquivo ou o pacote — função, classe e método nunca entram. O diagrama é documentação, não contrato: ele fala com humano.

---

### Etapa 8 — `/encerrar-projeto` (quando o projeto estiver pronto)

**Quando:** quando o projeto está pronto para release — não necessariamente com todas as specs concluídas (algumas podem ter ficado fora do escopo de propósito).

**O que faz:**
- Roda `uv run pytest -v` — se algo falhar, bloqueia o encerramento
- Valida o README contra o projeto real (não só checa existência)
- Verifica se há diagrama de arquitetura, ou registro de que a ausência foi decidida
- Audita a coerência do CLAUDE.md com o estado atual do projeto
- Fecha o `CHANGELOG.md` na versão: renomeia `## [Não lançado]` para `## [{versão}] - {data}`
- Commita tudo que os passos anteriores editaram, **antes** de criar a tag
- Cria uma tag de versão anotada e faz push
- Registra no CLAUDE.md a data, versão, contagem de testes, commits e período do projeto

**Por que é importante:** formaliza o fim do projeto com um estado verificado — testes verdes, documentação coerente e um ponto de restauração marcado no histórico.

**Por que o commit vem antes da tag:** uma tag aponta para um commit. Se o README, o CHANGELOG e o CLAUDE.md forem editados e a tag for criada sem commitar, ela aponta para o commit *anterior* — e o repositório passa a ter um `CHANGELOG.md` anunciando uma versão que a própria versão não contém. É a mesma classe de erro que o teste de contrato evita na API: dois artefatos descrevendo a mesma coisa sem nada garantindo que batem.

---

### Os dois artefatos que o fluxo mantém sozinho

Não são etapas. As skills que já existem escrevem neles conforme o projeto anda — não há skill nova nem passo manual.

#### `.claude/specs/_decisoes.md` — o "porquê" do projeto

Guarda as decisões que **restringem mais de uma spec**, com contexto, alternativa descartada e custo aceito, escritas no momento em que foram tomadas.

| Skill | Papel |
|---|---|
| `/dominio` | Escreve: bounded contexts, o que deliberadamente não é entidade |
| `/contrato` | Escreve: convenções da API e escopo (ex: somente leitura) |
| `/planejar-setup` | Escreve: versão do Python, banco, estrutura de pastas |
| `/spec-close` | Promove uma "Decisão tomada" da spec, se ela restringir as próximas |
| `/session-start` | Lê: linha `DECISOES:` no briefing, só os títulos |
| `/readme` | Destila na seção "Decisões técnicas" do README |

O critério de corte é uma pergunta só: *a decisão restringe código que ainda vai ser escrito, em mais de uma spec?* Decisão de uma spec só fica na spec — o lugar dela já existe. E regra que o CLAUDE.md global já impõe (código em português, teto de versão nas deps) **não entra**: obedecer não é decidir, e registrar isso transformaria o arquivo numa cópia do CLAUDE.md global.

O critério mora em `~/.claude/templates/_decisoes.md`, arquivo único que as quatro skills consultam. Se cada uma carregasse a própria cópia da regra, a primeira edição desalinharia as outras três.

**Por que não ADR:** o formato ADR (um arquivo numerado e imutável por decisão, com `superseded`) existe por causa de **rotatividade de time** — quem decidiu saiu, e você precisa ler a decisão no contexto em que foi tomada. Em projeto solo essa força não existe: quem decidiu ainda está lá. O que existe é esquecer com o tempo e precisar que outra pessoa **encontre** o raciocínio — e isso pede um arquivo só, legível, destilado no README, não uma pasta `docs/adr/`.

#### `CHANGELOG.md` — o que mudou, para quem usa

Formato [Keep a Changelog](https://keepachangelog.com/) + [SemVer](https://semver.org/). O `/spec-close` escreve uma linha em `## [Não lançado]` a cada spec fechada; o `/encerrar-projeto` renomeia a seção para a versão da tag.

A linha sai do **"O que faz" da spec**, não da mensagem de commit:

```
❌ Implementa o núcleo de consulta em consultas.py (Spec 7a)
✅ Filtro por tipo, desafio e ambiente agora funciona igual no terminal e no site
```

Mudança que quem usa não percebe — refatoração, ajuste de teste, reorganização de pasta — **não gera linha**. Ruído no CHANGELOG custa mais que a ausência de uma entrada; o `git log` continua guardando tudo.

**Por que não gerar do `git log`:** a geração automática (`semantic-release`, `release-please`) depende de conventional commits (`feat:`, `fix:`), e este fluxo usa mensagem livre em português, sem prefixo. Além disso os commits aqui são um por spec — um CHANGELOG derivado deles seria a lista de specs com outro nome. O que o `git log` não sabe e a spec sabe é o nível de usuário.

Para projeto que já andou antes disso existir, o `/encerrar-projeto` faz o **backfill** uma vez: reconstrói as entradas percorrendo os commits, mas lendo o "O que faz" de cada spec correspondente, e marca a seção como reconstruída.

---

### Referência rápida: quando usar o `/reabrir-spec`

`/reabrir-spec {nome}` é o caminho oficial para alterar uma spec **já concluída**. Ele adiciona uma seção de "Revisão" com o que muda e por quê, e troca o status para "em revisão" — o próximo `/spec-close` gera um commit `revisa {título}` em vez de `implementa {título}`. Nunca edite uma spec fechada na mão: reabra primeiro, para o histórico registrar a mudança.

---

### Referência rápida: quando usar o `/git-skill`

`/git-skill` é reservado para commits **fora** do ciclo de specs:
- Hotfix (correção urgente que não veio de uma spec)
- Ajuste de configuração (`.gitignore`, `pyproject.toml`, `.env.example`)
- Criação de tag de release (`v1.0.0`, `v1.1.0`)
- Commit inicial do projeto (antes de qualquer spec)

Durante a implementação de specs, use sempre `/spec-close`.

---

## Parte 2 — Referência Rápida das Skills

| Skill | Quando usar |
|---|---|
| `/auditar-claude-md` | Valida o CLAUDE.md antes de codar |
| `/dominio` | Propõe entidades, glossário e contextos (uma vez por projeto) |
| `/contrato` | (Projeto web) Define recursos, endpoints e convenções da API; gera `openapi.yaml` (OpenAPI 3.1) |
| `/spec` | Cria a spec de uma feature |
| `/spec-review` | Gemini confere cada spec pendente em paralelo, script acha conflitos, Claude julga pares de regras; define ordem |
| `/planejar-setup` | Decide versão do Python, deps e estrutura de pastas; documenta no CLAUDE.md |
| `/implementar [nome]` | Testes primeiro (subagente `escritor-testes`), Gemini escreve o código, Claude confere, testa os testes, grava o relatório |
| `/spec-close [nome]` | Fecha uma spec: pytest + relatório + "Não mexer" + revisão do diff + commit |
| `/reabrir-spec [nome]` | Reabre uma spec concluída para nova revisão |
| `/encerrar-projeto` | Encerramento formal: pytest + README + CHANGELOG + commit + tag |
| `/session-start` | Briefing de retomada de sessão |
| `/git-skill` | Commit fora do ciclo de specs |
| `/readme` | Gera o README.md quando o projeto estiver pronto |
| `/diagrama` | Desenha arquitetura e modelo de dados em Mermaid, numa região marcada do README |

O subagente `revisor-codigo` e o hook de gate (`check-spec-revisao.ps1`) são opcionais — ver seção "Como usar" no README — e reforçam etapas que as skills já cobrem por instrução. O `verificador-spec` e o `implementador-spec` são a reserva do Gemini: sem eles, quando a cota do `agy` acaba, a etapa para. O `escritor-testes` é diferente: sem ele o `/implementar` não tem testes prontos para a implementação fazer passar, e a separação entre quem escreve o teste e quem escreve o código deixa de existir.

---

## Parte 3 — O que Aprender para Entender Tudo

Esta parte explica os conceitos por trás de cada etapa do fluxo, com os termos exatos para pesquisar e aprender mais.

---

### 3.1 — O que é uma "spec" e por que ela existe

A spec (especificação de feature) é um documento que define **O QUE** implementar antes de escrever qualquer código. Ela separa a fase de decisão da fase de execução.

O conceito original vem de engenharia de software tradicional: equipes grandes escrevem especificações antes de codar para alinhar todo mundo. No fluxo com IA, a spec serve para que o Claude Code implemente exatamente o que você decidiu, sem adivinhar.

**Termos para pesquisar:**
- "Software Design Document SDD"
- "Feature Specification template"
- "Acceptance Criteria how to write"
- "BDD Behavior Driven Development" (especialmente o formato Given/When/Then)
- "Spec-driven development"
- "Requirements Engineering software"

**O que entender:** a diferença entre critérios verificáveis (`pytest` passa) e critérios vagos ("código limpo"). Specs só têm valor se os critérios puderem ser checados por um comando.

---

### 3.2 — Por que testes são o gate para commitar

O `/spec-close` só commita se os testes passam. Isso é uma prática chamada "green before commit" — você nunca commita código com testes quebrados.

A lógica: se testes passam, você tem evidência de que o código funciona como especificado. Se falham, você tem um bug documentado que precisa ser resolvido antes de avançar.

**Termos para pesquisar:**
- "Test Driven Development TDD Python"
- "pytest tutorial"
- "pytest fixtures" (como reutilizar setup entre testes)
- "pytest parametrize" (como testar múltiplos casos com um teste só)
- "what makes a good unit test"
- "test isolation Python"
- "mocking vs integration tests"

**O que entender:** a diferença entre testes unitários (testam uma função isolada), testes de integração (testam módulos juntos) e testes e2e (testam o sistema completo). O fluxo usa principalmente unitários + integração.

---

### 3.3 — Por que um commit por spec (não por sessão)

O fluxo commita uma vez por spec implementada, não uma vez por sessão de trabalho. Isso é chamado de "atomic commits" — cada commit representa uma mudança lógica completa e independente.

**Benefícios práticos:**
- `git log` conta a história do projeto (cada spec = um capítulo)
- Se uma spec introduziu um bug, dá para reverter só ela (`git revert`)
- Code review fica possível (revisar uma spec por vez)

**Termos para pesquisar:**
- "Atomic commits git"
- "Git commit best practices"
- "git log oneline graph"
- "git bisect" (como encontrar qual commit introduziu um bug)
- "git revert vs git reset"

**O que entender:** a diferença entre `git commit` (salva localmente) e `git push` (envia para o servidor remoto). E a diferença entre `git reset` (desfaz commits) e `git revert` (cria um commit que desfaz outro).

---

### 3.4 — Por que o código é organizado por domínio e não por tipo

O CLAUDE.md global define que o código deve ser organizado por feature/domínio (`usuarios/`, `produtos/`) e não por tipo de arquivo (`models/`, `views/`, `utils/`).

**A razão:** quando você precisa mexer em "usuários", tudo que precisa está em um lugar só. Na organização por tipo, você precisa abrir `models/`, `views/` e `services/` ao mesmo tempo — o código relacionado fica espalhado.

**Termos para pesquisar:**
- "Domain Driven Design DDD Python"
- "Feature-based project structure Python"
- "Separation of concerns software"
- "Cohesion coupling software design"
- "Clean Architecture Python"

**O que entender:** "coesão" (código relacionado junto) e "acoplamento" (módulos dependendo uns dos outros). Alta coesão e baixo acoplamento é o objetivo.

---

### 3.5 — Como o CLAUDE.md e as skills funcionam tecnicamente

O Claude Code lê arquivos específicos antes de cada conversa:
- **CLAUDE.md global:** em `~/.claude/CLAUDE.md` (Windows: `C:\Users\<usuario>\.claude\CLAUDE.md`)
- **CLAUDE.md do projeto:** em `.claude/CLAUDE.md` ou `CLAUDE.md` na raiz
- **Skills:** uma pasta por skill em `~/.claude/skills/{nome}/SKILL.md` (Windows: `C:\Users\<usuario>\.claude\skills\`)

Quando você digita `/spec`, o Claude Code lê o arquivo `~/.claude/skills/spec/SKILL.md` e usa o conteúdo como instrução. É essencialmente um "prompt" (instrução para a IA) salvo em arquivo.

**Termos para pesquisar:**
- "Claude Code CLAUDE.md documentation"
- "Claude Code custom slash commands"
- "Claude Code system prompt"
- "Prompt engineering guide"
- "System prompt vs user prompt"
- "Claude Code hooks" (automações que rodam em eventos, ex: antes de commitar)

**O que entender:** skills são prompts salvos em arquivo. Quando você melhora uma skill (editando diretamente o arquivo `.md`), você está refinando a instrução que a IA recebe. Quanto mais precisa a instrução, mais previsível o resultado.

---

### 3.6 — O que é "uv" e por que ele é usado no lugar de pip

`uv` é um gerenciador de pacotes Python moderno, muito mais rápido que pip. O fluxo usa `uv run pytest` em vez de `python -m pytest` ou `pytest` diretamente porque o `uv` garante que o comando roda no ambiente virtual correto do projeto.

**Termos para pesquisar:**
- "uv Python package manager"
- "uv vs pip vs pipenv vs poetry"
- "Python virtual environment" (o que é e por que existe)
- "pyproject.toml Python" (o arquivo de configuração moderno do Python)
- "Python dependency management"

**O que entender:** cada projeto Python tem suas próprias dependências. O ambiente virtual (venv) isola essas dependências para que projetos diferentes não interfiram entre si. O `uv` gerencia isso automaticamente.

---

### 3.7 — O que a IA faz quando implementa uma spec

Quando você roda `/implementar busca_monstro`, o Gemini (quem escreve o código):
1. Lê a spec completa e os testes que o `escritor-testes` já escreveu
2. Lê o CLAUDE.md do projeto para entender a arquitetura
3. Lê o `GEMINI.md` global para as convenções de código e o que é proibido
4. Cria ou modifica os arquivos listados em "Módulos afetados"
5. Roda os testes até passarem, sem poder alterá-los
6. Não toca no que está em "Não mexer"

Depois, o Claude confere tudo isso sem confiar no relato do Gemini: roda os testes ele mesmo e lê o código contra a spec.

A IA não "entende" o código como um humano — ela prediz o próximo token (pedaço de texto) com base no contexto. Quanto mais contexto preciso (CLAUDE.md, spec), menos ela precisa adivinhar e mais o resultado se parece com o que você quer.

**Termos para pesquisar:**
- "Large Language Models how they work"
- "AI code generation how it works"
- "Context window LLM" (o limite de texto que a IA processa de uma vez)
- "Prompt engineering for code generation"
- "AI pair programming workflow"

**O que entender:** a IA não "sabe" o que é certo — ela produz o que é estatisticamente provável dado o contexto. Por isso specs precisas e CLAUDE.md detalhado produzem resultados mais consistentes do que pedidos vagos.

---

### 3.8 — Hooks e subagentes: a camada automática opcional

Até certo ponto, este fluxo dependia só de instrução em texto (a IA lê a regra na skill e segue). Os arquivos em `.claude/agents/` e `.claude/hooks/` adicionam dois mecanismos mais fortes, ambos opcionais:

**Hook:** um script que o Claude Code executa automaticamente antes (ou depois) de uma ferramenta ser usada — por exemplo, antes de qualquer edição de arquivo. O hook deste fluxo (`check-spec-revisao.ps1`) roda antes de toda edição e verifica se existe alguma spec com `Revisão: pendente` no projeto atual. Se existir, a edição é recusada — não é um lembrete de texto que a IA pode ignorar por engano, é uma barreira técnica.

**Subagente:** uma instância separada do Claude Code, com seu próprio contexto e próprio conjunto de ferramentas, chamada de dentro de uma skill para fazer uma tarefa específica e devolver só o resultado — sem que o trabalho intermediário dela (arquivos lidos, comparações feitas) entre na conversa principal. Este fluxo usa quatro: `revisor-codigo` (dentro do `/spec-close`, só leitura, sem permissão de editar nada), `escritor-testes` (dentro do `/implementar`, escreve os testes da spec antes de existir código) e dois de reserva para quando a cota do Gemini acaba: `verificador-spec` (confere specs no `/spec-review`, só leitura) e `implementador-spec` (escreve o código no `/implementar`). Os de leitura só reportam e nunca decidem sozinhos; os que escrevem devolvem o controle para o `/spec-close` fazer o gate de testes e commit.

O par `escritor-testes` + quem implementa (o Gemini, ou o `implementador-spec` na reserva) mostra um segundo uso do isolamento: não é só economia de contexto, é **separação de papéis**. O escritor não vê o código porque ele ainda não existe; quem implementa não pode editar `tests/`. Nenhum dos dois consegue fechar o ciclo sozinho, e é justamente por isso que o `pytest` verde no fim significa alguma coisa. Um único agente fazendo os dois trabalhos produziria o mesmo resultado aparente — testes verdes — sem a mesma garantia.

**Por que isso importa mais do que parece:** escopo restrito de ferramentas é uma garantia técnica, não uma promessa de comportamento. Um subagente sem acesso a `Edit` ou `Write` fisicamente não consegue alterar código, mesmo que "quisesse" — diferente de só instruir "não edite nada" num prompt, que depende da IA seguir a instrução.

**Termos para pesquisar:**
- "Claude Code hooks PreToolUse PostToolUse"
- "Claude Code subagents / Task tool"
- "principle of least privilege" (por que restringir ferramentas importa)
- "AI agent orchestration"
- "multi-agent systems software"

**O que entender:** a diferença entre "pedir para a IA não fazer algo" (instrução, pode falhar) e "impedir tecnicamente que a IA faça algo" (permissão restrita, não falha). Hooks e escopo de ferramentas de subagente são a segunda categoria.

---

### 3.9 — Harness engineering: dois modelos, cada um no seu papel

**Harness** é tudo o que fica em volta do modelo para ele entregar o que foi pedido: as regras (CLAUDE.md, GEMINI.md), as skills, os testes, as travas (hooks, permissões, hash dos testes) e as conferências. A ideia costuma ser resumida como "agente = modelo + harness". Este fluxo inteiro é um harness.

O harness daqui usa dois modelos por dois motivos:

**Economia.** Escrever código é a parte que mais gasta token. O Gemini escreve na cota dele; o Claude só lê e confere. O mesmo vale para conferir as specs: cerca de 59 mil tokens por spec que deixam de sair da cota do Claude.

**Quem escreve não confere.** Um modelo tende a dar nota maior ao próprio texto e aos da mesma família. Por isso cada papel fica com um ator diferente: o Claude escreve a spec e os testes, o Gemini escreve o código, e o Claude confere um código que não foi ele quem escreveu. As permissões e o hash garantem que o Gemini não consiga mexer nos testes para fazê-los passar.

Não há medição de que o Gemini programa melhor que o Claude. O ganho vem da separação. Os números de cada peça estão em [`provas.md`](provas.md).

**Termos para pesquisar:**
- "harness engineering AI agents"
- "LLM-as-a-judge self-preference bias"
- "reward hacking code generation" (quando o modelo engana o teste em vez de resolver)
- "mutation testing" (testar os testes)

**O que entender:** o modelo é uma peça. A confiabilidade vem do que está em volta: quem faz o quê, o que cada um pode tocar e quem confere quem.
