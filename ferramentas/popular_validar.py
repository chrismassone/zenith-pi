"""Confere a população do banco (só leitura).

Uso: python -m ferramentas.popular_validar [--teste]
"""
import re
import sys
from collections import Counter
from pathlib import Path

if "--teste" in sys.argv:
    from ferramentas import banco_teste
    banco_teste.usar()

from database.conexao import conectar
from mysql.connector import Error

FERIADOS = ("2026-11-02",)             # mesma lista de popular_gerar.py
AGENDA = ("2026-10-19", "2026-11-09")


def contagens_da_carga():
    arquivo = Path(__file__).resolve().parents[1] / "banco" / "2_populacao.sql"
    return Counter(re.match(r"INSERT INTO (\w+) ", l).group(1)
                   for l in arquivo.read_text(encoding="utf-8").splitlines()
                   if l.startswith("INSERT INTO "))

PRINCIPAIS = ["paciente", "atendimento", "atendimento_procedimento", "compra", "consumo"]
TODAS = PRINCIPAIS + ["procedimento_insumo", "insumo", "fornecedor", "unidade",
                      "profissional", "procedimento", "anamnese", "lancamento", "usuario"]
MINIMOS = dict(paciente=120, atendimento=250, atendimento_procedimento=300, compra=100,
               consumo=150, procedimento_insumo=20, insumo=20, fornecedor=4, unidade=3,
               profissional=1, procedimento=7, anamnese=60, lancamento=60)

