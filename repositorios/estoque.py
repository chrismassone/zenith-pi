"""SQL de estoque: views de saldo e validade, compras e consumos."""
from repositorios.base import consultar, executar


def estoque(busca="", so_alertas=False, incluir_inativos=False):
    sql = """SELECT e.*,
                    (SELECT MIN(co.data_validade) FROM compra co
                      WHERE co.id_insumo = e.id_insumo
                        AND co.data_validade >= CURDATE()) AS proxima_validade,
                    EXISTS (SELECT 1 FROM vw_alerta_validade a
                             WHERE a.id_insumo = e.id_insumo) AS alerta_validade
               FROM vw_estoque_atual e WHERE 1=1"""
    par = []
    if not incluir_inativos:
        sql += " AND e.ativo = TRUE"
    if (busca or "").strip():
        sql += " AND e.nome_insumo LIKE %s"
        par.append(f"%{busca.strip()}%")
    linhas = consultar(sql + " ORDER BY e.nome_insumo", par)
    if so_alertas:
        linhas = [l for l in linhas if l["abaixo_minimo"] or l["alerta_validade"]]
    return linhas


def alertas_validade():
    return consultar("SELECT * FROM vw_alerta_validade ORDER BY data_validade")


def saldo(id_insumo):
    linha = consultar("SELECT saldo FROM vw_estoque_atual WHERE id_insumo = %s",
                      (id_insumo,), um=True)
    return linha["saldo"] if linha else None


def listar_compras(busca="", limite=300):
    sql = """SELECT co.*, i.nome_insumo, i.unidade_medida, f.razao_social
               FROM compra co
               JOIN insumo i USING (id_insumo)
               JOIN fornecedor f USING (id_fornecedor) WHERE 1=1"""
    par = []
    if (busca or "").strip():
        sql += " AND (i.nome_insumo LIKE %s OR f.razao_social LIKE %s OR co.lote LIKE %s)"
        par += [f"%{busca.strip()}%"] * 3
    return consultar(sql + " ORDER BY co.data_compra DESC, co.id_compra DESC LIMIT %s",
                     par + [limite])


def inserir_compra(d):
    novo_id, _ = executar(
        """INSERT INTO compra (id_fornecedor, id_insumo, data_compra, quantidade,
                               preco_unitario, lote, data_validade)
           VALUES (%(id_fornecedor)s, %(id_insumo)s, %(data_compra)s, %(quantidade)s,
                   %(preco_unitario)s, %(lote)s, %(data_validade)s)""", d)
    return novo_id


def listar_consumos(busca="", limite=300):
    sql = """SELECT c.*, i.nome_insumo, i.unidade_medida, p.nome_completo AS paciente
               FROM consumo c
               JOIN insumo i USING (id_insumo)
               LEFT JOIN atendimento a ON a.id_atendimento = c.id_atendimento
               LEFT JOIN paciente p ON p.id_paciente = a.id_paciente WHERE 1=1"""
    par = []
    if (busca or "").strip():
        sql += " AND i.nome_insumo LIKE %s"
        par.append(f"%{busca.strip()}%")
    return consultar(sql + " ORDER BY c.data_consumo DESC, c.id_consumo DESC LIMIT %s",
                     par + [limite])


def inserir_consumo_avulso(id_insumo, quantidade, quando, observacao):
    novo_id, _ = executar(
        """INSERT INTO consumo (id_insumo, id_atendimento, quantidade, data_consumo, observacao)
           VALUES (%s, NULL, %s, %s, %s)""", (id_insumo, quantidade, quando, observacao))
    return novo_id
