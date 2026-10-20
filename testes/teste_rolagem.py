"""Roda do mouse em todas as telas: sem erro e sem acúmulo de tratadores."""
from ferramentas import banco_teste
banco_teste.usar()

import time
import tkinter
import traceback

erros_py, erros_tk = [], []
tkinter.Tk.report_callback_exception = (
    lambda self, *a: erros_py.append("".join(traceback.format_exception(*a))))

from interface.app import Janela
from servicos.sessao import Sessao

j = Janela()
j.tk.createcommand("bgerror", lambda *a: erros_tk.append(" ".join(map(str, a))))
casos = []


def passo(n=5):
    for _ in range(n):
        j.update()
        time.sleep(0.04)


def ok(nome, cond):
    casos.append((nome, bool(cond)))


def areas():
    pilha, achadas = list(j.area.winfo_children()), []
    while pilha:
        w = pilha.pop()
        if getattr(w, "_parent_canvas", None) is not None and w.winfo_ismapped():
            achadas.append(w)
        pilha.extend(w.winfo_children())
    return achadas


def girar(widget, delta, vezes=3):
    x, y = widget.winfo_rootx() + 4, widget.winfo_rooty() + 4
    for _ in range(vezes):
        widget.event_generate("<MouseWheel>", delta=delta, x=4, y=4, rootx=x, rooty=y)
        j.update()


def testar_tela(nome):
    antes_py, antes_tk = len(erros_py), len(erros_tk)
    rolou = False
    for area in areas():
        canvas = area._parent_canvas
        filhos = [w for w in area.winfo_children() if w.winfo_ismapped()]
        alvo = filhos[0] if filhos else area
        inicio = canvas.yview()[0]
        girar(alvo, -120)
        if canvas.yview()[0] > inicio:
            rolou = True
        girar(alvo, 120, vezes=10)
    sem_erro = len(erros_py) == antes_py and len(erros_tk) == antes_tk
    ok(f"{nome}: rolar sem exceção", sem_erro)
    return rolou


passo(10)
j.sessao = Sessao(dict(id_usuario=0, nome="Teste Rolagem", email="t@exemplo.invalid",
                       perfil="Gerente", id_profissional=1))
j._montar_principal()
rolaram = []
for _ in range(2):                       # duas voltas, para pegar acúmulo
    for chave in list(j.itens):
        j.mostrar(chave)
        passo()
        if testar_tela(chave):
            rolaram.append(chave)
t = j.area.winfo_children()[0]
j.mostrar("pacientes")
j.area.winfo_children()[0].mostrar_formulario()
passo()
testar_tela("formulário de paciente")
j.mostrar("atendimentos")
j.area.winfo_children()[0].mostrar_formulario(5)
passo()
testar_tela("formulário de atendimento")
j.mostrar("insumos")
ins = j.area.winfo_children()[0]
for aba in ("movimentos", "cadastro", "fornecedores"):
    ins.trocar_aba(aba)
    passo()
    testar_tela(f"insumos/{aba}")

ok("Listas longas realmente rolam (atendimentos, pacientes, dashboard)",
   {"atendimentos", "pacientes", "dashboard"} <= set(rolaram))
tratadores = [l for l in j.bind_all("<MouseWheel>").splitlines() if l.strip()]
ok(f"Um único tratador global da roda após {2 * len(j.itens) + 5} telas "
   f"(encontrados: {len(tratadores)})", len(tratadores) == 1)
shift = [l for l in j.bind_all("<KeyPress-Shift_L>").splitlines() if l.strip()]
ok(f"Nenhum tratador global de Shift acumulado (encontrados: {len(shift)})", len(shift) == 0)
ok("Janela sem tratador de roda preso (matplotlib)", not j.bind("<MouseWheel>"))
j.sair()
passo(15)
ok("Sair e voltar ao login sem erro do Tk", not erros_tk)
j.destroy()

falhas = 0
for nome, passou in casos:
    falhas += not passou
    print("OK   " if passou else "FALHA", nome)
for e in (erros_py + erros_tk)[:3]:
    print("ERRO:", e[-600:])
print(f"\n{len(casos) - falhas}/{len(casos)} testes passaram")
raise SystemExit(falhas)