# (descrição, consulta que deve devolver 0)
ZERO = [
    ("Saldo negativo no estoque atual",
     "SELECT COUNT(*) FROM vw_estoque_atual WHERE saldo < 0"),
    ("Saldo negativo em algum momento da história",
     """SELECT COUNT(*) FROM (
          SELECT id_insumo, SUM(delta) OVER (PARTITION BY id_insumo ORDER BY quando, ordem
                                             ROWS UNBOUNDED PRECEDING) AS saldo
            FROM (SELECT id_insumo, TIMESTAMP(data_compra) AS quando, 0 AS ordem,
                         quantidade AS delta FROM compra
                  UNION ALL
                  SELECT id_insumo, data_consumo, 1, -quantidade FROM consumo) m) h
        WHERE saldo < 0"""),
    ("Realizado sem nenhum item",
     """SELECT COUNT(*) FROM atendimento a WHERE a.status = 'Realizado'
          AND NOT EXISTS (SELECT 1 FROM atendimento_procedimento ap
                           WHERE ap.id_atendimento = a.id_atendimento)"""),
    ("Faltou/Cancelado contando como receita",
     """SELECT COUNT(*) FROM vw_faturamento f JOIN atendimento a USING (id_atendimento)
         WHERE a.status <> 'Realizado'"""),
    ("Faltou/Cancelado com itens ou pagamento",
     """SELECT COUNT(*) FROM atendimento a WHERE a.status IN ('Faltou', 'Cancelado')
          AND (a.forma_pagamento IS NOT NULL OR EXISTS (SELECT 1 FROM atendimento_procedimento ap
                                                         WHERE ap.id_atendimento = a.id_atendimento))"""),
    ("Consumo ligado a atendimento que não é Realizado",
     """SELECT COUNT(*) FROM consumo c JOIN atendimento a USING (id_atendimento)
         WHERE a.status <> 'Realizado'"""),
    ("Consumo avulso sem motivo",
     "SELECT COUNT(*) FROM consumo WHERE id_atendimento IS NULL AND observacao IS NULL"),
    ("Consumo antes da primeira compra do insumo",
     """SELECT COUNT(*) FROM consumo c WHERE c.data_consumo <
          (SELECT MIN(TIMESTAMP(data_compra)) FROM compra co WHERE co.id_insumo = c.id_insumo)"""),
    ("Agendado em sábado ou domingo",
     "SELECT COUNT(*) FROM atendimento WHERE status = 'Agendado' AND DAYOFWEEK(data_hora) IN (1, 7)"),
    ("Agendado em feriado",
     "SELECT COUNT(*) FROM atendimento WHERE status = 'Agendado' AND DATE(data_hora) IN ("
     + ", ".join(f"'{d}'" for d in FERIADOS) + ")"),
    ("Agendado com consumo de insumo",
     """SELECT COUNT(*) FROM consumo c JOIN atendimento a USING (id_atendimento)
         WHERE a.status = 'Agendado'"""),
    ("Agendado com forma de pagamento ou desconto",
     "SELECT COUNT(*) FROM atendimento WHERE status = 'Agendado' "
     "AND (forma_pagamento IS NOT NULL OR desconto <> 0)"),
    ("Dia útil da agenda com menos de 2 atendimentos",
     f"""SELECT COUNT(*) FROM (
           WITH RECURSIVE dias AS (SELECT DATE('{AGENDA[0]}') d UNION ALL
                                   SELECT d + INTERVAL 1 DAY FROM dias WHERE d < '{AGENDA[1]}')
           SELECT d FROM dias
            WHERE DAYOFWEEK(d) NOT IN (1, 7) AND d NOT IN ("""
     + ", ".join(f"'{x}'" for x in FERIADOS) + """)
              AND (SELECT COUNT(*) FROM atendimento a WHERE DATE(a.data_hora) = d
                     AND a.status = 'Agendado') < 2) x"""),
    ("Agendado no passado",
     "SELECT COUNT(*) FROM atendimento WHERE status = 'Agendado' AND DATE(data_hora) < '2026-10-16'"),
    ("Realizado/Faltou/Cancelado no futuro",
     "SELECT COUNT(*) FROM atendimento WHERE status <> 'Agendado' AND DATE(data_hora) >= '2026-10-16'"),
    ("valor_cobrado diferente do preço de tabela",
     """SELECT COUNT(*) FROM atendimento_procedimento ap
          JOIN procedimento p USING (id_procedimento) WHERE ap.valor_cobrado <> p.preco_tabela"""),
    ("E-mail fora do domínio @exemplo.invalid",
     "SELECT COUNT(*) FROM paciente WHERE email_paciente NOT LIKE '%@exemplo.invalid'"),
    ("Cidade com UF junto",
     "SELECT COUNT(*) FROM paciente WHERE cidade_paciente LIKE '%,%' OR cidade_paciente LIKE '% SP'"),
    ("Dois atendimentos no mesmo horário e unidade",
     """SELECT COUNT(*) FROM (SELECT id_unidade, data_hora FROM atendimento
                               GROUP BY id_unidade, data_hora HAVING COUNT(*) > 1) d"""),
]
# FKs: (tabela, coluna, tabela referenciada, coluna referenciada)
FKS = [("atendimento", "id_paciente", "paciente", "id_paciente"),
       ("atendimento", "id_unidade", "unidade", "id_unidade"),
       ("atendimento", "id_profissional", "profissional", "id_profissional"),
       ("atendimento_procedimento", "id_atendimento", "atendimento", "id_atendimento"),
       ("atendimento_procedimento", "id_procedimento", "procedimento", "id_procedimento"),
       ("procedimento_insumo", "id_procedimento", "procedimento", "id_procedimento"),
       ("procedimento_insumo", "id_insumo", "insumo", "id_insumo"),
       ("compra", "id_fornecedor", "fornecedor", "id_fornecedor"),
       ("compra", "id_insumo", "insumo", "id_insumo"),
       ("consumo", "id_insumo", "insumo", "id_insumo"),
       ("consumo", "id_atendimento", "atendimento", "id_atendimento"),
       ("anamnese", "id_paciente", "paciente", "id_paciente"),
       ("anamnese", "id_profissional", "profissional", "id_profissional"),
       ("lancamento", "id_unidade", "unidade", "id_unidade")]
