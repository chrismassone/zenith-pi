"""Tela Insumos: abas Estoque, Compras e consumos, Insumos (cadastro) e
Fornecedores."""
from datetime import date

import customtkinter as ctk

from interface.componentes import (Abas, BotaoPrincipal, BotaoSecundario, Campo, Cartao,
                                   Mensagem, RodapeFormulario, Seletor, Tabela, caixa_rolagem,
                                   caixa_selecao, entrada)
from interface.formatos import brl, formatar_data, formatar_data_hora, numero
from interface.tema import Cor, Espaco, Medida
from interface.telas.base import FALHOU, TelaBase
from interface.telas.cadastros import CadastroFornecedores, CadastroInsumos
from servicos import cadastros, estoque as srv

ABAS = [("estoque", "Estoque"), ("movimentos", "Compras e consumos"),
        ("cadastro", "Insumos"), ("fornecedores", "Fornecedores")]


class TelaInsumos(TelaBase):
    MODULO = "insumos"
    TITULO, SUBTITULO = "Insumos", "Controle de estoque, compras e validade"

    def __init__(self, master, app):
        super().__init__(master, app, self.TITULO, self.SUBTITULO)
        self.conteudo.grid_rowconfigure(1, weight=1)
        self.abas = Abas(self.conteudo, ABAS, self.trocar_aba)
        self.abas.grid(row=0, column=0, sticky="ew", pady=(0, Espaco.L))
        self.area = None
        self.busca = ""
        self.so_alertas = False
        self.ver = "compras"
        self.trocar_aba("estoque")

    # ----- infraestrutura das abas -----
    def _nova_area(self):
        if self.area is not None:
            self.area.destroy()
        if self.rodape is not None:
            self.rodape.destroy()
            self.rodape = None
        self.cabecalho.trocar(self.TITULO, self.SUBTITULO)
        self.area = ctk.CTkFrame(self.conteudo, fg_color="transparent")
        self.area.grid(row=1, column=0, sticky="nsew")
        self.area.grid_columnconfigure(0, weight=1)
        return self.area

    def trocar_aba(self, chave):
        self.abas.ativar(chave)
        if chave in ("cadastro", "fornecedores"):
            area = self._nova_area()
            area.grid_rowconfigure(0, weight=1)
            classe = CadastroInsumos if chave == "cadastro" else CadastroFornecedores
            tela = classe(area, self.app, cabecalho=self.cabecalho)
            tela.grid(row=0, column=0, sticky="nsew")
        elif chave == "estoque":
            self.mostrar_estoque()
        else:
            self.mostrar_movimentos()

    # ----- aba Estoque -----
    def mostrar_estoque(self):
        area = self._nova_area()
        area.grid_rowconfigure(2, weight=1)
        barra = ctk.CTkFrame(area, fg_color="transparent")
        barra.grid(row=0, column=0, sticky="ew")
        self.campo_busca = entrada(barra, width=Medida.BUSCA_LARGURA,
                                   placeholder_text="Buscar insumo")
        self.campo_busca.grid(row=0, column=0)
        if self.busca:
            self.campo_busca.insert(0, self.busca)
        self.campo_busca.bind("<Return>", lambda _e: self.carregar_estoque())
        self.var_alertas = ctk.BooleanVar(value=self.so_alertas)
        caixa_selecao(barra, "Só alertas: abaixo do mínimo ou vencendo em até 60 dias",
                      self.var_alertas, self.carregar_estoque).grid(row=0, column=1,
                                                                    padx=(Espaco.L, 0))
        self.mensagem = Mensagem(area)
        self.mensagem.grid(row=1, column=0, sticky="ew", pady=Espaco.S)
        self.tabela = Tabela(area, [("Insumo", 4, "w"), ("Marca", 2, "w"), ("Saldo", 1, "e"),
                                    ("Mínimo", 1, "e"), ("Próxima validade", 2, "w"),
                                    ("Situação", 2, "w")],
                             "Nenhum insumo encontrado.")
        self.tabela.grid(row=2, column=0, sticky="nsew")
        self.carregar_estoque()

    def carregar_estoque(self):
        self.busca = self.campo_busca.get()
        self.so_alertas = self.var_alertas.get()
        linhas = self.chamar(srv.estoque, self.busca, self.so_alertas)
        if linhas is FALHOU:
            self.tabela.preencher([], vazio="O estoque não pôde ser carregado.")
            return

        def situacao(r):
            avisos = []
            if r["abaixo_minimo"]:
                avisos.append("Abaixo do mínimo")
            if r["alerta_validade"]:
                avisos.append("Validade próxima ou vencida")
            return (" · ".join(avisos), Cor.ERRO) if avisos else ("OK", Cor.TEXTO_SECUNDARIO)

        self.tabela.preencher(
            [[r["nome_insumo"], r["marca"], f"{numero(r['saldo'])} {r['unidade_medida']}",
              numero(r["estoque_minimo"]), formatar_data(r["proxima_validade"]) or "—",
              situacao(r)] for r in linhas],
            vazio="Nenhum insumo em alerta." if self.so_alertas else "Nenhum insumo encontrado.")

    # ----- aba Compras e consumos -----
    def mostrar_movimentos(self, aviso=""):
        area = self._nova_area()
        area.grid_rowconfigure(2, weight=1)
        barra = ctk.CTkFrame(area, fg_color="transparent")
        barra.grid(row=0, column=0, sticky="ew")
        self.seletor_ver = Seletor(barra, [("compras", "Compras"), ("consumos", "Consumos")],
                                   vazio="Compras", comando=lambda _v: self.carregar_movimentos(),
                                   width=Medida.FILTRO_LARGURA)
        self.seletor_ver.definir(self.ver)
        self.seletor_ver.grid(row=0, column=0)
        self.campo_busca = entrada(barra, width=Medida.BUSCA_LARGURA,
                                   placeholder_text="Buscar por insumo, fornecedor ou lote")
        self.campo_busca.grid(row=0, column=1, padx=(Espaco.M, 0))
        self.campo_busca.bind("<Return>", lambda _e: self.carregar_movimentos())
        barra.grid_columnconfigure(2, weight=1)
        if self.pode_editar:
            BotaoSecundario(barra, "Consumo avulso", self.form_consumo).grid(
                row=0, column=3, padx=(0, Espaco.S))
            BotaoPrincipal(barra, "Registrar compra", self.form_compra).grid(row=0, column=4)
        self.mensagem = Mensagem(area)
        self.mensagem.grid(row=1, column=0, sticky="ew", pady=Espaco.S)
        self.tabela_mov = Cartao(area)
        self.tabela_mov.grid(row=2, column=0, sticky="nsew")
        self.carregar_movimentos()
        if aviso:
            self.sucesso(aviso)

    def carregar_movimentos(self):
        self.ver = self.seletor_ver.valor() or "compras"
        busca = self.campo_busca.get()
        for w in self.tabela_mov.winfo_children():
            w.destroy()
        self.tabela_mov.grid_columnconfigure(0, weight=1)
        self.tabela_mov.grid_rowconfigure(0, weight=1)
        if self.ver == "compras":
            tabela = Tabela(self.tabela_mov, [
                ("Data", 1, "w"), ("Insumo", 3, "w"), ("Fornecedor", 3, "w"), ("Lote", 1, "w"),
                ("Validade", 1, "w"), ("Quantidade", 1, "e"), ("Preço unitário", 1, "e")],
                "Nenhuma compra registrada.")
            linhas = self.chamar(srv.compras, busca)
            dados = [] if linhas is FALHOU else [
                [formatar_data(r["data_compra"]), r["nome_insumo"], r["razao_social"], r["lote"],
                 formatar_data(r["data_validade"]), f"{numero(r['quantidade'])} {r['unidade_medida']}",
                 brl(r["preco_unitario"])] for r in linhas]
        else:
            tabela = Tabela(self.tabela_mov, [
                ("Data e hora", 2, "w"), ("Insumo", 3, "w"), ("Quantidade", 1, "e"),
                ("Origem", 4, "w")], "Nenhum consumo registrado.")
            linhas = self.chamar(srv.consumos, busca)
            dados = [] if linhas is FALHOU else [
                [formatar_data_hora(r["data_consumo"]), r["nome_insumo"],
                 f"{numero(r['quantidade'])} {r['unidade_medida']}",
                 (f"Atendimento nº {r['id_atendimento']} · {r['paciente']}"
                  if r["id_atendimento"] else (f"Avulso: {r['observacao']}", Cor.TEXTO_SECUNDARIO))]
                for r in linhas]
        tabela.configure(border_width=0)
        tabela.grid(row=0, column=0, sticky="nsew")
        tabela.preencher(dados)

    # ----- formulários de compra e consumo avulso -----
    def _formulario(self, titulo, campos, ao_salvar):
        area = self._nova_area()
        self.cabecalho.trocar(titulo, "")
        area.grid_rowconfigure(0, weight=1)
        corpo = caixa_rolagem(area)
        corpo.grid(row=0, column=0, sticky="nsew")
        corpo.grid_columnconfigure(0, weight=1)
        cartao = Cartao(corpo)
        cartao.grid(row=0, column=0, sticky="ew")
        grade = ctk.CTkFrame(cartao, fg_color="transparent")
        grade.pack(fill="x", padx=Espaco.XL, pady=(Espaco.S, Espaco.XL))
        grade.grid_columnconfigure((0, 1), weight=1, uniform="campo")
        self.campos = {}
        linha, coluna = 0, 0
        for chave, rotulo, kwargs in campos:
            largo = kwargs.pop("largo", False)
            if largo and coluna == 1:
                linha, coluna = linha + 1, 0
            campo = Campo(grade, rotulo, **kwargs)
            if largo:
                campo.grid(row=linha, column=0, columnspan=2, sticky="new", pady=(Espaco.L, 0))
                linha += 1
            else:
                campo.grid(row=linha, column=coluna, sticky="new", pady=(Espaco.L, 0),
                           padx=(0, Espaco.M) if coluna == 0 else (Espaco.M, 0))
                linha, coluna = (linha + 1, 0) if coluna == 1 else (linha, 1)
            self.campos[chave] = campo
        self.colocar_rodape(RodapeFormulario(self, lambda: self.mostrar_movimentos(),
                                             ao_salvar))

    def _opcoes_insumos(self):
        insumos = self.chamar(cadastros.insumos_ativos)
        if insumos is FALHOU:
            return [], {}
        return ([(i["id_insumo"], f"{i['nome_insumo']} · {i['marca']} ({i['unidade_medida']})")
                 for i in insumos], {i["id_insumo"]: i for i in insumos})

    def form_compra(self):
        opcoes, _ = self._opcoes_insumos()
        fornecedores = self.chamar(cadastros.listar_fornecedores)
        forn = [] if fornecedores is FALHOU else [(f["id_fornecedor"], f["razao_social"])
                                                  for f in fornecedores]
        self._formulario("Registrar compra", [
            ("id_insumo", "Insumo", dict(opcoes=opcoes, largo=True)),
            ("id_fornecedor", "Fornecedor", dict(opcoes=forn)),
            ("data_compra", "Data da compra", dict(dica="dd/mm/aaaa")),
            ("quantidade", "Quantidade (na unidade do insumo)", dict(dica="Ex.: 100")),
            ("preco_unitario", "Preço unitário (R$)", dict(dica="Ex.: 14,50")),
            ("lote", "Lote", dict()),
            ("data_validade", "Data de validade", dict(dica="dd/mm/aaaa")),
        ], self._salvar_compra)
        self.campos["data_compra"].definir(formatar_data(date.today()))

    def _salvar_compra(self):
        dados = {k: c.valor() for k, c in self.campos.items()}
        if self.chamar(srv.registrar_compra, dados, ao_invalido=self._erros) is FALHOU:
            return
        self.mostrar_movimentos(aviso="Compra registrada. O estoque foi atualizado.")

    def form_consumo(self):
        opcoes, self._por_id = self._opcoes_insumos()
        self._formulario("Registrar consumo avulso", [
            ("id_insumo", "Insumo", dict(opcoes=opcoes, largo=True)),
            ("quantidade", "Quantidade", dict()),
            ("observacao", "Motivo (obrigatório)", dict(largo=True,
                                                         dica="Ex.: perda no preparo, descarte")),
        ], self._salvar_consumo)
        self.campos["id_insumo"].controle._comando = self._mostrar_saldo

    def _mostrar_saldo(self, id_insumo):
        if not id_insumo:
            return
        linhas = self.chamar(srv.estoque, self._por_id[id_insumo]["nome_insumo"])
        if linhas is FALHOU:
            return
        saldo = next((l for l in linhas if l["id_insumo"] == id_insumo), None)
        if saldo:
            self.campos["quantidade"].mostrar_dica(
                f"Saldo atual: {numero(saldo['saldo'])} {saldo['unidade_medida']}")

    def _salvar_consumo(self):
        dados = {k: c.valor() for k, c in self.campos.items()}
        ins = self._por_id.get(dados.get("id_insumo")) or {}
        dados.update(nome_insumo=ins.get("nome_insumo", "Insumo"),
                     unidade_medida=ins.get("unidade_medida", ""))
        if self.chamar(srv.registrar_consumo_avulso, dados, ao_invalido=self._erros) is FALHOU:
            return
        self.mostrar_movimentos(aviso="Consumo avulso registrado.")

    def _erros(self, erro):
        for chave, campo in self.campos.items():
            campo.mostrar_erro(erro.erros.get(chave, ""))
        gerais = [m for k, m in erro.erros.items() if k not in self.campos]
        self.erro(" ".join(gerais) if gerais else "Corrija os campos destacados.")
