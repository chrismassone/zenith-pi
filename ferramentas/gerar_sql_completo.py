"""Monta banco/zenith_completo.sql (criação + população + consultas) e banco/permissoes.sql,
e as versões para o TiDB Cloud em banco/tidb/.

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
TIDB = RAIZ / "banco" / "tidb"

INICIO_PERMISSOES = "-- ------------------------------------------------------------\n-- 6. PERMISSOES"
INICIO_CONFERENCIA = "-- ------------------------------------------------------------\n-- 7. CONFERENCIA RAPIDA"
INICIO_GATILHOS = "-- ------------------------------------------------------------\n-- 4. REGRA DE ESTOQUE"
INICIO_VIEWS = "-- ------------------------------------------------------------\n-- 5. VIEWS"
# data de hoje em Brasília, qualquer que seja o fuso da conexão (o TiDB Cloud roda em UTC)
HOJE_BRASILIA = "DATE(CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '-03:00'))"


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


def para_tidb(texto):
    """Adapta o SQL do MySQL ao TiDB: data de Brasília e ids sequenciais."""
    texto = texto.replace("CURDATE()", HOJE_BRASILIA)
    return texto.replace(") ENGINE=InnoDB;", ") ENGINE=InnoDB AUTO_ID_CACHE=1;")


def criacao_tidb():
    texto = criacao_sem_permissoes()
    # o TiDB não tem gatilhos; a regra do saldo fica nos serviços do aplicativo
    i, j = texto.index(INICIO_GATILHOS), texto.index(INICIO_VIEWS)
    texto = texto[:i] + texto[j:]
    texto = texto.replace("-- SGBD: MySQL 8.0.16+ (necessario para o CHECK ser aplicado)",
                          "-- SGBD: TiDB Cloud 8.5 (versao adaptada de banco/1_criacao.sql)")
    texto = texto.replace("USE zenith;\n", """USE zenith;

-- Sem esta variavel o TiDB aceita os CHECKs mas nao os aplica. Ela precisa
-- estar ligada ANTES do CREATE TABLE (conferencia no fim do script completo).
SET GLOBAL tidb_enable_check_constraint = ON;
-- Horario de Brasilia para DEFAULT CURRENT_TIMESTAMP nesta sessao.
SET time_zone = '-03:00';
""", 1)
    return para_tidb(texto)


CONFERENCIA_TIDB = """
-- ====================== 5. CONFERENCIA TIDB ======================
-- Esperado: check_ligado = 1, 14 BASE TABLE, 12 VIEW e checks diferente de zero.
SELECT @@GLOBAL.tidb_enable_check_constraint AS check_ligado;
SELECT TABLE_TYPE, COUNT(*) AS total FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'zenith' GROUP BY TABLE_TYPE;
SELECT COUNT(*) AS checks FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'zenith';
"""

PERMISSOES_TIDB = """-- ============================================================
-- ZENITH - PERMISSOES NO TIDB CLOUD (gerado por gerar_sql_completo.py)
-- Execute com o usuario administrador, DEPOIS de zenith_completo_tidb.sql.
-- No TiDB Cloud Starter todo usuario leva o prefixo do cluster, mostrado em
-- Connect no console (ex.: 3xYz.root). Troque PREFIXO por ele e
-- TROQUE_ESTA_SENHA pela senha de cada usuario. NUNCA grave senhas reais
-- neste arquivo nem no Git: a senha do zenith_app fica so no arquivo .env.
-- ============================================================

-- ----- zenith_app: usuario do aplicativo -----
-- Consulta, inclui e altera; NAO apaga cadastros e NAO altera estrutura.
CREATE USER IF NOT EXISTS 'PREFIXO.zenith_app'@'%' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
GRANT SELECT, INSERT, UPDATE ON zenith.* TO 'PREFIXO.zenith_app'@'%';
-- DELETE so nas duas tabelas de DETALHE (itens do atendimento e insumos
-- padrao do procedimento), necessario para editar essas listas no app.
GRANT DELETE ON zenith.atendimento_procedimento TO 'PREFIXO.zenith_app'@'%';
GRANT DELETE ON zenith.procedimento_insumo TO 'PREFIXO.zenith_app'@'%';

-- ----- zenith_bi: usuario do Power BI (somente leitura) -----
CREATE USER IF NOT EXISTS 'PREFIXO.zenith_bi'@'%' IDENTIFIED BY 'TROQUE_ESTA_SENHA';
GRANT SELECT ON zenith.* TO 'PREFIXO.zenith_bi'@'%';

