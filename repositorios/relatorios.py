"""Leituras de Início, Financeiro e Dashboard, só das views vw_*. Período em 'aaaa-mm'."""
from repositorios.base import consultar, executar


def _filtros(alias="", ano_ini=None, ano_fim=None, id_unidade=None, id_procedimento=None,
             tem_procedimento=False):
    p = f"{alias}." if alias else ""
    cond, par = [], []
    if ano_ini:
        cond.append(f"{p}ano_mes >= %s")
        par.append(ano_ini)
    if ano_fim:
        cond.append(f"{p}ano_mes <= %s")
        par.append(ano_fim)
    if id_unidade:
        cond.append(f"{p}id_unidade = %s")
        par.append(id_unidade)
    if id_procedimento and tem_procedimento:
        cond.append(f"{p}id_procedimento = %s")
        par.append(id_procedimento)
    return (" WHERE " + " AND ".join(cond)) if cond else "", par


def meses_disponiveis():
    return [r["ano_mes"] for r in consultar(
        "SELECT DISTINCT ano_mes FROM vw_dash_kpis_mensal ORDER BY ano_mes")]


# financeiro / dashboard
def por_unidade(ano_ini, ano_fim, id_unidade=None):
    onde, par = _filtros("", ano_ini, ano_fim, id_unidade)
    return consultar(f"""SELECT id_unidade, nome_clinica,
                                SUM(faturamento) AS faturamento,
                                SUM(dias_com_atendimento) AS dias,
                                SUM(custo_locacao) AS custo_locacao,
                                SUM(despesas) AS despesas,
                                SUM(margem) AS margem
                           FROM vw_dash_unidade {onde}
                          GROUP BY id_unidade, nome_clinica ORDER BY nome_clinica""", par)


def kpis(ano_ini, ano_fim, id_unidade=None):
    onde, par = _filtros("", ano_ini, ano_fim, id_unidade)
    return consultar(f"""SELECT COALESCE(SUM(realizados), 0) AS realizados,
                                COALESCE(SUM(faltas), 0) AS faltas,
                                COALESCE(SUM(cancelados), 0) AS cancelados,
                                COALESCE(SUM(faturamento), 0) AS faturamento
                           FROM vw_dash_kpis_mensal {onde}""", par, um=True)


def mensal(ano_ini, ano_fim, id_unidade=None):
    onde, par = _filtros("", ano_ini, ano_fim, id_unidade)
    return consultar(f"""SELECT ano_mes, SUM(faturamento) AS faturamento,
                                SUM(realizados) AS realizados
                           FROM vw_dash_kpis_mensal {onde}
                          GROUP BY ano_mes ORDER BY ano_mes""", par)


def por_procedimento(ano_ini, ano_fim, id_unidade=None, id_procedimento=None):
    onde, par = _filtros("", ano_ini, ano_fim, id_unidade, id_procedimento, True)
    return consultar(f"""SELECT id_procedimento, nome_procedimento,
                                SUM(quantidade_realizada) AS quantidade,
                                SUM(faturamento) AS faturamento
                           FROM vw_dash_procedimento {onde}
                          GROUP BY id_procedimento, nome_procedimento
                          ORDER BY faturamento DESC""", par)


def procedimento_por_unidade_mes(ano_ini, ano_fim, id_unidade=None, id_procedimento=None):
    onde, par = _filtros("", ano_ini, ano_fim, id_unidade, id_procedimento, True)
    return consultar(f"""SELECT ano_mes, id_unidade, SUM(faturamento) AS faturamento,
                                SUM(quantidade_realizada) AS quantidade
                           FROM vw_dash_procedimento {onde}
                          GROUP BY ano_mes, id_unidade ORDER BY ano_mes""", par)


def comparecimento(ano_ini, ano_fim, id_unidade=None):
    onde, par = _filtros("", ano_ini, ano_fim, id_unidade)
    return consultar(f"""SELECT COALESCE(SUM(realizados), 0) AS realizados,
                                COALESCE(SUM(faltas), 0) AS faltas
                           FROM vw_dash_comparecimento {onde}""", par, um=True)


