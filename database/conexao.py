import time

import mysql.connector
from mysql.connector import Error
from config import DB_CONFIG, DB_TIME_ZONE

TENTATIVAS = 3  # a rede da nuvem às vezes falha na primeira


def conectar():
    for tentativa in range(1, TENTATIVAS + 1):
        try:
            conn = mysql.connector.connect(**DB_CONFIG)
            cursor = conn.cursor()
            cursor.execute("SET time_zone = %s", (DB_TIME_ZONE,))
            cursor.close()
            return conn
        except Error as erro:
            # usuário ou senha errados não melhoram tentando de novo
            if erro.errno in (1044, 1045) or tentativa == TENTATIVAS:
                raise ConnectionError(
                    "Não foi possível conectar ao banco de dados. "
                    "Verifique a internet (ou se o MySQL está ligado) e o arquivo .env."
                ) from erro
            time.sleep(tentativa)
