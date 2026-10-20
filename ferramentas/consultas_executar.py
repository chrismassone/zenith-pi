"""Roda as consultas de banco/3_consultas.sql e mostra quantas linhas cada uma devolve.

Uso: python -m ferramentas.consultas_executar [--mostrar] [--teste] [--markdown]
"""
import re
import sys
from datetime import datetime
from pathlib import Path

if "--teste" in sys.argv:
    from ferramentas import banco_teste
    banco_teste.usar()

from database.conexao import conectar

ARQUIVO = Path(__file__).resolve().parents[1] / "banco" / "3_consultas.sql"


def blocos():
    texto = ARQUIVO.read_text(encoding="utf-8")
    partes = re.split(r"^-- \[(\d+)\] (.*)$", texto, flags=re.M)
    for i in range(1, len(partes), 3):
        corpo = "\n".join(l for l in partes[i + 2].splitlines()
                          if not l.strip().startswith("--"))
        comandos = [c.strip() for c in corpo.split(";") if c.strip()]
        yield partes[i], partes[i + 1].strip(), comandos


def _celula(valor):
    if valor is None:
        return "NULL"
    return str(valor).replace("|", "\\|")


def markdown(resultados, banco):
    saida = ["# Resultados de 3_consultas.sql\n",
             f"Banco: `{banco}`. Executado em {datetime.now():%d/%m/%Y %H:%M} como zenith_app.",
             "Valores exatamente como o MySQL devolveu (até 10 linhas por consulta).\n"]
    for numero, titulo, colunas, linhas in resultados:
        saida.append(f"## [{numero}] {titulo}\n")
        saida.append(f"Total de linhas: **{len(linhas)}**\n")
        if not linhas:
            saida.append("(nenhuma linha)\n")
            continue
        saida.append("| " + " | ".join(colunas) + " |")
        saida.append("|" + "---|" * len(colunas))
        for l in linhas[:10]:
            saida.append("| " + " | ".join(_celula(v) for v in l) + " |")
        saida.append("")
    destino = Path(__file__).resolve().parents[1] / "docs" / "resultados_consultas.md"
    destino.write_text("\n".join(saida), encoding="utf-8")
    print("Gravado:", destino)


def main():
    mostrar = "--mostrar" in sys.argv
    conn = conectar()
    cur = conn.cursor()
    cur.execute("SELECT DATABASE()")
    banco = cur.fetchone()[0]
    falhas = 0
    resultados = []
    for numero, titulo, comandos in blocos():
        try:
            for cmd in comandos[:-1]:
                cur.execute(cmd)            # SET @parametro
            cur.execute(comandos[-1])
            linhas = cur.fetchall()
            resultados.append((numero, titulo, [d[0] for d in cur.description], linhas))
            print(f"[{numero}] {len(linhas):4d} linha(s)  {titulo}")
            if mostrar:
                for linha in linhas[:3]:
                    print("        ", linha)
        except Exception as e:  # noqa: BLE001
            falhas += 1
            print(f"[{numero}] ERRO  {titulo}: {e}")
    conn.close()
    if "--markdown" in sys.argv:
        markdown(resultados, banco)
    return falhas


if __name__ == "__main__":
    raise SystemExit(main())
