"""Tela de Pacientes: lista com busca e filtro, cadastro e edição.

Toda leitura e gravação passa por repositorios.paciente; aqui não há SQL."""
import customtkinter as ctk

from interface.componentes import (Cartao, BotaoPrincipal, BotaoSecundario,
                                   Divisoria, Mensagem, Campo, entrada, confirmar)
from interface.formatos import (CAMPOS, SUGESTOES_ORIGEM, formatar_cpf,
                                formatar_telefone, formatar_cep, formatar_data,
                                montar_dados, distribuir_erros)
from interface.tema import Cor, Espaco, Raio, Medida, Fonte
from repositorios import paciente as repo

ERRO_BANCO = ("Não foi possível acessar o banco de dados. "
              "Verifique se o MySQL está ligado e tente novamente.")
CONFIRMA_INATIVAR = ("Inativar este paciente? Ele deixa de aparecer na lista "
                     "de ativos, mas o histórico é mantido.")
ESPERA_BUSCA_MS = 300   # aguarda o usuário parar de digitar antes de buscar
MAX_NOME_TABELA = 40    # nomes maiores são abreviados na tabela (não no cadastro)
MAX_CIDADE_TABELA = 22

# (título, peso da coluna)
COLUNAS = [("Nome", 4), ("CPF", 2), ("Telefone", 2), ("Cidade", 2),
           ("Situação", 1), ("", 0)]

# Posição de cada campo no formulário: (linha, coluna, ocupa_duas_colunas)
POSICAO = {
    "nome_completo": (0, 0, True),
    "cpf": (1, 0, False), "data_nasc": (1, 1, False),
    "telefone_paciente": (2, 0, False), "email_paciente": (2, 1, False),
    "endereco_paciente": (3, 0, True),
    "bairro_paciente": (4, 0, False), "cidade_paciente": (4, 1, False),
    "cep_paciente": (5, 0, False), "origem_captacao": (5, 1, False),
}
DICAS = {
    "cpf": "000.000.000-00",
    "data_nasc": "dd/mm/aaaa",
    "telefone_paciente": "(00) 00000-0000",
    "cep_paciente": "00000-000",
    "email_paciente": "Opcional",
}


def _abreviar(texto, limite):
    texto = texto or ""
    return texto if len(texto) <= limite else texto[:limite - 3].rstrip() + "..."


