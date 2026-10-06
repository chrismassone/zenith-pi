"""Percorre a tela de Pacientes pela própria interface, com dados fictícios,
tira capturas e remove ao final os registros criados.
Não mexa no mouse nem no teclado enquanto ele roda."""
import os, tempfile, time
from PIL import ImageGrab

from interface.app import Janela
from interface.componentes import DialogoConfirmacao
from interface.telas.pacientes import TelaPacientes
from repositorios import paciente as repo
from database.conexao import conectar

# capturas vão para a pasta temporária do Windows, fora do projeto
SAIDA = os.path.join(tempfile.gettempdir(), "zenith_capturas")
os.makedirs(SAIDA, exist_ok=True)
NOME = "Paciente Ficticio UI"
dialogos = []  # o que foi observado em cada diálogo aberto


def responder_dialogo(tecla, captura=None):
    """Agenda: quando o diálogo aparecer, confere e responde com a tecla."""
    def agir():
        d = next((w for w in j.winfo_children() if isinstance(w, DialogoConfirmacao)), None)
        if d is None or not d.winfo_viewable():
            j.after(100, agir); return
        textos = [w.cget("text") for w in d.winfo_children()[0].winfo_children()
                  if type(w).__name__ == "CTkLabel"]
        cx = d.winfo_rootx() + d.winfo_width() // 2 - (j.winfo_rootx() + j.winfo_width() // 2)
        cy = d.winfo_rooty() + d.winfo_height() // 2 - (j.winfo_rooty() + j.winfo_height() // 2)
        dialogos.append(dict(textos=textos, grab=j.grab_current() is d,
                             centro=(cx, cy), botoes=[b.cget("text") for b in
                             d.winfo_children()[0].winfo_children()[2].winfo_children()]))
        if captura:
            x, y = j.winfo_rootx(), j.winfo_rooty()
            ImageGrab.grab(bbox=(x, y, x + j.winfo_width(), y + j.winfo_height())
                           ).save(os.path.join(SAIDA, captura + ".png"))
        d.event_generate(tecla)
    j.after(500, agir)

j = Janela()
j.geometry("1280x800+0+0")


def passo():
    for _ in range(5):
        j.update(); time.sleep(0.15)


def foto(nome):
    passo()
    x, y = j.winfo_rootx(), j.winfo_rooty()
    ImageGrab.grab(bbox=(x, y, x + j.winfo_width(), y + j.winfo_height())
                   ).save(os.path.join(SAIDA, nome + ".png"))


def tela():
    return next(w for w in j.area.winfo_children() if isinstance(w, TelaPacientes))


def preencher(t, **v):
    for chave, valor in v.items():
        t.campos[chave].definir(valor)


def erros(t):
    return {k: c.erro.cget("text") for k, c in t.campos.items() if c.erro.winfo_ismapped()}


def ok(nome, cond):
    print("OK   " if cond else "FALHA", nome)


base = dict(nome_completo=NOME, cpf="111.111.111-11", data_nasc="10/05/1990",
            telefone_paciente="11987654321", email_paciente="ficticio@exemplo.com",
            cep_paciente="03047000", endereco_paciente="Rua Ficticia, 100",
            bairro_paciente="Mooca", cidade_paciente="Sao Paulo",
            origem_captacao="Indicação")