def retornos(id_unidade=None, id_procedimento=None):
    cond, par = [], []
    if id_unidade:
        cond.append("id_unidade = %s")
        par.append(id_unidade)
    if id_procedimento:
        cond.append("id_procedimento = %s")
        par.append(id_procedimento)
    onde = (" WHERE " + " AND ".join(cond)) if cond else ""
    return consultar(f"SELECT * FROM vw_dash_retorno{onde} ORDER BY data_retorno_prevista",
                     par)


def pacientes_cidade_bairro():
    return consultar("""SELECT cidade, bairro, pacientes_ativos, pacientes_total
                          FROM vw_dash_pacientes_cidade_bairro
                         ORDER BY pacientes_ativos DESC, cidade, bairro""")


def estoque_alertas():
    return consultar("""SELECT * FROM vw_estoque_atual
                         WHERE ativo = TRUE AND abaixo_minimo ORDER BY nome_insumo""")


def validade_alertas():
    return consultar("SELECT * FROM vw_alerta_validade ORDER BY data_validade")


# lançamentos
def listar_lancamentos(ano_ini, ano_fim, id_unidade=None):
    sql = """SELECT l.*, u.nome_clinica FROM lancamento l
               LEFT JOIN unidade u USING (id_unidade)
              WHERE DATE_FORMAT(l.data_lancamento, '%Y-%m') BETWEEN %s AND %s"""
    par = [ano_ini, ano_fim]
    if id_unidade:
        sql += " AND l.id_unidade = %s"
        par.append(id_unidade)
    return consultar(sql + " ORDER BY l.data_lancamento DESC, l.id_lancamento DESC", par)


def despesas_gerais(ano_ini, ano_fim):
    """Despesas sem unidade."""
    return consultar(
        """SELECT COALESCE(SUM(valor), 0) AS total FROM lancamento
            WHERE tipo = 'DESPESA' AND id_unidade IS NULL
              AND DATE_FORMAT(data_lancamento, '%Y-%m') BETWEEN %s AND %s""",
        (ano_ini, ano_fim), um=True)["total"]


def inserir_lancamento(d):
    novo_id, _ = executar(
        """INSERT INTO lancamento (id_unidade, categoria, descricao, valor, data_lancamento,
                                   tipo)
           VALUES (%(id_unidade)s, %(categoria)s, %(descricao)s, %(valor)s,
                   %(data_lancamento)s, %(tipo)s)""", d)
    return novo_id


def atualizar_lancamento(id_, d):
    _, n = executar(
        """UPDATE lancamento SET id_unidade = %(id_unidade)s, categoria = %(categoria)s,
                  descricao = %(descricao)s, valor = %(valor)s,
                  data_lancamento = %(data_lancamento)s, tipo = %(tipo)s
            WHERE id_lancamento = %(_id)s""", {**d, "_id": id_})
    return n


# início
def resumo_inicio(hoje, fim_semana):
    return consultar(
        """SELECT (SELECT COUNT(*) FROM paciente WHERE ativo = TRUE) AS pacientes_ativos,
                  (SELECT COUNT(*) FROM atendimento
                    WHERE DATE(data_hora) = %s AND status IN ('Agendado', 'Realizado'))
                      AS atendimentos_hoje,
                  (SELECT COUNT(*) FROM atendimento
                    WHERE DATE(data_hora) BETWEEN %s AND %s
                      AND status IN ('Agendado', 'Realizado')) AS atendimentos_semana,
                  (SELECT COUNT(*) FROM vw_dash_retorno WHERE vencido AND NOT retornou)
                      AS retornos_pendentes,
                  (SELECT COUNT(*) FROM vw_estoque_atual WHERE ativo = TRUE AND abaixo_minimo)
                      AS abaixo_minimo,
                  (SELECT COUNT(DISTINCT id_insumo) FROM vw_alerta_validade)
                      AS alerta_validade""", (hoje, hoje, fim_semana), um=True)


def agenda_do_dia(dia):
    return consultar(
        """SELECT a.data_hora, a.status, p.nome_completo AS paciente, u.nome_clinica
             FROM atendimento a JOIN paciente p USING (id_paciente)
             JOIN unidade u USING (id_unidade)
            WHERE DATE(a.data_hora) = %s AND a.status <> 'Cancelado'
            ORDER BY a.data_hora""", (dia,))
