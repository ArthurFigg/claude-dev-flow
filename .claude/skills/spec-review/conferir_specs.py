"""Conferidor de specs no formato novo (Interfaces públicas / Usa de outras specs / Regras).

Uso:
  uv run --no-project python conferir_specs.py <pasta_das_specs>

Em codigo (busca exata, sem IA):
  C0 a spec contradiz a propria interface publica
  C1 "Usa de outras specs" cita algo que a spec de origem nao publica
  C2 uma spec repete a assinatura de algo que outra spec publica
  C3 nome fora do glossario (_dominio.md) e fora das interfaces publicas
Pares para o Claude julgar:
  C4 regras "QUANDO ..., o <componente> DEVE ..." sobre o mesmo componente, em specs
     diferentes -- listadas lado a lado para o Claude conferir se se contradizem

Specs sem as secoes do formato novo sao ignoradas (o verificador-spec cuida delas).
Saida: JSON com os achados. Codigo de saida 0 sempre que conseguiu rodar.
C0-C3 validados em 06/10. O julgamento dos pares e do Claude (PASSO 2 do /spec-review).
"""

import json
import keyword
import re
import sys
from pathlib import Path

NOME_CHAMADA = re.compile(r"`(?:[\w.]+\.)?(\w+)\(([^`]*?)\)(?:\s*->[^`]*)?`")
REGRA = re.compile(r"(?m)^- QUANDO (.+?), (?:o|a) (\w+) DEVE (.+)$")
PERMITIDOS = {
    "None", "True", "False", "null", "str", "list", "dict", "bool", "int", "float",
    "pytest", "uv", "JOIN", "UNIQUE", "WARNING", "ERROR", "INFO", "PK", "FK", "README",
    "CLAUDE", "env", "example", "sessao", "commit", "flush", "begin",
}


def ler(caminho: Path) -> str:
    return caminho.read_text(encoding="utf-8").replace("\r\n", "\n")


def secao(texto: str, titulo: str) -> str:
    achado = re.search(rf"(?ms)^## {titulo}\s*$(.*?)(?=^## |\Z)", texto)
    return achado.group(1) if achado else ""


def formato_novo(texto: str) -> bool:
    return bool(secao(texto, "Interfaces públicas") or secao(texto, "Regras"))


def parametros(bruto: str) -> tuple:
    bruto = re.sub(r"\([^()]*\)", "", bruto)
    return tuple(p.split(":")[0].split("=")[0].strip() for p in bruto.split(",") if p.strip())


def interfaces(texto: str) -> dict[str, tuple | None]:
    saida: dict[str, tuple | None] = {}
    for linha in secao(texto, "Interfaces públicas").splitlines():
        chamada = NOME_CHAMADA.search(linha)
        if chamada:
            saida[chamada.group(1)] = parametros(chamada.group(2))
            continue
        nome = re.search(r"`(\w+)`", linha)
        if nome:
            saida[nome.group(1)] = None
    return saida


def usa(texto: str) -> list[tuple[str, str]]:
    return re.findall(r"`(\w+)` \((\w+)\)", secao(texto, "Usa de outras specs"))


def chamadas_no_corpo(texto: str) -> list[tuple[str, tuple]]:
    sem_interfaces = texto.replace(secao(texto, "Interfaces públicas"), "")
    achados = [(n, parametros(p)) for n, p in NOME_CHAMADA.findall(sem_interfaces)]
    return [(n, p) for n, p in achados if p not in ((), ("...",))]


def identificadores(texto: str) -> set[str]:
    achados = set()
    for bruto in re.findall(r"`([^`]+)`", texto):
        if "/" in bruto or '"' in bruto or re.search(r"\.\w+\.\w+|:\d", bruto):
            continue
        nome = re.split(r"[\s(.:\[=]", bruto.strip())[0]
        if nome.startswith("_") or keyword.iskeyword(nome) or not re.fullmatch(r"[A-Za-z_]\w*", nome):
            continue
        achados.add(nome)
    return achados


def glossario(texto: str) -> set[str]:
    sem_titulo = "\n".join(l for l in texto.splitlines() if not l.startswith("#"))
    return set(re.findall(r"[A-Za-z_]\w*", sem_titulo))


def regras(texto: str) -> list[tuple[str, str]]:
    return [(s, f"QUANDO {q}, o {s} DEVE {a}") for q, s, a in REGRA.findall(texto)]


def conferir_codigo(specs: dict[str, str], gloss: set[str] | None) -> list[str]:
    achados = []
    publicas = {nome: interfaces(t) for nome, t in specs.items()}
    dono = {n: spec for spec, ifs in publicas.items() for n in ifs}
    for nome, texto in specs.items():
        proprias = publicas[nome]
        for chamada, params in chamadas_no_corpo(texto):
            if chamada in proprias and proprias[chamada] is not None and params != proprias[chamada]:
                achados.append(f"C0 {nome}: `{chamada}{params}` difere da propria interface {proprias[chamada]}")
            elif chamada in dono and dono[chamada] != nome:
                achados.append(f"C2 {nome}: repete a assinatura de `{chamada}`, publicada em {dono[chamada]}")
        for citado, origem in usa(texto):
            alvo = next((s for s in specs if s.startswith(origem)), None)
            if alvo and citado not in publicas[alvo]:
                achados.append(f"C1 {nome}: usa `{citado}` de {origem}, que nao publica esse nome")
        if gloss is not None:
            for ident in sorted(identificadores(texto) - gloss - set(dono) - PERMITIDOS):
                achados.append(f"C3 {nome}: `{ident}` fora do glossario")
    return achados


def pares_de_regras(specs: dict[str, str]) -> list[tuple[str, str, str, str]]:
    por_spec = {nome: regras(t) for nome, t in specs.items()}
    nomes = sorted(specs)
    return [
        (a, ra, b, rb)
        for i, a in enumerate(nomes)
        for b in nomes[i + 1:]
        for sa, ra in por_spec[a]
        for sb, rb in por_spec[b]
        if sa == sb
    ]


def main() -> int:
    pasta = Path(sys.argv[1] if len(sys.argv) > 1 else ".claude/specs")
    todas = {p.name: ler(p) for p in sorted(pasta.glob("*.md")) if not p.name.startswith("_")}
    specs = {n: t for n, t in todas.items() if formato_novo(t)}
    caminho_gloss = pasta / "_dominio.md"
    gloss = glossario(ler(caminho_gloss)) if caminho_gloss.exists() else None
    resultado = {
        "specs_conferidas": sorted(specs),
        "specs_formato_antigo": sorted(set(todas) - set(specs)),
        "glossario": caminho_gloss.exists(),
        "codigo": conferir_codigo(specs, gloss),
        "pares_de_regras": [
            {"specs": [a, b], "regra_a": ra, "regra_b": rb}
            for a, ra, b, rb in pares_de_regras(specs)
        ],
    }
    print(json.dumps(resultado, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
