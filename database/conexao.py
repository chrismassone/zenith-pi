import mysql.connector
from mysql.connector import Error
from config import DB_CONFIG


def conectar():
    """Abre uma conexão com o banco. Quem chamar deve fechá-la."""
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Error as erro:
        raise ConnectionError(
            "Não foi possível conectar ao banco de dados. "
            "Verifique se o MySQL está ligado e se o arquivo .env está correto."
        ) from erro
