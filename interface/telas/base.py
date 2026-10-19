"""Base das telas: estrutura comum (cabeçalho, conteúdo, rodapé fixo),
tratamento de erros e um cadastro genérico com lista e formulário.

As telas não têm regra de negócio: chamam funções de servicos/ e mostram
o resultado. Erros de negócio chegam como exceções com mensagem pronta.
"""
import traceback

import customtkinter as ctk

from interface.componentes import (AgendaSegura, BotaoPrincipal, Cabecalho, Campo, Cartao, Mensagem,
                                   RodapeFormulario, Tabela, caixa_rolagem, caixa_selecao,
                                   confirmar, entrada)
from interface.tema import Cor, Espaco, Fonte, Medida
from servicos.erros import DadosInvalidos, ErroNegocio, SessaoExpirada

FALHOU = object()   # resultado de chamar() quando o erro já foi mostrado
MSG_INESPERADO = "Ocorreu um erro inesperado. Tente novamente."


class TelaBase(AgendaSegura, ctk.CTkFrame):
    """Cabeçalho no topo, conteúdo no meio (expande) e um rodapé opcional
    fixo embaixo (botões Salvar/Cancelar nunca rolam para fora da tela)."""

    MODULO = None

    def __init__(self, master, app, titulo, subtitulo="", cabecalho=None):
        """cabecalho: usado quando a tela fica embutida em outra (numa aba);
        ela então usa o cabeçalho da tela de fora e não tem margens próprias."""
        super().__init__(master, fg_color=Cor.FUNDO, corner_radius=0)
        self.app = app
        self.sessao = app.sessao
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        embutida = cabecalho is not None
        if embutida:
            self.cabecalho = cabecalho
        else:
            self.cabecalho = Cabecalho(self, titulo, subtitulo)
            self.cabecalho.grid(row=0, column=0, sticky="ew", padx=Espaco.XXL,
                                pady=(Espaco.XXL, Espaco.L))
        self.conteudo = ctk.CTkFrame(self, fg_color="transparent")
        self.conteudo.grid_columnconfigure(0, weight=1)
        self.conteudo.grid(row=1, column=0, sticky="nsew",
                           padx=0 if embutida else Espaco.XXL,
                           pady=(0, 0 if embutida else Espaco.L))
        self.rodape = None
        self.mensagem = None

    def destroy(self):
        self.cancelar_agendamentos()
        super().destroy()

    # ----- estrutura -----
    def limpar(self):
        for w in self.conteudo.winfo_children():
            w.destroy()
        if self.rodape is not None:
            self.rodape.destroy()
            self.rodape = None
        self.conteudo.grid_columnconfigure(0, weight=1)
        for r in range(6):
            self.conteudo.grid_rowconfigure(r, weight=0)

    def colocar_rodape(self, rodape):
        self.rodape = rodape
        rodape.grid(row=2, column=0, sticky="ew")
        self.mensagem = rodape.mensagem

    @property
    def pode_editar(self):
        return self.sessao.pode_editar(self.MODULO)

    # ----- chamadas aos serviços -----
    def chamar(self, funcao, *args, ao_invalido=None, **kwargs):
        """Chama funcao(sessao, *args). Em erro, mostra a mensagem e devolve
        FALHOU. DadosInvalidos vai para ao_invalido(erro), se informado."""
        try:
            return funcao(self.sessao, *args, **kwargs)
        except SessaoExpirada:
            self.app.sessao_expirou()
            return FALHOU
        except DadosInvalidos as erro:
            if ao_invalido:
                ao_invalido(erro)
            else:
                self.erro(erro.mensagem)
            return FALHOU
        except ErroNegocio as erro:
            self.erro(erro.mensagem)
            return FALHOU
        except Exception:  # noqa: BLE001 - o usuário nunca vê o erro técnico
            traceback.print_exc()
            self.erro(MSG_INESPERADO)
            return FALHOU

    def erro(self, texto):
        if self.mensagem is not None and self.mensagem.winfo_exists():
            self.mensagem.erro(texto)

    def sucesso(self, texto):
        if self.mensagem is not None and self.mensagem.winfo_exists():
            self.mensagem.sucesso(texto)


