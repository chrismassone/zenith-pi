"""Tela de pacientes, com anamnese e histórico."""
import customtkinter as ctk

from interface.componentes import (Abas, BotaoPrincipal, Campo, Cartao, Mensagem,
                                   RodapeFormulario, Seletor, Tabela, caixa_rolagem)
from interface.formatos import (brl, formatar_cep, formatar_cpf, formatar_data,
                                formatar_data_hora, formatar_telefone)
from interface.tema import Cor, Espaco
from interface.telas.base import FALHOU, TelaCadastro
from servicos import cadastros, pacientes as srv

CONFIRMA_INATIVAR = ("Inativar este paciente? Ele deixa de aparecer na lista "
                     "de ativos, mas o histórico é mantido.")
COR_STATUS = {"Realizado": Cor.SUCESSO, "Faltou": Cor.ERRO, "Cancelado": Cor.TEXTO_SECUNDARIO,
              "Agendado": Cor.TEXTO}


class TelaPacientes(TelaCadastro):
    MODULO = "pacientes"
    TITULO, SUBTITULO = "Pacientes", "Cadastro e consulta dos pacientes"
    TEXTO_NOVO, TITULO_NOVO, TITULO_EDITAR = "Novo paciente", "Novo paciente", "Editar paciente"
    BUSCA_DICA = "Buscar por nome ou CPF"
    VAZIO = "Nenhum paciente cadastrado ainda. Use o botão Novo paciente para começar."
    VAZIO_BUSCA = "Nenhum paciente encontrado para esta busca."
    CHAVE_ID = "id_paciente"
    MSG_INATIVAR = CONFIRMA_INATIVAR
    MSG_SALVO_NOVO, MSG_SALVO_EDITAR = "Paciente cadastrado.", "Alterações salvas."
    COLUNAS = [("Nome", 4, "w"), ("CPF", 2, "w"), ("Telefone", 2, "w"), ("Cidade", 2, "w"),
               ("Situação", 1, "w")]
    CAMPOS = [
        dict(chave="nome_completo", rotulo="Nome completo", largo=True),
        dict(chave="cpf", rotulo="CPF", dica="000.000.000-00"),
        dict(chave="data_nasc", rotulo="Data de nascimento", dica="dd/mm/aaaa"),
        dict(chave="telefone_paciente", rotulo="Telefone", dica="(00) 00000-0000"),
        dict(chave="email_paciente", rotulo="E-mail", dica="Opcional"),
        dict(chave="endereco_paciente", rotulo="Endereço", largo=True),
        dict(chave="bairro_paciente", rotulo="Bairro"),
        dict(chave="cidade_paciente", rotulo="Cidade"),
        dict(chave="cep_paciente", rotulo="CEP", dica="00000-000"),
        dict(chave="origem_captacao", rotulo="Origem da captação",
             sugestoes=srv.ORIGENS_SUGERIDAS, dica="Escolha uma sugestão ou digite"),
    ]

    def listar(self, busca, inativos):
        return srv.listar(self.sessao, busca, inativos)

    def linha(self, r):
        situacao = ("Ativo", Cor.TEXTO) if r["ativo"] else ("Inativo", Cor.TEXTO_SECUNDARIO)
        return [r["nome_completo"], formatar_cpf(r["cpf"]),
                formatar_telefone(r["telefone_paciente"]), r["cidade_paciente"], situacao]

    def para_form(self, r):
        d = super().para_form(r)
        d.update(cpf=formatar_cpf(r["cpf"]), data_nasc=formatar_data(r["data_nasc"]),
                 telefone_paciente=formatar_telefone(r["telefone_paciente"]),
                 cep_paciente=formatar_cep(r["cep_paciente"]),
                 email_paciente=r.get("email_paciente") or "")
        return d

    def salvar_servico(self, dados, id_):
        return srv.salvar(self.sessao, dados, id_)

    def ativar_servico(self, id_, ativo):
        srv.definir_ativo(self.sessao, id_, ativo)

    def mostrar_formulario(self, r=None, aba="dados"):
        if r is None:
            return super().mostrar_formulario(None)
        self.limpar()
        self.registro = r
        self.cabecalho.trocar(r["nome_completo"], "Ficha do paciente")
        abas = [("dados", "Dados")]
        if self.sessao.pode_ver("anamnese"):
            abas.append(("anamnese", "Anamnese"))
        abas.append(("historico", "Histórico de atendimentos"))
        Abas(self.conteudo, abas, lambda c: self.mostrar_formulario(self.registro, c),
             ativa=aba).grid(row=0, column=0, sticky="ew", pady=(0, Espaco.L))
        self.conteudo.grid_rowconfigure(1, weight=1)
        if aba == "dados":
            self.colocar_rodape(RodapeFormulario(self, lambda: self.mostrar_lista(),
                                                 self._salvar,
                                                 somente_leitura=not self.pode_editar))
            self.montar_campos(self.conteudo, 1, r)
        elif aba == "anamnese":
            self.lista_anamneses()
        else:
            self.historico()

    # histórico
    def historico(self):
        self.colocar_rodape(RodapeFormulario(self, lambda: self.mostrar_lista(), None,
                                             somente_leitura=True))
        tabela = Tabela(self.conteudo, [("Data e hora", 2, "w"), ("Unidade", 2, "w"),
                                        ("Procedimentos", 4, "w"), ("Situação", 1, "w"),
                                        ("Valor", 1, "e")],
                        "Nenhum atendimento registrado para este paciente.")
        tabela.grid(row=1, column=0, sticky="nsew")
        linhas = self.chamar(srv.historico, self.registro["id_paciente"])
        if linhas is FALHOU:
            tabela.preencher([], vazio="O histórico não pôde ser carregado.")
            return
        tabela.preencher([
            [formatar_data_hora(h["data_hora"]), h["nome_clinica"].replace("Unidade ", ""),
             h["procedimentos"] or "—", (h["status"], COR_STATUS[h["status"]]),
             brl(h["valor_total"]) if h["status"] == "Realizado" else "—"]
            for h in linhas])

    # anamnese
    def lista_anamneses(self, aviso=""):
        editar = self.sessao.pode_editar("anamnese")
        self.colocar_rodape(RodapeFormulario(self, lambda: self.mostrar_lista(), None,
                                             somente_leitura=True))
        area = ctk.CTkFrame(self.conteudo, fg_color="transparent")
        area.grid(row=1, column=0, sticky="nsew")
        area.grid_columnconfigure(0, weight=1)
        area.grid_rowconfigure(1, weight=1)
        if editar:
            BotaoPrincipal(area, "Nova anamnese", lambda: self.form_anamnese()).grid(
                row=0, column=0, sticky="e", pady=(0, Espaco.M))
        tabela = Tabela(area, [("Data", 2, "w"), ("Profissional", 2, "w"),
                               ("Queixa principal", 5, "w")],
                        "Nenhuma anamnese registrada para este paciente.",
                        acoes=lambda a: [("Editar" if editar else "Ver",
                                          lambda: self.form_anamnese(a))])
        tabela.grid(row=1, column=0, sticky="nsew")
        linhas = self.chamar(srv.listar_anamneses, self.registro["id_paciente"])
        if linhas is FALHOU:
            tabela.preencher([], vazio="As anamneses não puderam ser carregadas.")
            return
        tabela.preencher([[formatar_data_hora(a["data_registro"]), a["profissional"],
                           a["queixa_principal"]] for a in linhas], linhas)
        if aviso:
            self.sucesso(aviso)

    def form_anamnese(self, a=None):
        editar = self.sessao.pode_editar("anamnese")
        for w in self.conteudo.grid_slaves(row=1):
            w.destroy()
        if self.rodape is not None:
            self.rodape.destroy()
        voltar = lambda: self.mostrar_formulario(self.registro, "anamnese")
        self.colocar_rodape(RodapeFormulario(self, voltar, lambda: self._salvar_anamnese(a),
                                             somente_leitura=not editar))
        corpo = caixa_rolagem(self.conteudo)
        corpo.grid(row=1, column=0, sticky="nsew")
        corpo.grid_columnconfigure(0, weight=1)
        cartao = Cartao(corpo)
        cartao.grid(row=0, column=0, sticky="ew")
        grade = ctk.CTkFrame(cartao, fg_color="transparent")
        grade.pack(fill="x", padx=Espaco.XL, pady=(Espaco.S, Espaco.XL))
        grade.grid_columnconfigure(0, weight=1)
        self.campos_an = {}
        linha = 0
        self.seletor_prof = None
        if a is None and not self.sessao.id_profissional:
            profs = self.chamar(cadastros.profissionais)
            opcoes = [] if profs is FALHOU else [(p["id_profissional"], p["nome_completo"])
                                                for p in profs]
            campo = Campo(grade, "Profissional responsável", opcoes=opcoes)
            campo.grid(row=linha, column=0, sticky="new", pady=(Espaco.L, 0))
            if len(opcoes) == 1:
                campo.definir(opcoes[0][0])
            self.seletor_prof = campo
            linha += 1
        for c in srv.CAMPOS_ANAMNESE:
            multi = c.chave not in ("alergias", "medicamentos_em_uso")
            campo = Campo(grade, c.rotulo, multilinha=multi,
                          dica="" if c.obrigatorio else "Opcional")
            campo.grid(row=linha, column=0, sticky="new", pady=(Espaco.L, 0))
            if a:
                campo.definir(a.get(c.chave) or "")
            if not editar:
                campo.somente_leitura()
            self.campos_an[c.chave] = campo
            linha += 1

    def _salvar_anamnese(self, a):
        dados = {k: c.valor() for k, c in self.campos_an.items()}
        prof = self.seletor_prof.valor() if self.seletor_prof else None

        def invalido(erro):
            for k, c in self.campos_an.items():
                c.mostrar_erro(erro.erros.get(k, ""))
            self.erro("Corrija os campos destacados.")

        r = self.chamar(srv.salvar_anamnese, self.registro["id_paciente"], dados,
                        a["id_anamnese"] if a else None, prof, ao_invalido=invalido)
        if r is FALHOU:
            return
        self.mostrar_formulario(self.registro, "anamnese")
        self.sucesso("Anamnese salva.")
