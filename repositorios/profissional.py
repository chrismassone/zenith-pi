"""SQL da tabela profissional."""
from repositorios.base import consultar


def listar(incluir_inativos=False):
    sql = "SELECT id_profissional, nome_completo, ativo FROM profissional"
    if not incluir_inativos:
        sql += " WHERE ativo = TRUE"
    return consultar(sql + " ORDER BY nome_completo")
