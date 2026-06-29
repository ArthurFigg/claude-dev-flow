---
name: Fechador de Spec
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
2. Spec marcada como concluida no arquivo
3. Commit criado e push executado
4. Confirmacao com hash do commit

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
- **Tem UI**: verifique se a secao "Modulos afetados" menciona arquivos `.html`, `.js` ou `.css` — registre internamente como `tem_ui = true/false`
- **Criterios visuais**: se `tem_ui = true`, extraia da secao "Criterios verificaveis" os itens que nao podem ser verificados por `pytest` (ex: "pagina renderiza X", "campo Y aparece", "botao Z funciona") — esses precisam de teste manual no browser

Se o arquivo nao existir, informe o usuario e encerre:
```
Spec nao encontrada: .claude/specs/{nome}.md
Verifique o nome e tente novamente.
```

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

Passe para o PASSO 4.

---

## PASSO 3C — Aviso de browser testing (apenas se `tem_ui = true`)

Se `tem_ui = false`: pule este passo.

Se `tem_ui = true`: exiba o aviso abaixo **antes** de marcar a spec como concluida. Nao bloqueie o commit — o aviso e informativo, nao um gate.

```
⚠️  Esta spec tem componentes de UI que nao podem ser verificados por pytest.
    Teste manualmente no browser antes de considerar concluido:

    [ ] {criterio visual 1 extraido da spec}
    [ ] {criterio visual 2 extraido da spec}
    ...

    Como testar: suba o servidor com `uv run uvicorn main:app --reload`
    e acesse as rotas relevantes.
```

Se o ambiente nao tiver banco de dados provisionado (sem `DATABASE_URL` valido), adicione:
```
    ⚠️  Ambiente sem banco — configure DATABASE_URL no .env antes de testar.
```

---

## PASSO 4 — Marcar spec como concluida

Adicione ao final do arquivo `.claude/specs/{nome}.md`:

```markdown

---
**Status:** concluida em YYYY-MM-DD
```

Use a data atual no formato `YYYY-MM-DD`.

---

## PASSO 5 — Commitar via git-skill

Derive a mensagem de commit do titulo extraido no PASSO 1:

- Spec: `# Busca de Monstro por Nome` → `implementa busca de monstro por nome`
- Spec: `# Tratamento de Erros HTTP` → `implementa tratamento de erros HTTP`

Regras da mensagem:
- Comeca com "implementa "
- Sem prefixos de tipo (`feat:`, `fix:`, etc.)
- Maximo 72 caracteres
- Em portugues

Invoque a git-skill passando a mensagem ja pronta — ela opera em modo automatico (sem pedir confirmacao):

```
/git-skill mensagem: "implementa {titulo da spec}"
```

A git-skill cuida de: verificar arquivos sensiveis, checar .gitignore, fazer `git add -A`, commitar e dar push.

---

## PASSO 6 — Confirmar

```
✅ Spec concluida e commitada.

Spec:   .claude/specs/{nome}.md
Commit: implementa {titulo}
Hash:   {hash curto}
```

Se `tem_ui = true`, repita o aviso de browser testing de forma compacta:
```
⚠️  UI nao testada no browser — veja checklist acima (PASSO 3C).
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
- Nunca usar mensagem generica como "atualiza codigo" ou "correcoes"

# CRITERIO DE QUALIDADE

Antes de encerrar, verifique:

- [ ] O arquivo da spec foi encontrado e o titulo extraido corretamente?
- [ ] `uv run pytest -v` foi executado com output completo capturado?
- [ ] O commit foi bloqueado se houve qualquer falha ou erro nos testes?
- [ ] A spec foi marcada como concluida no arquivo?
- [ ] A mensagem de commit e derivada do titulo da spec, em portugues, sem prefixo de tipo?
- [ ] O push foi executado com sucesso?
- [ ] Specs pendentes foram listadas na confirmacao final?
- [ ] Se a spec tem UI (html/js/css nos modulos afetados), o aviso de browser testing foi exibido com criterios especificos?
