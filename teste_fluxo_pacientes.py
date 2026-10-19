"""Fluxo pela interface: login, pacientes (cadastro, busca, edição,
inativação com o diálogo próprio, CPF inválido e duplicado), anamnese,
histórico e perfis. Banco zenith_teste; dados fictícios removidos ao final.
Não mexa no mouse nem no teclado enquanto roda."""
from fluxo_util import PREFIXO, Fluxo
from interface.componentes import Abas, DialogoConfirmacao
from repositorios.base import consultar
from validacoes.documentos import validar_cpf

f = Fluxo("pacientes")
NOME = f"{PREFIXO} Paciente"


def cpf_livre():
    for base in range(111222333, 111222999):
        b = [int(c) for c in str(base)]
        for t in (9, 10):
            dv = sum(d * (t + 1 - i) for i, d in enumerate(b)) * 10 % 11
            b.append(0 if dv == 10 else dv)
        cpf = "".join(map(str, b))
        if validar_cpf(cpf) and not consultar("SELECT 1 FROM paciente WHERE cpf=%s", (cpf,)):
            return cpf


try:
    # ---- login ----
    login = f.entrar("Gerente", senha="senha-errada-ficticia")
    f.ok("Senha errada: mensagem genérica",
         login.mensagem.cget("text") == "E-mail ou senha incorretos.")
    f.foto("01_login_erro")
    f.entrar("Gerente")
    f.ok("Gerente entra e vê o Início", f.j.sessao and f.j.sessao.perfil == "Gerente")
    f.foto("02_inicio")

    # ---- cadastro ----
    f.j.mostrar("pacientes")
    t = f.tela()
    f.foto("03_pacientes_lista")
    t.mostrar_formulario()
    t._salvar()
    f.passo()
    f.ok("Formulário vazio: mensagem padrão de obrigatório",
         t.campos["nome_completo"].erro.cget("text") == "O campo Nome completo é obrigatório.")
    f.foto("04_paciente_obrigatorios")
    dados = dict(nome_completo=NOME, cpf="111.111.111-11", data_nasc="10/05/1990",
                 telefone_paciente="11987654321", email_paciente="fluxo@exemplo.invalid",
                 endereco_paciente="Rua Ficticia, 100", bairro_paciente="Mooca",
                 cidade_paciente="São Paulo", cep_paciente="03047000",
                 origem_captacao="Indicação")
    for k, v in dados.items():
        t.campos[k].definir(v)
    t._salvar()
    f.passo()
    f.ok("CPF inválido recusado", t.campos["cpf"].erro.cget("text") == "CPF inválido.")
    f.foto("05_paciente_cpf_invalido")
    cpf = cpf_livre()
    t.campos["cpf"].definir(cpf)
    t._salvar()
    f.passo()
    t = f.tela()
    f.ok("Cadastrado e de volta à lista", t.mensagem.cget("text") == "Paciente cadastrado.")
    reg = consultar("SELECT * FROM paciente WHERE cpf=%s", (cpf,), um=True)
    f.ok("Gravado com CPF, telefone e CEP só com dígitos",
         reg and (reg["telefone_paciente"], reg["cep_paciente"]) == ("11987654321", "03047000"))

    # ---- busca e edição ----
    t.campo_busca.insert(0, PREFIXO)
    t.carregar()
    f.passo()
    f.ok("Busca por nome encontra o paciente", len(t.tabela._linhas) == 1)
    f.foto("06_pacientes_busca")
    t.mostrar_formulario(reg)
    f.passo()
    f.ok("Edição abre com CPF formatado",
         t.campos["cpf"].valor() == f"{cpf[:3]}.{cpf[3:6]}.{cpf[6:9]}-{cpf[9:]}")
    f.foto("07_paciente_dados")
    t.campos["cidade_paciente"].definir("Mogi das Cruzes")
    t._salvar()
    f.passo()
    t = f.tela()
    f.ok("Edição salva", consultar("SELECT cidade_paciente c FROM paciente WHERE cpf=%s",
                                   (cpf,), um=True)["c"] == "Mogi das Cruzes")

    # ---- CPF duplicado ----
    outro = consultar("SELECT cpf FROM paciente WHERE id_paciente=1", um=True)["cpf"]
    t.mostrar_formulario()
    for k, v in {**dados, "cpf": outro, "nome_completo": NOME + " Dois"}.items():
        t.campos[k].definir(v)
    t._salvar()
    f.passo()
    f.ok("CPF duplicado recusado",
         t.campos["cpf"].erro.cget("text") == "Já existe um paciente com este CPF.")
    f.foto("08_paciente_cpf_duplicado")

    # ---- inativar com o diálogo próprio (Esc cancela, Enter confirma) ----
    t.mostrar_lista()
    t = f.tela()
    registro = consultar("SELECT * FROM paciente WHERE cpf=%s", (cpf,), um=True)
    estado = {}

    def responder(tecla, foto=None):
        def agir():
            d = f.dialogo(DialogoConfirmacao)
            if d is None or not d.winfo_viewable():
                f.depois(100, agir)
                return
            estado["texto"] = [w.cget("text") for w in d.winfo_children()[0].winfo_children()
                               if type(w).__name__ == "CTkLabel"]
            estado["bloqueia"] = f.j.grab_current() is d
            if foto:
                f.foto(foto)
            d.event_generate(tecla)
        f.depois(400, agir)

    responder("<Escape>", "09_dialogo_inativar")
    t._ativar(registro, False)
    f.passo()
    f.ok("Diálogo com o texto exato", estado.get("texto", [None])[-1:] == [
        "Inativar este paciente? Ele deixa de aparecer na lista de ativos, mas o histórico "
        "é mantido."])
    f.ok("Diálogo bloqueia a janela de trás", estado.get("bloqueia"))
    f.ok("Esc cancela", consultar("SELECT ativo FROM paciente WHERE cpf=%s", (cpf,), um=True)["ativo"])
    responder("<Return>")
    t._ativar(registro, False)
    f.passo()
    f.ok("Enter inativa", not consultar("SELECT ativo FROM paciente WHERE cpf=%s",
                                        (cpf,), um=True)["ativo"])
    t.var_inativos.set(True)
    t.carregar()
    f.passo()
    f.foto("10_pacientes_inativos")
    t._ativar(registro, True)
    f.ok("Reativar", consultar("SELECT ativo FROM paciente WHERE cpf=%s", (cpf,), um=True)["ativo"])

    # ---- anamnese e histórico ----
    t.mostrar_formulario(registro, "anamnese")
    f.passo()
    f.foto("11_anamnese_lista")
    t.form_anamnese()
    f.passo()
    t._salvar_anamnese(None)
    f.passo()
    f.ok("Anamnese: queixa obrigatória",
         t.campos_an["queixa_principal"].erro.cget("text") == "O campo Queixa principal é obrigatório.")
    t.campos_an["queixa_principal"].definir("Linhas de expressão na testa (fictício)")
    t.campos_an["alergias"].definir("Nenhuma conhecida")
    f.foto("12_anamnese_form")
    t._salvar_anamnese(None)
    f.passo()
    f.ok("Anamnese salva", consultar("SELECT COUNT(*) n FROM anamnese WHERE id_paciente=%s",
                                     (registro["id_paciente"],), um=True)["n"] == 1)
    t.mostrar_formulario(consultar("SELECT * FROM paciente WHERE id_paciente=1", um=True),
                         "historico")
    f.passo()
    f.foto("13_paciente_historico")

    # ---- perfis ----
    f.j.sair()
    f.passo()
    f.entrar("Atendente")
    f.ok("Atendente: menu sem Financeiro e Dashboard",
         list(f.j.itens) == ["inicio", "pacientes", "atendimentos", "procedimentos",
                             "unidades", "insumos"])
    f.j.mostrar("pacientes")
    f.tela().mostrar_formulario(registro)
    f.passo()
    abas = next(w for w in f.tela().conteudo.winfo_children() if isinstance(w, Abas))
    f.ok("Atendente vê Dados e Histórico, mas não a aba Anamnese",
         list(abas._botoes) == ["dados", "historico"])
    f.j.sair()
    f.passo()
    f.entrar("Profissional")
    f.ok("Profissional: menu", list(f.j.itens) == ["inicio", "pacientes", "atendimentos"])
    f.foto("14_menu_profissional")
    f.j.sessao.ultimo_uso -= __import__("datetime").timedelta(minutes=31)
    f.j._verificar_sessao()
    f.passo()
    f.ok("30 min sem atividade volta ao login com aviso",
         f.j.sessao is None and "expirou" in f.j.raiz.mensagem.cget("text"))
finally:
    f.limpar([
        ("DELETE FROM anamnese WHERE id_paciente IN (SELECT id_paciente FROM paciente "
         "WHERE nome_completo LIKE %s)", (PREFIXO + "%",)),
        ("DELETE FROM paciente WHERE nome_completo LIKE %s", (PREFIXO + "%",)),
    ])
    f.j.destroy()
    print("Registros de teste removidos.")
raise SystemExit(f.relatorio())