class TelaCadastro(TelaBase):
    """Lista com busca, filtro de inativos, ações por linha e formulário de
    cadastro/edição na mesma tela. As subclasses descrevem os campos e
    ligam as funções do serviço."""

    TITULO = SUBTITULO = ""
    TEXTO_NOVO = "Novo"
    TITULO_NOVO = "Novo registro"
    TITULO_EDITAR = "Editar registro"
    BUSCA_DICA = "Buscar"
    VAZIO = "Nenhum registro cadastrado."
    VAZIO_BUSCA = "Nenhum registro encontrado para esta busca."
    CHAVE_ID = "id"
    COLUNAS = []            # [(título, peso, alinhamento)]
    CAMPOS = []             # [dict(chave, rotulo, largo, dica, sugestoes, opcoes, multilinha)]
    TEM_INATIVOS = True
    MSG_INATIVAR = "Inativar este registro? Ele deixa de aparecer nas listas, mas o histórico é mantido."
    MSG_SALVO_NOVO = "Cadastro realizado."
    MSG_SALVO_EDITAR = "Alterações salvas."

    def __init__(self, master, app, cabecalho=None):
        super().__init__(master, app, self.TITULO, self.SUBTITULO, cabecalho=cabecalho)
        self.busca = ""
        self.inativos = False
        self.registro = None
        self.mostrar_lista()

    # ----- ganchos para as subclasses -----
    def listar(self, busca, inativos):
        raise NotImplementedError

    def linha(self, r):
        raise NotImplementedError

    def para_form(self, r):
        return {c["chave"]: "" if r.get(c["chave"]) is None else str(r[c["chave"]])
                for c in self.CAMPOS}

    def salvar_servico(self, dados, id_):
        raise NotImplementedError

    def ativar_servico(self, id_, ativo):
        raise NotImplementedError

    def opcoes(self, chave):
        """Opções [(valor, rótulo)] de campos do tipo seletor."""
        return []

    def secao_extra(self, corpo, linha_grade):
        """Seções adicionais do formulário (abaixo dos campos)."""

    def dados_extra(self):
        return {}

    def filtros_extra(self, barra, coluna):
        """Controles adicionais na barra de ferramentas. Devolve a próxima coluna."""
        return coluna

    # ----- lista -----
    def mostrar_lista(self, aviso=""):
        self.limpar()
        self.cabecalho.trocar(self.TITULO, self.SUBTITULO)
        self.registro = None
        self.conteudo.grid_rowconfigure(2, weight=1)

        barra = ctk.CTkFrame(self.conteudo, fg_color="transparent")
        barra.grid(row=0, column=0, sticky="ew")
        self.campo_busca = entrada(barra, width=Medida.BUSCA_LARGURA,
                                   placeholder_text=self.BUSCA_DICA)
        self.campo_busca.grid(row=0, column=0, sticky="w")
        if self.busca:
            self.campo_busca.insert(0, self.busca)
        self.campo_busca.bind("<Return>", lambda _e: self.carregar())
        self.campo_busca.bind("<KeyRelease>", self._ao_digitar)
        coluna = 1
        if self.TEM_INATIVOS:
            self.var_inativos = ctk.BooleanVar(value=self.inativos)
            caixa_selecao(barra, "Mostrar inativos", self.var_inativos, self.carregar).grid(
                row=0, column=coluna, sticky="w", padx=(Espaco.L, 0))
            coluna += 1
        coluna = self.filtros_extra(barra, coluna)
        barra.grid_columnconfigure(coluna, weight=1)
        if self.pode_editar:
            BotaoPrincipal(barra, self.TEXTO_NOVO, lambda: self.mostrar_formulario()
                           ).grid(row=0, column=coluna + 1, sticky="e")

        self.mensagem = Mensagem(self.conteudo)
        self.mensagem.grid(row=1, column=0, sticky="ew", pady=Espaco.S)
        self.tabela = Tabela(self.conteudo, self.COLUNAS, self.VAZIO, acoes=self._acoes)
        self.tabela.grid(row=2, column=0, sticky="nsew")
        self._espera = None
        self.carregar()
        if aviso:
            self.sucesso(aviso)

    def _ao_digitar(self, evento):
        if evento.keysym == "Return":
            return
        if self._espera:
            self.after_cancel(self._espera)
        self._espera = self.agendar(300, self.carregar)

    def carregar(self):
        self._espera = None
        self.busca = self.campo_busca.get()
        if self.TEM_INATIVOS:
            self.inativos = self.var_inativos.get()
        self.mensagem.limpar()
        registros = self.chamar(lambda _s: self.listar(self.busca, self.inativos))
        if registros is FALHOU:
            self.tabela.preencher([], vazio="A lista não pôde ser carregada.")
            return
        self.tabela.preencher([self.linha(r) for r in registros], registros,
                              vazio=self.VAZIO_BUSCA if self.busca.strip() else self.VAZIO)

    def _acoes(self, r):
        if not self.pode_editar:
            return [("Ver", lambda: self.mostrar_formulario(r))]
        acoes = [("Editar", lambda: self.mostrar_formulario(r))]
        if "ativo" in r:
            if r["ativo"]:
                acoes.append(("Inativar", lambda: self._ativar(r, False)))
            else:
                acoes.append(("Reativar", lambda: self._ativar(r, True)))
        return acoes

    def _ativar(self, r, ativo):
        if not ativo and not confirmar(self, "Inativar", self.MSG_INATIVAR, "Inativar"):
            return
        if self.chamar(lambda _s: self.ativar_servico(r[self.CHAVE_ID], ativo)) is FALHOU:
            return
        self.carregar()
        self.sucesso("Registro reativado." if ativo else "Registro inativado.")

    # ----- formulário -----
    def mostrar_formulario(self, r=None):
        self.limpar()
        self.registro = r
        self.cabecalho.trocar(self.TITULO_EDITAR if r else self.TITULO_NOVO, "")
        self.colocar_rodape(RodapeFormulario(self, lambda: self.mostrar_lista(), self._salvar,
                                             somente_leitura=not self.pode_editar))
        self.conteudo.grid_rowconfigure(0, weight=1)
        self.montar_campos(self.conteudo, 0, r)

    def montar_campos(self, master, linha_grade, r):
        """Corpo rolável com o cartão de campos em duas colunas e as seções extras."""
        leitura = not self.pode_editar
        self.corpo = caixa_rolagem(master)
        self.corpo.grid(row=linha_grade, column=0, sticky="nsew")
        self.corpo.grid_columnconfigure(0, weight=1)

        cartao = Cartao(self.corpo)
        cartao.grid(row=0, column=0, sticky="ew")
        grade = ctk.CTkFrame(cartao, fg_color="transparent")
        grade.pack(fill="x", padx=Espaco.XL, pady=(Espaco.S, Espaco.XL))
        grade.grid_columnconfigure((0, 1), weight=1, uniform="campo")
        self.campos = {}
        linha, coluna = 0, 0
        for c in self.CAMPOS:
            largo = c.get("largo", False)
            if largo and coluna == 1:
                linha, coluna = linha + 1, 0
            opcoes = self.opcoes(c["chave"]) if c.get("opcoes") else None
            campo = Campo(grade, c["rotulo"], dica=c.get("dica", ""),
                          sugestoes=c.get("sugestoes"), opcoes=opcoes,
                          multilinha=c.get("multilinha", False))
            if largo:
                margem = (0, 0)
            elif coluna == 0:
                margem = (0, Espaco.M)
            else:
                margem = (Espaco.M, 0)
            campo.grid(row=linha, column=coluna, columnspan=2 if largo else 1, sticky="new",
                       padx=margem, pady=(Espaco.L, 0))
            self.campos[c["chave"]] = campo
            if largo or coluna == 1:
                linha, coluna = linha + 1, 0
            else:
                coluna = 1
        if r:
            for chave, valor in self.para_form(r).items():
                if chave in self.campos:
                    self.campos[chave].definir(valor)
        self.secao_extra(self.corpo, 1)
        if leitura:
            for campo in self.campos.values():
                campo.somente_leitura()
        primeiro = next(iter(self.campos.values()), None)
        if primeiro and not leitura:
            primeiro.controle.focus_set()

    def valores(self):
        return {chave: campo.valor() for chave, campo in self.campos.items()}

    def mostrar_erros(self, erro):
        erros = erro.erros
        for chave, campo in self.campos.items():
            campo.mostrar_erro(erros.get(chave, ""))
        gerais = [m for k, m in erros.items() if k not in self.campos]
        self.erro(" ".join(gerais) if gerais else "Corrija os campos destacados.")
        self.erros_extra(erros)

    def erros_extra(self, erros):
        """Para seções extras exibirem os erros delas."""

    def _salvar(self):
        dados = {**self.valores(), **self.dados_extra()}
        id_ = self.registro[self.CHAVE_ID] if self.registro else None
        for campo in self.campos.values():
            campo.mostrar_erro("")
        self.erros_extra({})
        resultado = self.chamar(lambda _s: self.salvar_servico(dados, id_),
                                ao_invalido=self.mostrar_erros)
        if resultado is FALHOU:
            return
        self.mostrar_lista(aviso=self.MSG_SALVO_EDITAR if id_ else self.MSG_SALVO_NOVO)
