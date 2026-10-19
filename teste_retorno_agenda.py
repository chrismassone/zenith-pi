"""Regra única de retorno (view vw_dash_retorno + serviço do app) e regras da
agenda futura. Banco zenith_teste; dados fictícios removidos ao final.

Regra: data prevista = último Realizado + intervalo; retornou = há Agendado
ou Realizado do paciente depois do último procedimento; vencido = prevista <
hoje; pendente = vencido e não retornou; taxa = vencidos que retornaram /
vencidos."""
import banco_teste
banco_teste.usar()  # grava só no banco zenith_teste

import re
from collections import Counter
from datetime import date, datetime, timedelta
from pathlib import Path

from repositorios.base import consultar, transacao
from servicos import relatorios
from servicos.sessao import Sessao

S = Sessao(dict(id_usuario=0, nome="Teste", email="t@exemplo.invalid", perfil="Gerente"))
HOJE = date.today()
TOXINA = consultar("SELECT id_procedimento, intervalo_retorno_dias d FROM procedimento "
                   "WHERE nome_procedimento = 'Toxina botulínica'", um=True)
INTERVALO = TOXINA["d"]
casos = []


def caso(nome, obtido, esperado):
    casos.append((nome, obtido, esperado))


def cpf_ficticio(base):
    b = [int(c) for c in f"{base:09d}"]
    for t in (9, 10):
        dv = sum(d * (t + 1 - i) for i, d in enumerate(b)) * 10 % 11
        b.append(0 if dv == 10 else dv)
    return "".join(map(str, b))


def paciente(cur, n):
    cpf = next(cpf_ficticio(b) for b in range(900000000 + n * 1000, 999999999)
               if not consultar("SELECT 1 FROM paciente WHERE cpf=%s", (cpf_ficticio(b),)))
    cur.execute("""INSERT INTO paciente (nome_completo, cpf, data_nasc, telefone_paciente,
                     cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente,
                     origem_captacao) VALUES (%s, %s, '1990-01-01', '11987654321',
                     '03047000', 'Rua Ficticia, 1', 'Mooca', 'São Paulo', 'Indicação')""",
                (f"Teste Retorno {n}", cpf))
    return cur.lastrowid


def atendimento(cur, id_pac, quando, status):
    cur.execute("""INSERT INTO atendimento (id_profissional, id_paciente, id_unidade, data_hora,
                     status, forma_pagamento) VALUES (1, %s, 1, %s, %s, %s)""",
                (id_pac, quando, status, "Pix" if status == "Realizado" else None))
    id_at = cur.lastrowid
    cur.execute("""INSERT INTO atendimento_procedimento (id_atendimento, id_procedimento,
                     quantidade_aplicada, regiao_aplicada, valor_cobrado)
                   VALUES (%s, %s, 30, 'Testa', 1200)""", (id_at, TOXINA["id_procedimento"]))


def as_datetime(d):
    return datetime(d.year, d.month, d.day, 10, 0)


# ---------------- regra de retorno ----------------
pacientes = {}
try:
    with transacao() as cur:
        # A: vencido e retornou (há Agendado depois do último procedimento)
        pacientes["A"] = paciente(cur, 1)
        atendimento(cur, pacientes["A"], as_datetime(HOJE - timedelta(days=INTERVALO + 30)),
                    "Realizado")
        atendimento(cur, pacientes["A"], as_datetime(HOJE + timedelta(days=5)), "Agendado")
        # B: vencido e não retornou -> pendente
        pacientes["B"] = paciente(cur, 2)
        atendimento(cur, pacientes["B"], as_datetime(HOJE - timedelta(days=INTERVALO + 30)),
                    "Realizado")
        # C: ainda não vencido, sem retorno -> NÃO é pendente
        pacientes["C"] = paciente(cur, 3)
        atendimento(cur, pacientes["C"], as_datetime(HOJE - timedelta(days=10)), "Realizado")
        # D: previsto exatamente para hoje -> NÃO vencido (regra é estritamente "< hoje")
        pacientes["D"] = paciente(cur, 4)
        atendimento(cur, pacientes["D"], as_datetime(HOJE - timedelta(days=INTERVALO)),
                    "Realizado")
        # E: falta ou cancelamento depois não conta como retorno
        pacientes["E"] = paciente(cur, 5)
        atendimento(cur, pacientes["E"], as_datetime(HOJE - timedelta(days=INTERVALO + 30)),
                    "Realizado")
        atendimento(cur, pacientes["E"], as_datetime(HOJE - timedelta(days=3)), "Faltou")

    def linha(chave):
        return consultar("""SELECT vencido, retornou, data_retorno_prevista FROM vw_dash_retorno
                             WHERE id_paciente = %s""", (pacientes[chave],), um=True)

    a, b, c, d, e = (linha(k) for k in "ABCDE")
    caso("Vencido e retornou: vencido=1, retornou=1", (a["vencido"], a["retornou"]), (1, 1))
    caso("Vencido sem retorno: pendente (vencido=1, retornou=0)",
         (b["vencido"], b["retornou"]), (1, 0))
    caso("Não vencido: vencido=0 (não conta como pendente)", (c["vencido"], c["retornou"]),
         (0, 0))
    caso("Previsto para hoje: ainda não vencido (estritamente < hoje)", d["vencido"], 0)
    caso("Data prevista = último Realizado + intervalo", d["data_retorno_prevista"], HOJE)
    caso("Falta depois do procedimento não conta como retorno", e["retornou"], 0)

    # o serviço do app usa exatamente a mesma regra (mesma view)
    dash = relatorios.dashboard(S, "2025-01", "2027-12")
    ids_pendentes = {r["id_paciente"] for r in dash["retornos_pendentes"]}
    caso("Serviço: pendentes incluem B e E, e não A, C, D",
         (pacientes["B"] in ids_pendentes, pacientes["E"] in ids_pendentes,
          pacientes["A"] in ids_pendentes, pacientes["C"] in ids_pendentes,
          pacientes["D"] in ids_pendentes), (True, True, False, False, False))
    v = consultar("""SELECT SUM(vencido) ven, SUM(vencido AND retornou) ret,
                            SUM(vencido AND NOT retornou) pen FROM vw_dash_retorno""", um=True)
    caso("Serviço: taxa = vencidos que retornaram / vencidos",
         round(float(dash["taxa_retorno"]), 6), round(float(v["ret"]) / float(v["ven"]), 6))
    caso("Início: cartão de pendentes = vencido e não retornou",
         relatorios.inicio(S)["retornos_pendentes"], int(v["pen"]))