try:
    passo()
    j.mostrar("pacientes"); foto("01_lista_inicial")
    t = tela()
    t.mostrar_formulario(); foto("02_form_vazio")

    t._salvar(); passo()
    ok("Form vazio: erros por campo", len(erros(t)) >= 8)
    foto("03_form_obrigatorios")

    preencher(t, **base, ); preencher(t, data_nasc="31/02/1990"); t._salvar(); passo()
    ok("Data 31/02 recusada no formulário", "data_nasc" in erros(t))
    preencher(t, data_nasc="10/05/1990"); t._salvar(); passo()
    ok("CPF inválido recusado: " + str(erros(t)), erros(t).get("cpf") == "CPF inválido.")
    foto("04_form_cpf_invalido")

    preencher(t, cpf="52998224725"); t._salvar(); passo()
    t = tela()
    ok("Cadastrado e voltou à lista: " + t.mensagem.cget("text"),
       t.mensagem.cget("text") == "Paciente cadastrado.")
    foto("05_lista_apos_cadastro")

    t.campo_busca.insert(0, "Ficticio UI"); t.carregar(); passo()
    achados = repo.listar("Ficticio UI")
    ok("Busca por nome encontra 1", len(achados) == 1)
    foto("06_busca_nome")
    t.campo_busca.delete(0, "end"); t.campo_busca.insert(0, "529.982"); t.carregar()
    ok("Busca por CPF parcial encontra", any(p["nome_completo"] == NOME for p in repo.listar("529.982")))
    p = achados[0]
    ok("CPF/telefone/CEP gravados só com dígitos",
       (p["cpf"], p["telefone_paciente"], p["cep_paciente"]) == ("52998224725", "11987654321", "03047000"))

    t.mostrar_formulario(p); passo()
    ok("Edição pré-preenche CPF formatado", t.campos["cpf"].valor() == "529.982.247-25")
    ok("Edição pré-preenche data", t.campos["data_nasc"].valor() == "10/05/1990")
    foto("07_form_edicao")
    preencher(t, cidade_paciente="Mogi das Cruzes", origem_captacao="Evento ficticio")
    t._salvar(); passo(); t = tela()
    p2 = repo.buscar_por_id(p["id_paciente"])
    ok("Edição salva (cidade e origem livre)",
       (p2["cidade_paciente"], p2["origem_captacao"]) == ("Mogi das Cruzes", "Evento ficticio"))

    t.mostrar_formulario(); preencher(t, **{**base, "nome_completo": NOME + " Dois",
                                         "cpf": "529.982.247-25"})
    t._salvar(); passo()
    ok("CPF duplicado recusado: " + str(erros(t)),
       erros(t).get("cpf") == "Já existe um paciente com este CPF.")
    foto("08_form_cpf_duplicado")
    t.mostrar_lista(); t = tela()

    ativos = lambda: any(x["id_paciente"] == p["id_paciente"] for x in repo.listar())
    responder_dialogo("<Escape>", captura="13_dialogo_inativar")
    t._inativar(p2); passo()
    d = dialogos[-1]
    ok("Diálogo: título e texto exatos",
       d["textos"] == ["Inativar paciente", "Inativar este paciente? Ele deixa de aparecer "
                       "na lista de ativos, mas o histórico é mantido."])
    ok("Diálogo: botões Cancelar e Inativar", d["botoes"] == ["Cancelar", "Inativar"])
    ok("Diálogo bloqueia a janela de trás (grab)", d["grab"])
    ok("Diálogo centralizado: desvio " + str(d["centro"]),
       all(abs(v) <= 2 for v in d["centro"]))
    ok("Esc cancela: continua ativo", ativos())
    ok("Diálogo fechado após Esc", not any(isinstance(w, DialogoConfirmacao)
                                          for w in j.winfo_children()))
    responder_dialogo("<Return>")
    t._inativar(p2); passo()
    ok("Inativado some dos ativos", not any(x["id_paciente"] == p["id_paciente"] for x in repo.listar()))
    t.var_inativos.set(True); t.carregar(); passo()
    foto("09_lista_com_inativos")
    t._reativar(p2); passo()
    ok("Reativado volta aos ativos", any(x["id_paciente"] == p["id_paciente"] for x in repo.listar()))

    t.var_inativos.set(False); t.campo_busca.delete(0, "end")
    t.campo_busca.insert(0, "zzzz nao existe"); t.carregar(); foto("10_estado_vazio")

    j.geometry("1100x700+0+0"); t.campo_busca.delete(0, "end"); t.carregar()
    foto("11_lista_1100x700")
    t.mostrar_formulario(p2); foto("12_form_1100x700")
    t.mostrar_lista()
    print("Capturas salvas em", SAIDA)
finally:
    conn = conectar(); cur = conn.cursor()
    cur.execute("DELETE FROM paciente WHERE nome_completo LIKE %s", (NOME + "%",))
    conn.commit(); print("Registros de teste removidos:", cur.rowcount); conn.close()
    j.destroy()

