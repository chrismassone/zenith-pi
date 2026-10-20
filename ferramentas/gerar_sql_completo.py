"""Monta banco/zenith_completo.sql (criação + população + consultas) e banco/permissoes.sql.

Uso: python -m ferramentas.gerar_sql_completo
"""
import re
from collections import Counter
from datetime import datetime
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
BANCO = RAIZ / "banco" / "1_criacao.sql"
POPULACAO = RAIZ / "banco" / "2_populacao.sql"
CONSULTAS = RAIZ / "banco" / "3_consultas.sql"
COMPLETO = RAIZ / "banco" / "zenith_completo.sql"
PERMISSOES = RAIZ / "banco" / "permissoes.sql"
COMPLETO_TESTE = RAIZ / "banco" / "teste" / "zenith_completo_teste.sql"

INICIO_PERMISSOES = "-- ------------------------------------------------------------\n-- 6. PERMISSOES"
INICIO_CONFERENCIA = "-- ------------------------------------------------------------\n-- 7. CONFERENCIA RAPIDA"


def criacao_sem_permissoes():
    texto = BANCO.read_text(encoding="utf-8")
    i, j = texto.index(INICIO_PERMISSOES), texto.index(INICIO_CONFERENCIA)
    return texto[:i] + texto[j:]


def contagens():
    return Counter(re.match(r"INSERT INTO (\w+) ", l).group(1)
                   for l in POPULACAO.read_text(encoding="utf-8").splitlines()
                   if l.startswith("INSERT INTO "))


def gerar_completo():
    n = contagens()
    linhas_contagem = "\n".join(f"--   {t:26s} {n[t]:5d}" for t in sorted(n))
    cabecalho = f"""-- ============================================================
-- ZENITH - SCRIPT COMPLETO (gerado por gerar_sql_completo.py em
-- {datetime.now():%d/%m/%Y %H:%M}; nao edite a mao)
--
-- ############################################################
-- ##  AVISO: ESTE SCRIPT APAGA E RECRIA O SCHEMA `zenith`.  ##
-- ##  TODOS OS DADOS ATUAIS DE `zenith` SERAO PERDIDOS.      ##
-- ##  FACA O BACKUP ANTES (mysqldump; ver README.md).      ##
-- ############################################################
--
-- O que e: estrutura + dados ficticios + consultas do Zenith, em um
-- unico arquivo, para rodar de ponta a ponta no MySQL Workbench como root.
-- Ordem:
--   1. Criacao (1_criacao.sql sem a secao de permissoes): tabelas,
--      indices, gatilhos (com DELIMITER) e views.
--   2. Populacao (2_populacao.sql): dados 100% ficticios, numa
--      transacao (START TRANSACTION ... COMMIT).
--   3. Consultas (3_consultas.sql): 20 consultas de conferencia.
--   4. COMMIT final.
--
-- Contagens finais esperadas por tabela:
{linhas_contagem}
--   usuario                        0
--
-- Os USUARIOS DO SISTEMA NAO estao neste script. Depois de rodar, crie o
-- primeiro Gerente com:  python criar_usuario.py
-- (a senha e digitada sem aparecer e guardada so como hash bcrypt).
-- As permissoes do MySQL estao a parte, em permissoes.sql.
-- ============================================================

"""
    partes = [
        cabecalho,
        "-- ====================== 1. CRIACAO ======================\n",
        criacao_sem_permissoes(),
        "\n-- ====================== 2. POPULACAO ======================\n",
        POPULACAO.read_text(encoding="utf-8"),
        "\n-- ====================== 3. CONSULTAS ======================\n",
        CONSULTAS.read_text(encoding="utf-8"),
        "\n-- ====================== 4. FIM ======================\nCOMMIT;\n",
    ]
    COMPLETO.write_text("".join(partes), encoding="utf-8")


def gerar_permissoes():
    PERMISSOES.write_text("""-- ============================================================
-- ZENITH - PERMISSOES DO MYSQL (gerado por gerar_sql_completo.py)
-- Execute como root, DEPOIS de zenith_completo.sql.
-- Troque TROQUE_ESTA_SENHA pela senha de cada usuario. NUNCA grave senhas reais
-- neste arquivo nem no Git: a senha do zenith_app fica so no arquivo .env.
-- ============================================================

-- ----- zenith_app: usuario do aplicativo -----
-- Consulta, inclui e altera; NAO apaga cadastros e NAO altera estrutura.
-- Se o usuario ja existir, o CREATE abaixo e ignorado.
CREATE USER IF NOT EXISTS 'zenith_app'@'localhost' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
GRANT SELECT, INSERT, UPDATE ON zenith.* TO 'zenith_app'@'localhost';
-- DELETE so nas duas tabelas de DETALHE (itens do atendimento e insumos
-- padrao do procedimento), necessario para editar essas listas no app.
GRANT DELETE ON zenith.atendimento_procedimento TO 'zenith_app'@'localhost';
GRANT DELETE ON zenith.procedimento_insumo TO 'zenith_app'@'localhost';

-- ----- zenith_bi: usuario do Power BI (somente leitura) -----
CREATE USER IF NOT EXISTS 'zenith_bi'@'localhost' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
GRANT SELECT ON zenith.* TO 'zenith_bi'@'localhost';

FLUSH PRIVILEGES;

-- Conferencia:
-- SHOW GRANTS FOR 'zenith_app'@'localhost';
-- SHOW GRANTS FOR 'zenith_bi'@'localhost';
""", encoding="utf-8")


def gerar_copia_teste():
    """Mesmo script para o schema zenith_teste (troca só DROP/CREATE DATABASE e USE)."""
    saida = []
    for linha in COMPLETO.read_text(encoding="utf-8").splitlines(keepends=True):
        if re.match(r"(DROP DATABASE IF EXISTS zenith;|USE zenith;)", linha):
            linha = linha.replace("zenith;", "zenith_teste;")
        elif re.match(r"CREATE DATABASE zenith\s*$", linha):
            linha = linha.replace("zenith", "zenith_teste", 1)
        saida.append(linha)
    COMPLETO_TESTE.write_text("".join(saida), encoding="utf-8")


if __name__ == "__main__":
    gerar_completo()
    gerar_permissoes()
    gerar_copia_teste()
    print("Gerados:", COMPLETO.relative_to(RAIZ), PERMISSOES.relative_to(RAIZ),
          COMPLETO_TESTE.relative_to(RAIZ))
