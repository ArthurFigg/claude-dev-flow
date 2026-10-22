# Variante só-Claude

Use esta pasta se você não tem o `agy` (Gemini) instalado. Copie os arquivos por cima
dos de `.claude/`:

```
variantes/so-claude/skills/implementar/  ->  ~/.claude/skills/implementar/
variantes/so-claude/skills/spec-review/  ->  ~/.claude/skills/spec-review/
variantes/so-claude/agents/implementador-spec.md  ->  ~/.claude/agents/
```

O que muda em relação à versão principal:

| Etapa | Versão principal (agy) | Esta variante |
|---|---|---|
| Escrever o código da spec | Gemini, conferido pelo Claude | Claude (inline ou agente `implementador-spec`) |
| Conferir as specs no `/spec-review` | Gemini, Claude de reserva | Agente `verificador-spec` |
| Testar os testes (mutantes) | Gemini propõe os erros | Não tem |
| Relatório "cumpre a spec?" | Tem | Não tem (o `/spec-close` avisa e segue) |

**Atenção:** esta variante é a versão de 27/09/2026. Ela não recebeu as melhorias de
outubro do `/implementar` e do `/spec-review` que não dependem do Gemini (spec expandida,
trava dos testes por hash, relatório, script `conferir_specs.py`).