# (descrição, consulta que deve devolver > 0)
POSITIVO = [
    ("Retornos pendentes (vencidos e sem retorno)",
     "SELECT COUNT(*) FROM vw_dash_retorno WHERE vencido AND NOT retornou"),
    ("Insumos abaixo do mínimo", "SELECT COUNT(*) FROM vw_estoque_atual WHERE abaixo_minimo"),
    ("Alertas de validade (até 60 dias ou vencidos)", "SELECT COUNT(*) FROM vw_alerta_validade"),
    ("Pacientes inativos", "SELECT COUNT(*) FROM paciente WHERE NOT ativo"),
    ("Pacientes sem atendimento",
     """SELECT COUNT(*) FROM paciente p WHERE NOT EXISTS
          (SELECT 1 FROM atendimento a WHERE a.id_paciente = p.id_paciente)"""),
    ("Agendamentos futuros", "SELECT COUNT(*) FROM atendimento WHERE status = 'Agendado'"),
    ("Faltas", "SELECT COUNT(*) FROM atendimento WHERE status = 'Faltou'"),
    ("Cancelamentos", "SELECT COUNT(*) FROM atendimento WHERE status = 'Cancelado'"),
    ("Consumos avulsos", "SELECT COUNT(*) FROM consumo WHERE id_atendimento IS NULL"),
    ("Consumo diferente do padrão (ajuste da profissional)",
     """SELECT COUNT(*) FROM consumo c JOIN atendimento_procedimento ap USING (id_atendimento)
          JOIN procedimento_insumo pi ON pi.id_procedimento = ap.id_procedimento
                                      AND pi.id_insumo = c.id_insumo
         WHERE c.quantidade <> pi.quantidade_padrao"""),
    ("Insumos comprados de mais de um fornecedor (N:M)",
     """SELECT COUNT(*) FROM (SELECT id_insumo FROM compra GROUP BY id_insumo
                               HAVING COUNT(DISTINCT id_fornecedor) > 1) x"""),
]


def main():
    conn = conectar()
    cur = conn.cursor()
    falhas = 0

    def ok(cond, texto):
        nonlocal falhas
        falhas += not cond
        print(("OK   " if cond else "FALHA"), texto)

    print("== Contagem por tabela ==")
    for t in TODAS:
        cur.execute(f"SELECT COUNT(*) FROM {t}")
        n = cur.fetchone()[0]
        minimo = MINIMOS.get(t)
        ok(minimo is None or n >= minimo, f"{t:26s} {n:5d}" + (f"  (mínimo {minimo})" if minimo else ""))

    print("\n== Contagens iguais às de 2_populacao.sql ==")
    cur.execute("SELECT DATABASE()")
    print("   banco:", cur.fetchone()[0])
    for t, esperado in sorted(contagens_da_carga().items()):
        cur.execute(f"SELECT COUNT(*) FROM {t}")
        n = cur.fetchone()[0]
        ok(n == esperado, f"{t:26s} banco {n:5d}  carga {esperado:5d}")

    cur.execute("SELECT MIN(data_hora), MAX(data_hora) FROM atendimento WHERE status <> 'Agendado'")
    print("   período dos atendimentos ocorridos:", *cur.fetchone())
    cur.execute("SELECT nome_clinica FROM unidade ORDER BY id_unidade")
    print("   unidades:", ", ".join(r[0] for r in cur.fetchall()))

    print("\n== Deve ser zero ==")
    for texto, sql in ZERO:
        cur.execute(sql)
        n = cur.fetchone()[0]
        ok(n == 0, f"{texto}: {n}")
    for tab, col, ref, refcol in FKS:
        cur.execute(f"""SELECT COUNT(*) FROM {tab} t LEFT JOIN {ref} r ON r.{refcol} = t.{col}
                        WHERE t.{col} IS NOT NULL AND r.{refcol} IS NULL""")
        n = cur.fetchone()[0]
        ok(n == 0, f"FK órfã {tab}.{col}: {n}")

    print("\n== Deve existir (cenários para os relatórios) ==")
    for texto, sql in POSITIVO:
        cur.execute(sql)
        n = cur.fetchone()[0]
        ok(n > 0, f"{texto}: {n}")

    print("\n== Gatilho de saldo no banco ==")
    cur.execute("SELECT id_insumo, saldo FROM vw_estoque_atual ORDER BY id_insumo LIMIT 1")
    id_ins, saldo = cur.fetchone()
    try:
        cur.execute("INSERT INTO consumo (id_insumo, quantidade, observacao) VALUES (%s, %s, %s)",
                    (id_ins, saldo + 1, "Teste automatico do gatilho"))
        conn.rollback()
        ok(False, "Consumo acima do saldo foi ACEITO (gatilho ausente?)")
    except Error as e:
        conn.rollback()
        ok(e.sqlstate == "45000", f"Consumo acima do saldo recusado pelo banco: {e.msg}")

    conn.close()
    print(f"\n{'Tudo certo.' if not falhas else f'{falhas} verificação(ões) falharam.'}")
    return falhas


if __name__ == "__main__":
    raise SystemExit(main())
