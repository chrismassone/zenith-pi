"""SQL de atendimento, itens (atendimento_procedimento) e o consumo de
insumos gerado ao realizar o atendimento. Sem regra de negócio."""
from repositorios.base import consultar, transacao


def listar(busca="", id_unidade=None, status=None, data_ini=None, data_fim=None,
           id_paciente=None):
    sql = """SELECT v.id_atendimento, v.data_hora, v.status, v.valor_total, v.qtd_itens,
                    v.id_unidade, u.nome_clinica, p.id_paciente, p.nome_completo AS paciente,
                    (SELECT GROUP_CONCAT(pr.nome_procedimento ORDER BY ap.id_atend_proc
                                         SEPARATOR ', ')
                       FROM atendimento_procedimento ap
                       JOIN procedimento pr USING (id_procedimento)
                      WHERE ap.id_atendimento = v.id_atendimento) AS procedimentos
               FROM vw_valor_atendimento v
               JOIN paciente p ON p.id_paciente = v.id_paciente
               JOIN unidade u  ON u.id_unidade  = v.id_unidade
              WHERE 1=1"""
    par = []
    if (busca or "").strip():
        sql += " AND p.nome_completo LIKE %s"
        par.append(f"%{busca.strip()}%")
    if id_unidade:
        sql += " AND v.id_unidade = %s"
        par.append(id_unidade)
    if status:
        sql += " AND v.status = %s"
        par.append(status)
    if id_paciente:
        sql += " AND v.id_paciente = %s"
        par.append(id_paciente)
    if data_ini:
        sql += " AND v.data_hora >= %s"
        par.append(data_ini)
    if data_fim:
        sql += " AND v.data_hora < %s + INTERVAL 1 DAY"
        par.append(data_fim)
    return consultar(sql + " ORDER BY v.data_hora DESC", par)


def buscar(id_atendimento):
    a = consultar("""SELECT a.*, v.subtotal, v.valor_total
                       FROM atendimento a JOIN vw_valor_atendimento v USING (id_atendimento)
                      WHERE a.id_atendimento = %s""", (id_atendimento,), um=True)
    if a:
        a["itens"] = consultar(
            """SELECT ap.*, pr.nome_procedimento FROM atendimento_procedimento ap
                 JOIN procedimento pr USING (id_procedimento)
                WHERE ap.id_atendimento = %s ORDER BY ap.id_atend_proc""", (id_atendimento,))
        a["qtd_consumos"] = consultar(
            "SELECT COUNT(*) AS n FROM consumo WHERE id_atendimento = %s",
            (id_atendimento,), um=True)["n"]
    return a


def sugestao_insumos(ids_procedimento):
    """Insumos padrão dos procedimentos, com o saldo atual de cada um."""
    if not ids_procedimento:
        return []
    marcas = ", ".join(["%s"] * len(ids_procedimento))
    return consultar(
        f"""SELECT pi.id_procedimento, pi.id_insumo, pi.quantidade_padrao,
                   e.nome_insumo, e.marca, e.unidade_medida, e.saldo
              FROM procedimento_insumo pi
              JOIN vw_estoque_atual e ON e.id_insumo = pi.id_insumo
             WHERE pi.id_procedimento IN ({marcas}) AND e.ativo = TRUE
             ORDER BY e.nome_insumo""", list(ids_procedimento))


def saldos(ids_insumo):
    if not ids_insumo:
        return {}
    marcas = ", ".join(["%s"] * len(ids_insumo))
    linhas = consultar(f"SELECT id_insumo, saldo, nome_insumo, unidade_medida "
                       f"FROM vw_estoque_atual WHERE id_insumo IN ({marcas})", list(ids_insumo))
    return {l["id_insumo"]: l for l in linhas}


def salvar(id_atendimento, d, itens, consumos=()):
    """Grava cabeçalho, itens e (opcionalmente) consumos numa transação só.
    itens = [dict(id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado)]
    consumos = [(id_insumo, quantidade)] já conferidos pelo serviço."""
    with transacao() as cur:
        if id_atendimento is None:
            cur.execute("""INSERT INTO atendimento (id_profissional, id_paciente, id_unidade,
                                   data_hora, status, forma_pagamento, desconto, observacao)
                           VALUES (%(id_profissional)s, %(id_paciente)s, %(id_unidade)s,
                                   %(data_hora)s, %(status)s, %(forma_pagamento)s,
                                   %(desconto)s, %(observacao)s)""", d)
            id_atendimento = cur.lastrowid
        else:
            cur.execute("""UPDATE atendimento SET id_profissional = %(id_profissional)s,
                                  id_paciente = %(id_paciente)s, id_unidade = %(id_unidade)s,
                                  data_hora = %(data_hora)s, status = %(status)s,
                                  forma_pagamento = %(forma_pagamento)s,
                                  desconto = %(desconto)s, observacao = %(observacao)s
                            WHERE id_atendimento = %(_id)s""", {**d, "_id": id_atendimento})
            # itens são substituídos: exige DELETE do zenith_app nesta tabela de detalhe
            cur.execute("DELETE FROM atendimento_procedimento WHERE id_atendimento = %s",
                        (id_atendimento,))
        for it in itens:
            cur.execute("""INSERT INTO atendimento_procedimento (id_atendimento, id_procedimento,
                                   quantidade_aplicada, regiao_aplicada, valor_cobrado)
                           VALUES (%s, %s, %s, %s, %s)""",
                        (id_atendimento, it["id_procedimento"], it["quantidade_aplicada"],
                         it["regiao_aplicada"], it["valor_cobrado"]))
        for id_insumo, qtd in consumos:
            cur.execute("""INSERT INTO consumo (id_insumo, id_atendimento, quantidade,
                                                data_consumo)
                           VALUES (%s, %s, %s, %s)""",
                        (id_insumo, id_atendimento, qtd, d["data_hora"]))
    return id_atendimento
