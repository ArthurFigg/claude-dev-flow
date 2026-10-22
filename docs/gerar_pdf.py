"""Gera docs/provas.pdf a partir de docs/provas.md (Markdown -> HTML -> PDF pelo Chrome).

uso: uv run --no-project --with markdown python docs/gerar_pdf.py [caminho do chrome]
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import markdown

AQUI = Path(__file__).parent
CHROME_PADRAO = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

ESTILO = """
body { font-family: "Segoe UI", Arial, sans-serif; font-size: 11pt; line-height: 1.5;
       color: #1d2420; max-width: 760px; margin: 0 auto; }
h1 { font-size: 22pt; margin-bottom: 4px; }
h2 { font-size: 14pt; color: #2f6b4f; border-top: 1px solid #d9dfdb; padding-top: 14px;
     margin-top: 22px; break-after: avoid; }
table { border-collapse: collapse; width: 100%; font-size: 9.5pt; margin: 8px 0;
        break-inside: avoid; }
th, td { border: 1px solid #d9dfdb; padding: 5px 7px; text-align: left; vertical-align: top; }
th { background: #eef1ee; }
code { font-family: Consolas, monospace; font-size: 9.5pt; background: #eef1ee;
       padding: 0 3px; border-radius: 3px; }
a { color: #2f6b4f; }
hr { display: none; }
@page { size: A4; margin: 18mm 16mm; }
"""


def montar_html(texto_md: str) -> str:
    # O link para o proprio PDF nao faz sentido dentro do PDF.
    texto_md = "\n".join(
        linha for linha in texto_md.splitlines() if "provas.pdf" not in linha
    )
    corpo = markdown.markdown(texto_md, extensions=["tables"])
    return f'<!doctype html><meta charset="utf-8"><style>{ESTILO}</style>{corpo}'


def main() -> None:
    chrome = sys.argv[1] if len(sys.argv) > 1 else CHROME_PADRAO
    html = montar_html((AQUI / "provas.md").read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as pasta:
        arquivo_html = Path(pasta) / "provas.html"
        arquivo_html.write_text(html, encoding="utf-8")
        subprocess.run(
            [
                chrome,
                "--headless",
                "--disable-gpu",
                "--no-pdf-header-footer",
                f"--print-to-pdf={AQUI / 'provas.pdf'}",
                arquivo_html.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
    print(f"gerado: {AQUI / 'provas.pdf'}")


if __name__ == "__main__":
    main()
