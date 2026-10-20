"""Gera banco/teste/zenith_banco_teste.sql (estrutura do zenith no schema zenith_teste).

Uso: python -m ferramentas.gerar_banco_teste
"""
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
ORIGEM = RAIZ / "banco" / "1_criacao.sql"
DESTINO = RAIZ / "banco" / "teste" / "zenith_banco_teste.sql"

texto = ORIGEM.read_text(encoding="utf-8")
trocas = [
    ("DROP DATABASE IF EXISTS zenith;", "DROP DATABASE IF EXISTS zenith_teste;"),
    ("CREATE DATABASE zenith\n", "CREATE DATABASE zenith_teste\n"),
    ("USE zenith;", "USE zenith_teste;"),
    ("-- ATENCAO: este script APAGA o banco zenith e o recria vazio.",
     "-- ATENCAO: este script APAGA o banco zenith_teste e o recria vazio."),
]
for antes, depois in trocas:
    assert texto.count(antes) == 1, f"trecho não encontrado: {antes!r}"
    texto = texto.replace(antes, depois)

cabecalho = (
    "-- ============================================================\n"
    "-- GERADO por gerar_banco_teste.py a partir de 1_criacao.sql.\n"
    "-- Banco zenith_teste: SOMENTE para testes automatizados.\n"
    "-- Nao edite a mao. O banco principal (zenith) NAO e tocado.\n"
    "-- ============================================================\n\n"
)
permissoes = (
    "\n-- ------------------------------------------------------------\n"
    "-- Permissoes do banco de TESTE (com DELETE, para os testes limparem)\n"
    "-- ------------------------------------------------------------\n"
    "GRANT SELECT, INSERT, UPDATE, DELETE ON zenith_teste.* TO 'zenith_app'@'localhost';\n"
    "FLUSH PRIVILEGES;\n"
)
DESTINO.write_text(cabecalho + texto + permissoes, encoding="utf-8")
print("Gerado:", DESTINO.name)
