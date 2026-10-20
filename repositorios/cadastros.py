from repositorios.base import consultar, executar, transacao


def _filtro(sql, coluna_busca, busca, incluir_inativos, ordem):
    parametros = []
    if not incluir_inativos:
        sql += " AND ativo = TRUE"
    if (busca or "").strip():
        sql += f" AND {coluna_busca} LIKE %s"
        parametros.append(f"%{busca.strip()}%")
    return consultar(sql + f" ORDER BY {ordem}", parametros)


def _inserir(tabela, d):
    colunas = ", ".join(d)
    marcas = ", ".join(f"%({c})s" for c in d)
    novo_id, _ = executar(f"INSERT INTO {tabela} ({colunas}) VALUES ({marcas})", d)
    return novo_id


def _atualizar(tabela, chave, id_, d):
    sets = ", ".join(f"{c} = %({c})s" for c in d)
    _, linhas = executar(f"UPDATE {tabela} SET {sets} WHERE {chave} = %(_id)s",
                         {**d, "_id": id_})
    return linhas


def _ativo(tabela, chave, id_, ativo):
    _, linhas = executar(f"UPDATE {tabela} SET ativo = %s WHERE {chave} = %s", (ativo, id_))
    return linhas


# unidade
def listar_unidades(busca="", incluir_inativos=False):
    return _filtro("SELECT * FROM unidade WHERE 1=1", "nome_clinica", busca,
                   incluir_inativos, "nome_clinica")


def inserir_unidade(d):
    return _inserir("unidade", d)


def atualizar_unidade(id_, d):
    return _atualizar("unidade", "id_unidade", id_, d)


def ativar_unidade(id_, ativo):
    return _ativo("unidade", "id_unidade", id_, ativo)


# fornecedor
def listar_fornecedores(busca="", incluir_inativos=False):
    return _filtro("SELECT * FROM fornecedor WHERE 1=1", "razao_social", busca,
                   incluir_inativos, "razao_social")


def inserir_fornecedor(d):
    return _inserir("fornecedor", d)


def atualizar_fornecedor(id_, d):
    return _atualizar("fornecedor", "id_fornecedor", id_, d)


def ativar_fornecedor(id_, ativo):
    return _ativo("fornecedor", "id_fornecedor", id_, ativo)


# procedimento
def listar_procedimentos(busca="", incluir_inativos=False):
    return _filtro(
        """SELECT p.*, c.custo_insumos, c.qtd_insumos
             FROM procedimento p
             JOIN vw_custo_procedimento c USING (id_procedimento) WHERE 1=1""",
        "p.nome_procedimento", busca, incluir_inativos, "p.nome_procedimento")


def insumos_do_procedimento(id_procedimento):
    return consultar(
        """SELECT pi.id_insumo, pi.quantidade_padrao, i.nome_insumo, i.marca,
                  i.unidade_medida
             FROM procedimento_insumo pi JOIN insumo i USING (id_insumo)
            WHERE pi.id_procedimento = %s ORDER BY i.nome_insumo""", (id_procedimento,))


def salvar_procedimento(id_, d, insumos):
    """Grava o procedimento e a lista de insumos padrão na mesma transação."""
    with transacao() as cur:
        if id_ is None:
            cur.execute("""INSERT INTO procedimento (nome_procedimento, preco_tabela,
                                                     intervalo_retorno_dias)
                           VALUES (%(nome_procedimento)s, %(preco_tabela)s,
                                   %(intervalo_retorno_dias)s)""", d)
            id_ = cur.lastrowid
        else:
            cur.execute("""UPDATE procedimento SET nome_procedimento = %(nome_procedimento)s,
                                  preco_tabela = %(preco_tabela)s,
                                  intervalo_retorno_dias = %(intervalo_retorno_dias)s
                            WHERE id_procedimento = %(_id)s""", {**d, "_id": id_})
        novos = {i for i, _ in insumos}
        cur.execute("SELECT id_insumo FROM procedimento_insumo WHERE id_procedimento = %s",
                    (id_,))
        atuais = {r["id_insumo"] for r in cur.fetchall()}
        for removido in atuais - novos:
            cur.execute("DELETE FROM procedimento_insumo WHERE id_procedimento = %s "
                        "AND id_insumo = %s", (id_, removido))
        for id_insumo, qtd in insumos:
            cur.execute("""INSERT INTO procedimento_insumo (id_procedimento, id_insumo,
                                                            quantidade_padrao)
                           VALUES (%s, %s, %s)
                           ON DUPLICATE KEY UPDATE quantidade_padrao = VALUES(quantidade_padrao)""",
                        (id_, id_insumo, qtd))
    return id_


def ativar_procedimento(id_, ativo):
    return _ativo("procedimento", "id_procedimento", id_, ativo)


# insumo
def listar_insumos(busca="", incluir_inativos=False):
    return _filtro("SELECT * FROM insumo WHERE 1=1", "nome_insumo", busca,
                   incluir_inativos, "nome_insumo")


def inserir_insumo(d):
    return _inserir("insumo", d)


def atualizar_insumo(id_, d):
    return _atualizar("insumo", "id_insumo", id_, d)


def ativar_insumo(id_, ativo):
    return _ativo("insumo", "id_insumo", id_, ativo)


def listar_profissionais():
    return consultar("SELECT id_profissional, nome_completo FROM profissional "
                     "WHERE ativo = TRUE ORDER BY nome_completo")
