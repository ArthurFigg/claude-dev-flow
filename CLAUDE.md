# CLAUDE.md — Exemplo de Configuração Global

> **ADAPTE ANTES DE USAR**
> Este arquivo é o CLAUDE.md global do autor, construído e refinado ao longo de 5 projetos Python reais.
> Ele é intencionalmente opinionado — reflete escolhas específicas de stack, idioma e estilo.
> Leia cada seção, entenda o motivo, e ajuste ao seu contexto antes de usar.
>
> Decisões que você provavelmente vai querer mudar:
> - **Idioma do código**: aqui está configurado para português. Se você trabalha em inglês, ajuste a seção "Idioma".
> - **Gerenciador de pacotes**: usa `uv`. Se você usa `pip`, `poetry` ou outro, ajuste a seção "Dependências e Ambiente".
> - **Linter/Formatter**: usa `ruff`. Substituível por `black` + `flake8` se preferir.
> - **Stack**: as regras assumem Python. Para outros idiomas, remova ou substitua as seções específicas de Python.

---

# CLAUDE.md — Preferências Globais de Desenvolvimento Python

> Válido globalmente em todos os projetos Python.
> Um `CLAUDE.md` local por projeto pode sobrescrever regras específicas.

---

## Perfil e Tom

* Nível: **avançado**. Sem explicações básicas. Respostas diretas e técnicas.
* Stack: varia por projeto — adapte ao contexto sem assumir framework fixo.
* Quando houver mais de uma solução razoável, apresente as opções com trade-offs em vez de escolher silenciosamente.
* Seja direto: "isso tem o problema X" em vez de "talvez você queira considerar".

---

## Ambiguidade e Contexto

* Pedido claro: implemente sem perguntar. Não peça confirmação desnecessária.
* Pedido vago (onde o código fica, qual a intenção, qual o escopo): **pergunte, não adivinhe**. Uma pergunta por vez, da mais crítica para a menos. Nunca entregue algo genérico simulando entendimento.
* O que costuma faltar: mecanismo ("função de autenticação" → JWT, sessão, OAuth?), objetivo ("refatora isso" → performance ou legibilidade?), critério ("adiciona validação" → de quê, e falha onde?).
* Depois das respostas, confirme o entendimento em uma linha antes de implementar.
* Se o pedido vai causar problema (acoplamento, inconsistência com o projeto), sinalize antes de implementar.

---

## Quando eu abrir um projeto existente

"Analise este projeto" = ler estrutura e arquivos principais, identificar os padrões já usados, e gerar um `.claude/CLAUDE.md` específico dele — perguntando antes de salvar.

---

## Abordagem por Etapas

* Em projetos novos ou tarefas grandes, **sempre proponha as etapas antes de implementar** — liste o que será feito em cada uma, com escopo claro.
* Aguarde aprovação do usuário antes de iniciar cada etapa.
* Ordem das etapas deve seguir dependência arquitetural: camada de dados → lógica de negócio → UI → integração.
* Cada etapa deve ser **autocontida e testável** — ao final de cada etapa, rodar `pytest -v` explicitamente e reportar o resultado antes de propor a próxima. Isso vale mesmo quando nenhum teste novo foi adicionado, para confirmar que a suite existente não quebrou.
* Quando o projeto usar specs em `.claude/specs/`, cada spec é uma etapa — `pytest -v` deve passar antes de avançar para a spec seguinte, independentemente de o usuário pedir.
* Não acumule etapas nem pule à frente sem sinal do usuário.
* Quando o usuário disser "vamos pausar", "para por aqui" ou similar, propor atualizar o CLAUDE.md do projeto com o status atual: o que foi concluído e o que falta — antes de encerrar a sessão.

---

## Fluxo de Desenvolvimento

Projeto novo, nesta ordem:

```
CLAUDE.md → /auditar-claude-md → /dominio → [/contrato, só API HTTP] →
/spec (×N) → /spec-review → /planejar-setup → executar setup →
por spec: /implementar → /spec-close →
/readme → /diagrama → /encerrar-projeto
```

`/session-start` abre qualquer sessão de projeto em andamento.