-- ----- banco de testes (so se zenith_teste_tidb.sql foi executado) -----
-- Os testes automaticos gravam e apagam o que criam, por isso o DELETE.
GRANT SELECT, INSERT, UPDATE, DELETE ON zenith_teste.* TO 'PREFIXO.zenith_app'@'%';

FLUSH PRIVILEGES;

-- Conferencia:
-- SHOW GRANTS FOR 'PREFIXO.zenith_app'@'%';
-- SHOW GRANTS FOR 'PREFIXO.zenith_bi'@'%';
"""


def gerar_tidb():
    TIDB.mkdir(exist_ok=True)
    criacao = criacao_tidb()
    (TIDB / "1_criacao_tidb.sql").write_text(criacao, encoding="utf-8")
    n = contagens()
    linhas_contagem = "\n".join(f"--   {t:26s} {n[t]:5d}" for t in sorted(n))
    cabecalho = f"""-- ============================================================
-- ZENITH - SCRIPT COMPLETO PARA O TIDB CLOUD (gerado por
-- gerar_sql_completo.py em {datetime.now():%d/%m/%Y %H:%M}; nao edite a mao)
--
-- ############################################################
-- ##  AVISO: ESTE SCRIPT APAGA E RECRIA O SCHEMA `zenith`.  ##
-- ##  TODOS OS DADOS ATUAIS DE `zenith` SERAO PERDIDOS.      ##
-- ############################################################
--
-- Rodar com o usuario administrador do cluster (SQL Editor do TiDB Cloud
-- ou MySQL Workbench com SSL, porta 4000).
-- Diferencas para banco/zenith_completo.sql (MySQL):
--   - sem os 3 gatilhos de saldo (o TiDB nao tem gatilhos; a regra fica
--     nos servicos do aplicativo);
--   - CURDATE() trocado por
--     {HOJE_BRASILIA},
--     para a data ser a de Brasilia em qualquer conexao (app e Power BI);
--   - AUTO_ID_CACHE=1 para os ids novos seguirem a sequencia;
--   - SET GLOBAL tidb_enable_check_constraint = ON para os CHECKs valerem.
-- Os dados sao exatamente os de 2_populacao.sql.
--
-- Contagens finais esperadas por tabela:
{linhas_contagem}
--   usuario                        0
-- As permissoes ficam a parte, em permissoes_tidb.sql.
-- ============================================================

"""
    partes = [
        cabecalho,
        "-- ====================== 1. CRIACAO ======================\n",
        criacao,
        "\n-- ====================== 2. POPULACAO ======================\n",
        POPULACAO.read_text(encoding="utf-8"),
        "\n-- ====================== 3. CONSULTAS ======================\n",
        para_tidb(CONSULTAS.read_text(encoding="utf-8")),
        "\n-- ====================== 4. FIM ======================\nCOMMIT;\n",
        CONFERENCIA_TIDB,
    ]
    (TIDB / "zenith_completo_tidb.sql").write_text("".join(partes), encoding="utf-8")
    (TIDB / "permissoes_tidb.sql").write_text(PERMISSOES_TIDB, encoding="utf-8")
    # banco de testes no mesmo cluster (os testes que gravam usam zenith_teste)
    teste = "".join(partes)
    for a, b in (("DROP DATABASE IF EXISTS zenith;", "DROP DATABASE IF EXISTS zenith_teste;"),
                 ("CREATE DATABASE zenith\n", "CREATE DATABASE zenith_teste\n"),
                 ("USE zenith;", "USE zenith_teste;"),
                 ("SCHEMA = 'zenith'", "SCHEMA = 'zenith_teste'"),
                 ("schema `zenith`", "schema `zenith_teste`"),
                 ("de `zenith` SERAO", "de `zenith_teste` SERAO")):
        teste = teste.replace(a, b)
    (TIDB / "zenith_teste_tidb.sql").write_text(teste, encoding="utf-8")


if __name__ == "__main__":
    gerar_completo()
    gerar_permissoes()
    gerar_copia_teste()
    gerar_tidb()
    print("Gerados:", COMPLETO.relative_to(RAIZ), PERMISSOES.relative_to(RAIZ),
          COMPLETO_TESTE.relative_to(RAIZ), TIDB.relative_to(RAIZ))
