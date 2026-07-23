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

* Se o contexto for ambíguo (onde o código fica, qual é a intenção, qual o escopo), **pergunte antes de assumir**. Uma pergunta direta é melhor que uma implementação errada.
* Quando o pedido for claro, implemente sem perguntar — não peça confirmação desnecessária.
* Se perceber que o pedido vai causar problema (acoplamento, inconsistência com o projeto), sinalize antes de implementar.

## Prompts Mal Formulados

* Se o pedido for vago, incompleto ou ambíguo demais para gerar algo útil, **não tente adivinhar — faça perguntas**.
* Identifique exatamente o que está faltando e pergunte de forma direta e objetiva: uma pergunta por vez, começando pela mais crítica.
* Exemplos de situações que exigem clarificação:

  * "cria uma função de autenticação" → qual mecanismo? JWT, sessão, OAuth? onde fica no projeto?
  * "refatora isso" → qual é o objetivo da refatoração? performance, legibilidade, desacoplamento?
  * "adiciona validação" → validação de quê, com qual critério, onde deve falhar?
* Não simule entendimento e entregue algo genérico. Prefira pausar e alinhar.
* Após as respostas, confirme o entendimento em uma linha antes de implementar.

---

## Quando eu abrir um projeto existente

Se eu disser "analise este projeto", você deve:

1. Ler a estrutura de pastas e arquivos principais
2. Identificar padrões já usados no código
3. Gerar um .claude/CLAUDE.md específico para esse projeto
4. Me perguntar antes de salvar se está correto

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

Ordem obrigatória para projetos novos:

```
1. Criar CLAUDE.md do projeto  (Claude.ai — só para projetos novos)
2. /auditar-claude-md          — detecta gaps e inconsistências antes de qualquer código
3. /dominio                    — propõe entidades, glossário e contextos; gera _dominio.md (uma vez por projeto)
   /contrato                   — (só projeto web) define a superfície da API (recursos, endpoints, RFC 7807, versão); gera _contrato.md; roda após /dominio, antes das specs de endpoint
4. /spec                       — repetir para cada feature planejada
5. /spec-review                — revisa o conjunto de specs, resolve conflitos, define ordem
6. /planejar-setup             — com todas as specs prontas, decide versão Python, deps e estrutura de pastas; documenta no CLAUDE.md, não executa
7. executar setup              — "execute o setup seguindo a seção 'Setup do ambiente' do CLAUDE.md"
8. Para cada spec (na ordem recomendada pelo spec-review):
   → implementar
   → /spec-close               — roda pytest, marca concluída, commita
9. /session-start              — usar no início de qualquer sessão subsequente
10. /encerrar-projeto          — quando o projeto estiver pronto para release
```

Regras do fluxo:
* `/contrato` roda **só em projeto que expõe uma API HTTP** (provedor de endpoints), após o `/dominio` e antes das specs de endpoint. Gera `_contrato.md` (documento-decisão em markdown: recursos, endpoints, schemas, erro RFC 7807, versionamento); o OpenAPI real sai do FastAPI na implementação. Projeto CLI/desktop/script ou que só consome API externa pula esta etapa.
* `/spec-review` é obrigatório após gerar todas as specs — nunca implementar sem revisar o conjunto. Antes de implementar qualquer spec, verifique se o campo `**Revisão:**` no arquivo está como `aprovada`. Se estiver `pendente`, avise o usuário e peça para rodar `/spec-review` primeiro.
* `/planejar-setup` roda depois do `/spec-review` e antes de implementar — com todas as specs prontas, o planejamento de deps fica preciso (sabe exatamente o que a primeira spec exige).
* executar setup (conversa livre) é o passo entre `/planejar-setup` e a primeira implementação.
* `/spec-close` é o único caminho para commitar durante a implementação — nunca commitar manualmente no meio de specs.
* `/session-start` substitui a reconstrução manual de contexto ao retomar um projeto.
* `/git-skill` é reservado para commits fora do ciclo de specs (hotfix, ajuste de config).
* `/encerrar-projeto` é o encerramento formal — pytest final, README, tag de versão e registro no CLAUDE.md. Disparar quando o projeto estiver pronto, não necessariamente quando todas as specs estiverem concluídas.

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

❌ Não:

```
models/
views/
utils/
helpers/
```

✅ Sim:

```
usuarios/
    __init__.py         # só re-exportações da API pública do módulo
    modelos.py          # entidades e schemas (Pydantic, dataclasses, SQLAlchemy)
    servicos.py         # lógica de negócio pura, sem dependência de framework
    rotas.py            # handlers HTTP — só orquestração, sem lógica
    repositorio.py      # acesso a dados e queries
    excecoes.py         # erros específicos do domínio

produtos/
    __init__.py
    modelos.py
    servicos.py
    rotas.py
    repositorio.py

tests/
    usuarios/
        test_servicos.py
        test_repositorio.py
    produtos/
        test_servicos.py
```

* Se o nome do arquivo precisar de "e" para fazer sentido, está fazendo coisas demais.
* `utils.py` genérico é code smell. Nomeie pelo que faz: `formatadores.py`, `validadores.py`.
* `config.py` na raiz para settings globais (Pydantic `BaseSettings`).
* `__init__.py` sem lógica — só re-exportações explícitas.

---

## Testes

* **pytest** sempre. Criar `tests/` espelhando a estrutura do projeto.
* Gerar os testes **junto com o código**, sem precisar pedir.
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
* Early return para reduzir nesting. Sem `else` após `return`/`raise`.
* Preferir composição a herança. Herança só com relação "é um" real.
* Funções acima de 20 linhas são candidatas a refatoração — sinalizar antes de escrever.
* Evitar flags booleanas como parâmetro (`processar(dados, True)`) — usar enum ou funções separadas.
* Exceções específicas do domínio em `excecoes.py`. Nunca `except Exception: pass`.
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
* **Versioning de dependências:** sempre definir teto de versão (`>=x,<y`) em dependências de produção — nunca só limite inferior. Minor/patch não costumam quebrar; major quase sempre quebra. Teto padrão: `<(major+1).0.0`. Exceção: dependências internas do próprio projeto.
* **Seed de demonstração:** em projetos com dashboard ou UI de análise, criar `seed.py` junto com a spec de UI — não depois. Dados reais revelam problemas visuais que testes unitários não detectam.
* **Banco de dados em desenvolvimento: SQLite por padrão**, a menos que o projeto exija recurso exclusivo do PostgreSQL (ex: `LISTEN/NOTIFY`, extensões como `pgvector`, Full Text Search nativo). Quando usar SQLite: tipos genéricos do SQLAlchemy (`Uuid`, `JSON`) em vez de `postgresql.UUID`/`postgresql.JSONB`; `create_all` no startup para dev; Alembic só para produção com PostgreSQL.

---

## Proibições Absolutas

* Nunca `eval()` ou `exec()` sem discussão explícita de segurança.
* Nunca `except Exception: pass` — silenciar erros é pior que deixar quebrar.
* Nunca misturar lógica de negócio com acesso a dados.
* Nunca retornar `None` implicitamente de funções que deveriam retornar dados — tipar como `Optional[T]`.
* Nunca `print()` em código não-script — usar `logging`.
* Nunca refatorar código legado sem perguntar primeiro.