finally:
    with transacao() as cur:
        for id_pac in pacientes.values():
            cur.execute("DELETE ap FROM atendimento_procedimento ap JOIN atendimento a "
                        "USING (id_atendimento) WHERE a.id_paciente = %s", (id_pac,))
            cur.execute("DELETE FROM atendimento WHERE id_paciente = %s", (id_pac,))
            cur.execute("DELETE FROM paciente WHERE id_paciente = %s", (id_pac,))
    print("Registros de teste removidos.")

# ---------------- agenda futura (dados da carga, no zenith_teste) ----------------
agendados = consultar("SELECT id_atendimento, data_hora FROM atendimento WHERE status='Agendado'")
caso("Nenhum Agendado em sábado ou domingo",
     [a["id_atendimento"] for a in agendados if a["data_hora"].weekday() >= 5], [])
caso("Nenhum Agendado no feriado de 02/11/2026",
     [a["id_atendimento"] for a in agendados if a["data_hora"].date() == date(2026, 11, 2)], [])
por_dia = Counter(a["data_hora"].date() for a in agendados)
dias = [date(2026, 10, 19) + timedelta(days=i) for i in range(30)]
uteis = [d for d in dias if d.weekday() < 5 and d != date(2026, 11, 2)][:15]
caso("15 dias úteis de 19/10 a 09/11/2026", (uteis[0], uteis[-1]),
     (date(2026, 10, 19), date(2026, 11, 9)))
caso("Cada dia útil da agenda com 2 a 5 (exceto 19/10, que já tinha 7)",
     [d for d in uteis[1:] if not 2 <= por_dia[d] <= 5], [])
caso("Nenhum Agendado com consumo",
     consultar("SELECT COUNT(*) n FROM consumo c JOIN atendimento a USING (id_atendimento) "
               "WHERE a.status = 'Agendado'", um=True)["n"], 0)

# ---------------- dados antigos preservados ----------------
sql = (Path(__file__).resolve().parent / "banco" / "historico" / "zenith_populacao.sql").read_text(encoding="utf-8")
ids_at = [int(m) for m in re.findall(r"^INSERT INTO atendimento \(.*?VALUES \((\d+),", sql, re.M)]
ids_ap = [int(m) for m in re.findall(r"^INSERT INTO atendimento_procedimento \(.*?VALUES \((\d+),",
                                     sql, re.M)]
caso("Atendimentos 1 a 261 preservados e novos a partir de 262",
     (ids_at[:261] == list(range(1, 262)), min(ids_at[261:]) == 262), (True, True))
caso("Itens 1 a 321 preservados e novos a partir de 322",
     (ids_ap[:321] == list(range(1, 322)), min(ids_ap[321:]) == 322), (True, True))

falhas = 0
for nome, obtido, esperado in casos:
    ok = obtido == esperado
    falhas += not ok
    print(("OK   " if ok else "FALHA"), nome, "" if ok else f"(obtido {obtido!r})")
print(f"\n{len(casos) - falhas}/{len(casos)} testes passaram")
raise SystemExit(falhas)