**O detalhe de cada etapa está em `docs/fluxo.md`** — quando roda, o que gera, o que pula, e os dois artefatos que as skills mantêm sozinhas (`_decisoes.md` e `CHANGELOG.md`). Leia esse arquivo ao começar projeto novo ou ao escolher a próxima etapa; não precisa dele para escrever código.

Três regras do fluxo valem sempre e por isso ficam aqui:

* **Spec com `**Revisão:** pendente` não é implementada.** Rodar `/spec-review` antes.
* **`/implementar` é o único caminho para implementar uma spec** — ele escreve os testes antes do código, por outro ator (ver seção Testes).
* **`/spec-close` é o único caminho para commitar durante a implementação.** `/git-skill` só para commit fora do ciclo de specs.

---

## Desenvolvimento de Interface (Desktop)

* Quando componentes de UI estiverem prontos mas a janela principal ainda não existir, **ofereça criar um script descartável de visualização** (`preview.py`) para o usuário ver o progresso antes do app estar completo.
* O script deve ser simples, na raiz do projeto, e explicitamente descartável — deixar claro que não faz parte do projeto final.
* **Regra de packing do tkinter** — em um mesmo frame, widgets com `side="right"` devem ser empacotados *antes* de qualquer widget com `fill="x", expand=True`. Violação torna os widgets right-aligned invisíveis (o widget expansível consome todo o espaço primeiro).
* **Thread safety com Tkinter** — callbacks vindos de threads externas (daemon, hotkey global, tray) nunca chamam widgets diretamente. Usar sempre `widget.after(0, callback)` para serializar a execução na thread principal do Tkinter; caso contrário o app pode travar ou corromper o estado da UI silenciosamente.

---

## Idioma

* **Todo o código em português**: variáveis, funções, classes, métodos, exceções, mensagens de erro, logs.
* Exceções: nomes técnicos consagrados em inglês que não têm tradução natural (`id`, `status`, `token`, `payload`, `slug`, `cache`) podem ser mantidos.
* Comentários no código: português.
* Commits: português, descritivo e livre — sem convenção de prefixos.

---

## Comunicação

* Explique o **porquê** das decisões, não o que o código faz.
* Ao explicar uma decisão, nomear o **princípio geral** por trás dela e citar **um** outro contexto onde o mesmo princípio se aplica. O objetivo é conhecimento transferível, não explicação mais longa — uma frase a mais, não um parágrafo.
* Avise riscos proativamente (performance, segurança, acoplamento) antes de implementar.
* Sem comentários óbvios no código. Comente apenas lógica genuinamente não-óbvia, trade-offs ou limitações conhecidas.
* Quando perceber algo que pode ser melhorado no código mostrado, **sugira a refatoração mesmo sem ser pedido** — estrutura, naming, performance, acoplamento desnecessário.

---

## Código Legado

* Ao receber código que quebra as convenções deste arquivo, **pergunte antes de tocar**: preservar o estilo existente ou refatorar para o padrão?
* Nunca refatorar silenciosamente código legado — a decisão é do usuário.

---

## Estrutura de Projeto

Organização por **domínio/feature**, nunca por tipo de arquivo.

Uma pasta por domínio (`usuarios/`, `produtos/`), não `models/` + `views/` + `utils/`.

Dentro de cada domínio:

```
usuarios/
    __init__.py         # só re-exportações da API pública do módulo
    modelos.py          # entidades e schemas (Pydantic, dataclasses, SQLAlchemy)
    servicos.py         # lógica de negócio pura, sem dependência de framework
    rotas.py            # handlers HTTP — só orquestração, sem lógica
    repositorio.py      # acesso a dados e queries
    excecoes.py         # erros específicos do domínio
```

* Se o nome do arquivo precisar de "e" para fazer sentido, está fazendo coisas demais.
* `utils.py` genérico é code smell. Nomeie pelo que faz: `formatadores.py`, `validadores.py`.
* `config.py` na raiz para settings globais (Pydantic `BaseSettings`).
* `__init__.py` sem lógica — só re-exportações explícitas.

---

## Testes

