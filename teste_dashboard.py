"""Compara cada número do Dashboard (que lê as views vw_*) com um cálculo
independente feito direto nas TABELAS, sem usar nenhuma view. Só leitura.
Uso: python teste_dashboard.py"""
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP

from repositorios.base import consultar
from servicos import relatorios
from servicos.sessao import Sessao

S = Sessao(dict(id_usuario=0, nome="Teste", email="t@exemplo.invalid", perfil="Gerente"))
D2 = Decimal("0.01")


def independente(de, ate, unidade=None, procedimento=None):
    atend = consultar("""SELECT id_atendimento, id_paciente, id_unidade, data_hora, status, desconto
                           FROM atendimento""")
    itens = defaultdict(list)
    for i in consultar("SELECT id_atendimento, id_procedimento, valor_cobrado "
                       "FROM atendimento_procedimento"):
        itens[i["id_atendimento"]].append(i)
    loc = {u["id_unidade"]: u["valor_locacao"] for u in
           consultar("SELECT id_unidade, valor_locacao FROM unidade")}
    no_periodo = lambda a: de <= a["data_hora"].strftime("%Y-%m") <= ate and (
        not unidade or a["id_unidade"] == unidade)
    real = [a for a in atend if a["status"] == "Realizado" and no_periodo(a)]

    def valor(a):
        sub = sum((i["valor_cobrado"] for i in itens[a["id_atendimento"]]), Decimal(0))
        return max(sub - a["desconto"], Decimal(0)), sub

    fat_un, dias, fat_mes, fat_proc, qtd_proc = (defaultdict(Decimal), defaultdict(set),
                                                 defaultdict(Decimal), defaultdict(Decimal),
                                                 defaultdict(int))
    for a in real:
        v, sub = valor(a)
        mes = a["data_hora"].strftime("%Y-%m")
        dias[(a["id_unidade"], mes)].add(a["data_hora"].date())
        for i in itens[a["id_atendimento"]]:
            parte = i["valor_cobrado"] - (a["desconto"] * i["valor_cobrado"] / sub if sub else 0)
            fat_proc[i["id_procedimento"]] += parte
            qtd_proc[i["id_procedimento"]] += 1
            if procedimento and i["id_procedimento"] == procedimento:
                fat_un[a["id_unidade"]] += parte
                fat_mes[mes] += parte
        if not procedimento:
            fat_un[a["id_unidade"]] += v
            fat_mes[mes] += v
    custo = defaultdict(Decimal)
    for (u, mes), ds in dias.items():
        custo[u] += loc[u] * len(ds)
    for l in consultar("SELECT id_unidade, valor, data_lancamento FROM lancamento "
                       "WHERE tipo='DESPESA' AND id_unidade IS NOT NULL"):
        if de <= l["data_lancamento"].strftime("%Y-%m") <= ate and (
                not unidade or l["id_unidade"] == unidade):
            custo[l["id_unidade"]] += l["valor"]
    faturamento = sum(fat_un.values(), Decimal(0))
    n = qtd_proc[procedimento] if procedimento else len(real)
    faltas = sum(1 for a in atend if a["status"] == "Faltou" and no_periodo(a))
    # retorno: último procedimento realizado (com intervalo) por paciente ativo
    procs = {p["id_procedimento"]: p["intervalo_retorno_dias"] for p in
             consultar("SELECT id_procedimento, intervalo_retorno_dias FROM procedimento")}
    ativos = {p["id_paciente"] for p in consultar("SELECT id_paciente FROM paciente WHERE ativo")}
    ultimo = {}
    for a in atend:
        if a["status"] != "Realizado":
            continue
        for i in itens[a["id_atendimento"]]:
            chave = (a["id_paciente"], i["id_procedimento"])
            if chave not in ultimo or a["data_hora"] > ultimo[chave]["data_hora"]:
                ultimo[chave] = a
    vencidos = retornaram = pendentes = 0
    for (pac, proc), a in ultimo.items():
        if procs[proc] is None or pac not in ativos:
            continue
        if unidade and a["id_unidade"] != unidade:
            continue
        if procedimento and proc != procedimento:
            continue
        d = a["data_hora"].date()
        if d + timedelta(days=procs[proc]) < date.today():
            vencidos += 1
            voltou = any(b["id_paciente"] == pac and b["status"] in ("Agendado", "Realizado")
                         and b["data_hora"].date() > d for b in atend)
            retornaram += voltou
            pendentes += not voltou
    return dict(
        faturamento=faturamento.quantize(D2),
        por_unidade={u: v.quantize(D2) for u, v in fat_un.items()},
        margem=(faturamento - sum(custo.values(), Decimal(0))).quantize(D2),
        ticket=(faturamento / n).quantize(D2, ROUND_HALF_UP) if n else None,
        comparecimento=(Decimal(len(real)) / (len(real) + faltas)).quantize(Decimal("0.0001"))
        if real or faltas else None,
        retorno=(Decimal(retornaram) / vencidos).quantize(Decimal("0.0001")) if vencidos else None,
        pendentes=pendentes,
        pacientes_ativos=len(ativos),
        mensal={m: v.quantize(D2) for m, v in fat_mes.items()},
        procedimento={p: v.quantize(D2) for p, v in fat_proc.items()},
        estoque_baixo=sum(1 for _ in consultar(
            """SELECT i.id_insumo FROM insumo i WHERE i.ativo AND
               COALESCE((SELECT SUM(quantidade) FROM compra c WHERE c.id_insumo=i.id_insumo),0)
             - COALESCE((SELECT SUM(quantidade) FROM consumo c WHERE c.id_insumo=i.id_insumo),0)
               < i.estoque_minimo""")))


