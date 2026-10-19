"""Execução de SQL parametrizado, comum a todos os repositórios.

Os repositórios só montam SQL e devolvem dados; não têm regra de negócio.
Erros do MySQL viram exceções próprias, para a camada de serviços traduzir
em mensagens claras ao usuário.
"""
from contextlib import contextmanager

from mysql.connector import Error

from database.conexao import conectar

ERRO_DUPLICADO = 1062   # violação de UNIQUE
ERRO_FK = 1452          # referência para registro inexistente
ERRO_CHECK = 3819       # violação de CHECK
SINAL_GATILHO = "45000" # SIGNAL dos gatilhos (ex.: saldo insuficiente)


class RegistroDuplicado(Exception):
    """Valor único repetido. .chave traz o nome da restrição (ex.: uq_paciente_cpf)."""

    def __init__(self, chave):
        self.chave = chave
        super().__init__(chave)


class RegraDoBanco(Exception):
    """O banco recusou a gravação por uma regra (gatilho, CHECK ou FK)."""


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
    """SELECT: devolve lista de dicionários (ou um dicionário / None)."""
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
    """INSERT/UPDATE isolado, com commit. Devolve (lastrowid, rowcount)."""
    with transacao() as cursor:
        cursor.execute(sql, parametros)
        return cursor.lastrowid, cursor.rowcount


@contextmanager
def transacao():
    """Várias gravações que entram juntas ou não entram:

        with transacao() as cur:
            cur.execute(...)
            cur.execute(...)
    """
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
