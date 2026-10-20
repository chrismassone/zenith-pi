"""Roda os blocos de banco/consultas_figuras.sql (só leitura).

Uso: python -m ferramentas.prints_executar [schema] [blocos...]
"""
import re
import sys
from pathlib import Path

from database.conexao import conectar

ARQUIVO = Path(__file__).resolve().parents[1] / "banco" / "consultas_figuras.sql"


def blocos():
    texto = ARQUIVO.read_text(encoding="utf-8")
    partes = re.split(r"^-- ===== (\d+)\. (.*?) =====\s*$", texto, flags=re.M)
    resultado = []
    for i in range(1, len(partes), 3):
        corpo = "\n".join(l for l in partes[i + 2].splitlines() if not l.strip().startswith("--"))
        comandos = [c.strip() for c in corpo.split(";") if c.strip()]
        resultado.append((int(partes[i]), partes[i + 1].strip(), comandos))
    return resultado


def executar(schema, numeros=None):
    """{número: (título, colunas, linhas)}"""
    if not re.fullmatch(r"zenith(_teste)?", schema):
        raise ValueError("schema permitido: zenith ou zenith_teste")
    conn = conectar()
    try:
        cur = conn.cursor()
        cur.execute(f"USE {schema}")
        saida = {}
        for numero, titulo, comandos in blocos():
            if numeros and numero not in numeros:
                continue
            for cmd in comandos[:-1]:
                cur.execute(cmd)                # SET @parametro
            cur.execute(comandos[-1])
            colunas = [d[0] for d in cur.description]
            saida[numero] = (titulo, colunas, cur.fetchall())
        return saida
    finally:
        conn.close()


def como_texto(saida):
    linhas = []
    for numero, (titulo, colunas, dados) in saida.items():
        linhas.append(f"===== {numero}. {titulo} =====")
        linhas.append(" | ".join(colunas))
        for d in dados:
            linhas.append(" | ".join("NULL" if v is None else str(v) for v in d))
        if not dados:
            linhas.append("(nenhuma linha)")
        linhas.append("")
    return "\n".join(linhas)


if __name__ == "__main__":
    schema = sys.argv[1] if len(sys.argv) > 1 else "zenith_teste"
    nums = [int(n) for n in sys.argv[2:]] or None
    print(como_texto(executar(schema, nums)))
