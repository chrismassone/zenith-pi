"""Regra do saldo no repositório, sem depender de gatilho (zenith_teste)."""
from ferramentas import banco_teste
banco_teste.usar()

import threading
from datetime import datetime
from decimal import Decimal

from repositorios import estoque as repo
from repositorios.base import RegraDoBanco, consultar, transacao

casos = []
criados = []


def caso(nome, obtido, esperado):
    casos.append((nome, obtido, esperado))


def saldo(id_insumo):
    return consultar("SELECT saldo FROM vw_estoque_atual WHERE id_insumo = %s",
                     (id_insumo,), um=True)["saldo"]


def consumos_teste():
    return consultar("SELECT COUNT(*) n FROM consumo WHERE observacao = 'Teste de saldo'",
                     um=True)["n"]


gaze = consultar("SELECT id_insumo FROM insumo WHERE nome_insumo = 'Gaze estéril'",
                 um=True)["id_insumo"]
try:
    s0 = saldo(gaze)

    # 1. conferência dentro da transação, antes de qualquer INSERT
    try:
        with transacao() as cur:
            repo.travar_saldo(cur, [(gaze, s0 + 1)])
        recusou = False
    except RegraDoBanco:
        recusou = True
    caso("Consumo acima do saldo recusado na transação", recusou, True)

    # 2. mesmo chamando o repositório direto (sem a conferência do serviço)
    try:
        criados.append(repo.inserir_consumo_avulso(gaze, s0 + 1, datetime.now(), "Teste de saldo"))
        recusou = False
    except RegraDoBanco:
        recusou = True
    caso("Repositório recusa consumo avulso acima do saldo", recusou, True)
    caso("Nada gravado na recusa", consumos_teste(), 0)

    # 3. dois consumos simultâneos que, juntos, passam do saldo: só um entra
    largada = threading.Barrier(2)
    resultados = []

    def consumir():
        largada.wait()
        try:
            resultados.append(repo.inserir_consumo_avulso(gaze, s0, datetime.now(),
                                                          "Teste de saldo"))
        except RegraDoBanco:
            resultados.append(None)

    linhas = [threading.Thread(target=consumir) for _ in range(2)]
    for th in linhas:
        th.start()
    for th in linhas:
        th.join()
    criados.extend(r for r in resultados if r)
    caso("Simultâneos: só um consumo gravado", sum(1 for r in resultados if r), 1)
    caso("Saldo nunca fica negativo", saldo(gaze) >= 0, True)
    caso("Saldo zerado pelo consumo aceito", saldo(gaze), Decimal("0.00"))
finally:
    with transacao() as cur:
        for i in criados:
            cur.execute("DELETE FROM consumo WHERE id_consumo = %s", (i,))
    print("Registros de teste removidos.")

falhas = 0
for nome, obtido, esperado in casos:
    ok = obtido == esperado
    falhas += not ok
    print(("OK   " if ok else "FALHA"), nome, "" if ok else f"(obtido {obtido!r})")
print(f"\n{len(casos) - falhas}/{len(casos)} testes passaram")
