"""Execução de SQL parametrizado e tradução dos erros do MySQL."""
from contextlib import contextmanager

from mysql.connector import Error

from database.conexao import conectar

ERRO_DUPLICADO = 1062
ERRO_FK = 1452
ERRO_CHECK = 3819
SINAL_GATILHO = "45000"  # SIGNAL dos gatilhos de saldo


class RegistroDuplicado(Exception):
    def __init__(self, chave):
        self.chave = chave
        super().__init__(chave)


class RegraDoBanco(Exception):
    """Recusa por gatilho, CHECK ou FK."""


def _traduzir(erro):
    if erro.errno == ERRO_DUPLICADO:
        # mensagem do MySQL: "Duplicate entry 'x' for key 'tabela.uq_nome'"
        chave = erro.msg.rsplit("'", 2)[-2].split(".")[-1] if "'" in erro.msg else ""
        return RegistroDuplicado(chave)
    if erro.sqlstate == SINAL_GATILHO:
        return RegraDoBanco(erro.msg)
    if erro.errno in (ERRO_FK, ERRO_CHECK):
        return RegraDoBanco(erro.msg)
    return RuntimeError("Não foi possível concluir a operação no banco de dados.")


def consultar(sql, parametros=(), um=False):
    conn = conectar()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(sql, parametros)
        return cursor.fetchone() if um else cursor.fetchall()
    except Error as erro:
        raise _traduzir(erro) from erro
    finally:
        conn.close()


def executar(sql, parametros=()):
    """INSERT/UPDATE com commit. Devolve (lastrowid, rowcount)."""
    with transacao() as cursor:
        cursor.execute(sql, parametros)
        return cursor.lastrowid, cursor.rowcount


@contextmanager
def transacao():
    """Várias gravações numa transação: with transacao() as cur: ..."""
    conn = conectar()
    try:
        cursor = conn.cursor(dictionary=True)
        yield cursor
        conn.commit()
    except Error as erro:
        conn.rollback()
        raise _traduzir(erro) from erro
    except BaseException:
        conn.rollback()
        raise
    finally:
        conn.close()