def q(v, casas="0.01"):
    return None if v is None else Decimal(v).quantize(Decimal(casas), ROUND_HALF_UP)


casos = []
nomes = {u["id_unidade"]: u["nome_clinica"] for u in consultar("SELECT * FROM unidade")}
procs_nome = {p["id_procedimento"]: p["nome_procedimento"] for p in
              consultar("SELECT * FROM procedimento")}
for rotulo, filtro in [("todos, ano inteiro", ("2025-10", "2026-10", None, None)),
                       ("Tatuapé, jul-set", ("2026-07", "2026-09", 2, None)),
                       ("Toxina botulínica, ano", ("2025-10", "2026-10", None, 1)),
                       ("Mogi + Skinbooster, 1º sem.", ("2026-01", "2026-06", 3, 5))]:
    d = relatorios.dashboard(S, *filtro)
    e = independente(*filtro)
    c = lambda n, a, b: casos.append((f"[{rotulo}] {n}", a, b))
    c("Faturamento total", q(d["faturamento"]), e["faturamento"])
    c("Faturamento por unidade", {n: q(v) for n, v in d["faturamento_por_unidade"] if v},
      {nomes[u]: v for u, v in e["por_unidade"].items() if v})
    c("Margem líquida", q(d["margem_liquida"]), e["margem"])
    c("Ticket médio", q(d["ticket_medio"]), e["ticket"])
    c("Taxa de comparecimento", q(d["taxa_comparecimento"], "0.0001"), e["comparecimento"])
    c("Taxa de retorno", q(d["taxa_retorno"], "0.0001"), e["retorno"])
    c("Retornos pendentes (lista)", len(d["retornos_pendentes"]), e["pendentes"])
    c("Pacientes ativos", d["pacientes_ativos"], e["pacientes_ativos"])
    c("Faturamento mensal", {m: q(v) for m, v in d["mensal"] if v},
      {m: v for m, v in e["mensal"].items() if v})
    esperado_proc = {procs_nome[p]: v for p, v in e["procedimento"].items()
                     if not filtro[3] or p == filtro[3]}
    c("Faturamento por procedimento", {n: q(v) for n, v in d["por_procedimento"]}, esperado_proc)
    c("Insumos abaixo do mínimo", len(d["estoque_alertas"]), e["estoque_baixo"])

falhas = 0
for nome, obtido, esperado in casos:
    ok = obtido == esperado
    falhas += not ok
    print(("OK   " if ok else "FALHA"), nome, "" if ok else f"(dashboard {obtido!r} x SQL {esperado!r})")
print(f"\n{len(casos) - falhas}/{len(casos)} testes passaram")