class TelaPacientes(ctk.CTkFrame):
    def __init__(self, master):
        super().__init__(master, fg_color="transparent")
        self.busca = ""
        self.mostrar_inativos = False
        self._espera = None
        self.mostrar_lista()

    def _limpar(self):
        for w in self.winfo_children():
            w.destroy()

    # ================= LISTA =================
    def mostrar_lista(self, aviso=""):
        self._limpar()
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)

        barra = ctk.CTkFrame(self, fg_color="transparent")
        barra.grid(row=0, column=0, sticky="ew")
        barra.grid_columnconfigure(2, weight=1)

        self.campo_busca = entrada(barra, width=Medida.BUSCA_LARGURA,
                                   placeholder_text="Buscar por nome ou CPF")
        self.campo_busca.grid(row=0, column=0, sticky="w")
        if self.busca:
            self.campo_busca.insert(0, self.busca)
        self.campo_busca.bind("<KeyRelease>", self._ao_digitar)
        self.campo_busca.bind("<Return>", lambda _e: self.carregar())

        self.var_inativos = ctk.BooleanVar(value=self.mostrar_inativos)
        ctk.CTkCheckBox(
            barra, text="Mostrar inativos", variable=self.var_inativos,
            command=self.carregar, font=Fonte.corpo, text_color=Cor.TEXTO,
            fg_color=Cor.OURO_BOTAO, hover_color=Cor.OURO_BOTAO_HOVER,
            border_color=Cor.BORDA_CAMPO, checkmark_color=Cor.SOBRE_OURO,
            border_width=Medida.BORDA_CAIXA_SELECAO, corner_radius=Raio.CAIXA_SELECAO,
        ).grid(row=0, column=1, sticky="w", padx=(Espaco.L, 0))

        BotaoPrincipal(barra, "Novo paciente", lambda: self.mostrar_formulario()
                       ).grid(row=0, column=3, sticky="e")

        self.mensagem = Mensagem(self)
        self.mensagem.grid(row=1, column=0, sticky="ew", pady=Espaco.S)

        cartao = Cartao(self)
        cartao.grid(row=2, column=0, sticky="nsew")
        cartao.grid_columnconfigure(0, weight=1)
        cartao.grid_rowconfigure(0, weight=1)
        self.tabela = ctk.CTkScrollableFrame(
            cartao, fg_color=Cor.FUNDO, corner_radius=0,
            scrollbar_button_color=Cor.BORDA_SUAVE,
            scrollbar_button_hover_color=Cor.BORDA_CAMPO)
        # deixa a borda de 1 px do cartão visível em volta da tabela
        self.tabela.grid(row=0, column=0, sticky="nsew",
                         padx=Raio.CARTAO // 2, pady=Raio.CARTAO // 2)

        self.carregar()
        if aviso:
            self.mensagem.sucesso(aviso)

    def _ao_digitar(self, evento):
        if evento.keysym == "Return":
            return
        if self._espera:
            self.after_cancel(self._espera)
        self._espera = self.after(ESPERA_BUSCA_MS, self.carregar)

    def carregar(self):
        self._espera = None
        self.busca = self.campo_busca.get()
        self.mostrar_inativos = self.var_inativos.get()
        self.mensagem.limpar()
        for w in self.tabela.winfo_children():
            w.destroy()

        try:
            pacientes = repo.listar(self.busca, incluir_inativos=self.mostrar_inativos)
        except (ConnectionError, RuntimeError):
            self.mensagem.erro(ERRO_BANCO)
            self._estado_vazio("A lista não pôde ser carregada.")
            return

        if not pacientes:
            if self.busca.strip():
                texto = "Nenhum paciente encontrado para esta busca."
            else:
                texto = ("Nenhum paciente cadastrado ainda. "
                         "Use o botão Novo paciente para começar.")
            self._estado_vazio(texto)
            return
        self._montar_tabela(pacientes)

    def _estado_vazio(self, texto):
        self.tabela.grid_columnconfigure(0, weight=1)
        ctk.CTkLabel(self.tabela, text=texto, font=Fonte.corpo,
                     text_color=Cor.TEXTO_SECUNDARIO
                     ).grid(row=0, column=0, columnspan=len(COLUNAS),
                            pady=Espaco.XXXL)

    def _montar_tabela(self, pacientes):
        t = self.tabela
        ultima = len(COLUNAS) - 1
        for c, (_, peso) in enumerate(COLUNAS):
            t.grid_columnconfigure(c, weight=peso)

        def celula(linha, coluna, texto, fonte, cor, fundo):
            ctk.CTkLabel(t, text=texto, font=fonte, text_color=cor, anchor="w",
                         fg_color=fundo).grid(
                row=linha, column=coluna, sticky="ew",
                padx=(Espaco.L, Espaco.L if coluna == ultima else 0))

        # cabeçalho: faixa de fundo + títulos
        t.grid_rowconfigure(0, minsize=Medida.LINHA_TABELA)
        ctk.CTkFrame(t, fg_color=Cor.SUPERFICIE_SUAVE, corner_radius=0,
                     height=Medida.LINHA_TABELA).grid(row=0, column=0, columnspan=len(COLUNAS), sticky="nsew")
        for c, (titulo, _) in enumerate(COLUNAS):
            celula(0, c, titulo, Fonte.rotulo, Cor.TEXTO, Cor.SUPERFICIE_SUAVE)

        for i, p in enumerate(pacientes):
            linha = 2 * i + 2
            if i > 0:
                Divisoria(t).grid(row=linha - 1, column=0,
                                  columnspan=len(COLUNAS), sticky="ew")
            t.grid_rowconfigure(linha, minsize=Medida.LINHA_TABELA)
            ativo = bool(p["ativo"])
            valores = [
                _abreviar(p["nome_completo"], MAX_NOME_TABELA),
                formatar_cpf(p["cpf"]),
                formatar_telefone(p["telefone_paciente"]),
                _abreviar(p["cidade_paciente"], MAX_CIDADE_TABELA),
            ]
            for c, texto in enumerate(valores):
                celula(linha, c, texto, Fonte.corpo, Cor.TEXTO, Cor.FUNDO)
            celula(linha, 4, "Ativo" if ativo else "Inativo", Fonte.corpo,
                   Cor.TEXTO if ativo else Cor.TEXTO_SECUNDARIO, Cor.FUNDO)

            acoes = ctk.CTkFrame(t, fg_color="transparent")
            acoes.grid(row=linha, column=ultima, sticky="e",
                       padx=(Espaco.L, Espaco.L))
            tamanho = dict(height=Medida.BOTAO_LINHA_ALTURA,
                           width=Medida.BOTAO_LINHA_LARGURA)
            BotaoSecundario(acoes, "Editar",
                            lambda p=p: self.mostrar_formulario(p), **tamanho
                            ).pack(side="left")
            if ativo:
                BotaoSecundario(acoes, "Inativar", lambda p=p: self._inativar(p),
                                **tamanho).pack(side="left", padx=(Espaco.S, 0))
            else:
                BotaoSecundario(acoes, "Reativar", lambda p=p: self._reativar(p),
                                **tamanho).pack(side="left", padx=(Espaco.S, 0))

    def _inativar(self, p):
        if not confirmar(self, "Inativar paciente", CONFIRMA_INATIVAR, "Inativar"):
            return
        try:
            repo.inativar(p["id_paciente"])
        except (ConnectionError, RuntimeError):
            self.mensagem.erro(ERRO_BANCO)
            return
        self.carregar()
        self.mensagem.sucesso("Paciente inativado.")

    def _reativar(self, p):
        try:
            repo.reativar(p["id_paciente"])
        except (ConnectionError, RuntimeError):
            self.mensagem.erro(ERRO_BANCO)
            return
        self.carregar()
        self.mensagem.sucesso("Paciente reativado.")

    # ================= FORMULÁRIO =================
    def mostrar_formulario(self, paciente=None):
        """Sem 'paciente': cadastro. Com 'paciente' (linha da lista): edição."""
        self._limpar()
        self.paciente = paciente
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)

        titulo = "Editar paciente" if paciente else "Novo paciente"
        ctk.CTkLabel(self, text=titulo, font=Fonte.h2, text_color=Cor.TEXTO,
                     anchor="w").grid(row=0, column=0, sticky="ew")
        ctk.CTkLabel(self, text="Campos sem a indicação \"Opcional\" são obrigatórios.",
                     font=Fonte.pequeno, text_color=Cor.TEXTO_SECUNDARIO,
                     anchor="w").grid(row=1, column=0, sticky="ew",
                                      pady=(Espaco.XS, Espaco.L))

        cartao = Cartao(self)
        cartao.grid(row=2, column=0, sticky="nsew")
        cartao.grid_columnconfigure(0, weight=1)
        cartao.grid_rowconfigure(0, weight=1)
        corpo = ctk.CTkScrollableFrame(
            cartao, fg_color=Cor.FUNDO, corner_radius=0,
            scrollbar_button_color=Cor.BORDA_SUAVE,
            scrollbar_button_hover_color=Cor.BORDA_CAMPO)
        corpo.grid(row=0, column=0, sticky="nsew",
                   padx=Raio.CARTAO // 2, pady=Raio.CARTAO // 2)
        corpo.grid_columnconfigure((0, 1), weight=1, uniform="campo")

        self.campos = {}
        for chave, rotulo, _ in CAMPOS:
            linha, coluna, largo = POSICAO[chave]
            campo = Campo(corpo, rotulo, dica=DICAS.get(chave, ""),
                          sugestoes=SUGESTOES_ORIGEM if chave == "origem_captacao" else None)
            esquerda = Espaco.L if coluna == 0 else Espaco.S
            direita = Espaco.L if (largo or coluna == 1) else Espaco.S
            campo.grid(row=linha, column=coluna, columnspan=2 if largo else 1,
                       sticky="new", padx=(esquerda, direita),
                       pady=(Espaco.L, 0))
            self.campos[chave] = campo
        # respiro abaixo do último campo
        ctk.CTkFrame(corpo, fg_color="transparent", height=Espaco.L
                     ).grid(row=len(POSICAO), column=0)

        if paciente:
            self._preencher(paciente)

        rodape = ctk.CTkFrame(self, fg_color="transparent")
        rodape.grid(row=3, column=0, sticky="ew", pady=(Espaco.L, 0))
        rodape.grid_columnconfigure(0, weight=1)
        self.mensagem = Mensagem(rodape)
        self.mensagem.grid(row=0, column=0, sticky="ew", padx=(0, Espaco.L))
        BotaoSecundario(rodape, "Cancelar", lambda: self.mostrar_lista()
                        ).grid(row=0, column=1, padx=(0, Espaco.S))
        BotaoPrincipal(rodape, "Salvar", self._salvar).grid(row=0, column=2)

        self.campos["nome_completo"].controle.focus_set()

    def _preencher(self, p):
        texto = {
            "nome_completo": p["nome_completo"],
            "cpf": formatar_cpf(p["cpf"]),
            "data_nasc": formatar_data(p["data_nasc"]),
            "telefone_paciente": formatar_telefone(p["telefone_paciente"]),
            "email_paciente": p.get("email_paciente") or "",
            "cep_paciente": formatar_cep(p["cep_paciente"]),
            "endereco_paciente": p["endereco_paciente"],
            "bairro_paciente": p["bairro_paciente"],
            "cidade_paciente": p["cidade_paciente"],
            "origem_captacao": p["origem_captacao"],
        }
        for chave, valor in texto.items():
            self.campos[chave].definir(valor or "")

    def _mostrar_erros(self, por_campo, gerais=()):
        for chave, campo in self.campos.items():
            campo.mostrar_erro(por_campo.get(chave, ""))
        if gerais:
            self.mensagem.erro(" ".join(gerais))
        elif por_campo:
            self.mensagem.erro("Corrija os campos destacados.")
        else:
            self.mensagem.limpar()

    def _salvar(self):
        valores = {chave: campo.valor() for chave, campo in self.campos.items()}
        dados, erros = montar_dados(valores)
        if erros:
            self._mostrar_erros(erros)
            return
        try:
            if self.paciente:
                repo.atualizar(self.paciente["id_paciente"], dados)
                aviso = "Alterações salvas."
            else:
                repo.inserir(dados)
                aviso = "Paciente cadastrado."
        except repo.DadosInvalidos as e:
            self._mostrar_erros(*distribuir_erros(e.erros))
            return
        except (ConnectionError, RuntimeError):
            self._mostrar_erros({})
            self.mensagem.erro(ERRO_BANCO)
            return
        self.mostrar_lista(aviso=aviso)