* **pytest** sempre. Criar `tests/` espelhando a estrutura do projeto.
* Gerar os testes sem precisar pedir — nunca entregar código sem eles.
* **No ciclo de specs, o teste vem antes e é de outro ator.** O `/implementar` chama o agente `escritor-testes`, que escreve os testes a partir dos "Critérios verificáveis" sem ver código. Depois a implementação faz passar e **não edita `tests/`**. Motivo: teste escrito pela mesma passada que escreveu o código confirma o código, não a spec. Fora do ciclo (script solto, hotfix), teste junto com o código.
* Nomenclatura: `test_{módulo}.py`, funções `test_{cenário}_{resultado_esperado}()`.
* Nível: pytest simples + fixtures quando houver setup repetido + mocks na fronteira (I/O, HTTP, banco).
* Cada teste com **um assert lógico**. Múltiplos asserts → separar em testes distintos.
* Testes independentes entre si — ordem de execução não pode importar.
* Mockar apenas fronteiras externas, nunca lógica de negócio.

---

## Type Hints

* Abordagem **minimalista**: usar onde agrega valor real na leitura e na IDE.
* Obrigatório em funções públicas com lógica não-trivial.
* Dispensável em funções curtas e óbvias, mesmo que públicas.
* Evitar `Any` — se usado, comentar o motivo.
* Rodar checador de tipo (`pyright`, dependência de dev) — sem ele, a anotação não pega bug.
* `TypeVar`, `Protocol`, `Generic` apenas quando genuinamente necessário.

---

## Docstrings

* Apenas em **funções públicas com lógica complexa** — não por padrão em tudo.
* Formato livre e objetivo: uma linha descrevendo o que faz, mais contexto só se necessário.
* Sem repetir o que o type hint já diz. Sem docstrings cerimoniosas (`Args:`, `Returns:`) em funções simples.

---

## Estilo e Qualidade

* Formatador: `ruff format`. Linter: `ruff check`. Linha máxima: **88 chars**.
* Sem `import *`. Imports explícitos, agrupados: stdlib → third-party → local.
* Early return para reduzir nesting.
* Preferir composição a herança. Herança só com relação "é um" real.
* Funções acima de 20 linhas são candidatas a refatoração — sinalizar antes de escrever.
* Evitar flags booleanas como parâmetro (`processar(dados, True)`) — usar enum ou funções separadas.
* Exceções específicas do domínio em `excecoes.py`.
* Async: **somente se explicitamente pedido**. Não sugerir nem usar async por padrão.

---

## Exibição de Código

* Ao modificar código existente: **sempre mostrar o arquivo completo**.
* Ao criar código novo: mostrar todos os arquivos (implementação + testes).
* Nunca usar `# ... resto do código`, `# unchanged` ou omitir trechos — causa erro.

---

## Dependências e Ambiente

* Gerenciador: **`uv`**. Usar `uv add`, `uv run`, `uv sync`.
* Configuração em `pyproject.toml`. Sem `requirements.txt` avulso.
* Variáveis de ambiente via `.env` + `pydantic-settings` ou `python-dotenv`.
* `.env.example` obrigatório com todas as variáveis necessárias (sem valores reais).
* Nunca hardcodar secrets, URLs de produção ou configurações de ambiente.
* **Versões de dependências:** commitar o `uv.lock` — é ele que trava as versões do app. Versão menor também quebra, então teto (`<x`) só com motivo concreto (quebra conhecida), anotado ao lado. Atualizar com `uv lock --upgrade` e rodar o pytest.
* **Seed de demonstração:** em projetos com dashboard ou UI de análise, criar `seed.py` junto com a spec de UI — não depois. Dados reais revelam problemas visuais que testes unitários não detectam.
* **Banco de dados: o mesmo no desenvolvimento e na produção.** SQLite só se a produção também for SQLite (app local, desktop, protótipo). Produção em PostgreSQL → PostgreSQL também no dev (ex.: container). Diferença entre bancos faz código que passou nos testes quebrar em produção.

---

## Proibições Absolutas

* Nunca `eval()` ou `exec()` sem discussão explícita de segurança.
* Nunca misturar lógica de negócio com acesso a dados.
* Nunca retornar `None` implicitamente de funções que deveriam retornar dados — tipar como `Optional[T]`.
* Nunca `print()` em código não-script — usar `logging`.
* Nunca refatorar código legado sem perguntar primeiro.
