"""Tela de atendimentos."""
from datetime import date
import tkinter as tk

import customtkinter as ctk

from interface.componentes import (AgendaSegura, BotaoPrincipal, BotaoSecundario, Campo, Cartao,
                                   Mensagem, RodapeFormulario, Seletor, Tabela,
                                   caixa_rolagem, entrada)
from interface.formatos import (brl, formatar_data, formatar_data_hora, formatar_hora,
                                numero)
from interface.tema import Cor, Espaco, Fonte, Medida
from interface.telas.base import FALHOU, TelaBase
from servicos import atendimentos as srv, cadastros, pacientes
from validacoes.valores import converter_data, converter_decimal

COR_STATUS = {"Realizado": Cor.SUCESSO, "Faltou": Cor.ERRO, "Cancelado": Cor.TEXTO_SECUNDARIO,
              "Agendado": Cor.TEXTO}


class TelaAtendimentos(TelaBase):
    MODULO = "atendimentos"
    TITULO, SUBTITULO = "Atendimentos", "Agenda e histórico de atendimentos"

    def __init__(self, master, app):
        super().__init__(master, app, self.TITULO, self.SUBTITULO)
        self.filtros = dict(busca="", unidade=None, status=None, de="", ate="")
        self.unidades = self.chamar(cadastros.unidades_ativas)
        if self.unidades is FALHOU:
            self.unidades = []
        self.mostrar_lista()

    # lista
    def mostrar_lista(self, aviso=""):
        self.limpar()
        self.cabecalho.trocar(self.TITULO, self.SUBTITULO)
        self.conteudo.grid_rowconfigure(2, weight=1)
        barra = ctk.CTkFrame(self.conteudo, fg_color="transparent")
        barra.grid(row=0, column=0, sticky="ew")
        f = self.filtros
        self.f_busca = entrada(barra, width=Medida.FILTRO_LARGURA,
                               placeholder_text="Buscar por paciente")
        self.f_busca.grid(row=0, column=0)
        self.f_unidade = Seletor(barra, [(u["id_unidade"], u["nome_clinica"])
                                         for u in self.unidades],
                                 vazio="Todas as unidades", width=Medida.FILTRO_LARGURA,
                                 comando=lambda _v: self.carregar())
        self.f_unidade.grid(row=0, column=1, padx=(Espaco.M, 0))
        self.f_status = Seletor(barra, [(s, s) for s in srv.STATUS], vazio="Todas as situações",
                                width=Medida.FILTRO_LARGURA, comando=lambda _v: self.carregar())
        self.f_status.grid(row=0, column=2, padx=(Espaco.M, 0))
        # período na segunda linha (não cabe tudo em 1280 px)
        self.f_de = entrada(barra, width=Medida.FILTRO_LARGURA, placeholder_text="De dd/mm/aaaa")
        self.f_de.grid(row=1, column=0, pady=(Espaco.S, 0), sticky="w")
        self.f_ate = entrada(barra, width=Medida.FILTRO_LARGURA,
                             placeholder_text="Até dd/mm/aaaa")
        self.f_ate.grid(row=1, column=1, padx=(Espaco.M, 0), pady=(Espaco.S, 0), sticky="w")
        for campo, valor in ((self.f_busca, f["busca"]), (self.f_de, f["de"]),
                             (self.f_ate, f["ate"])):
            if valor:
                campo.insert(0, valor)
            campo.bind("<Return>", lambda _e: self.carregar())
        self.f_unidade.definir(f["unidade"])
        self.f_status.definir(f["status"])
        BotaoSecundario(barra, "Filtrar", self.carregar,
                        width=Medida.BOTAO_LINHA_LARGURA).grid(row=1, column=2, sticky="w",
                                                               padx=(Espaco.M, 0),
                                                               pady=(Espaco.S, 0))
        barra.grid_columnconfigure(3, weight=1)
        if self.pode_editar:
            BotaoPrincipal(barra, "Novo atendimento", lambda: self.mostrar_formulario()
                           ).grid(row=0, column=4, sticky="e", padx=(Espaco.M, 0))
        self.mensagem = Mensagem(self.conteudo)
        self.mensagem.grid(row=1, column=0, sticky="ew", pady=Espaco.S)
        self.tabela = Tabela(self.conteudo, [
            ("Data e hora", 2, "w"), ("Paciente", 3, "w"), ("Procedimentos", 3, "w"),
            ("Unidade", 2, "w"), ("Situação", 1, "w"), ("Valor", 1, "e")],
            "Nenhum atendimento encontrado com os filtros selecionados.",
            acoes=lambda a: [("Editar" if self.pode_editar else "Ver",
                              lambda: self.mostrar_formulario(a["id_atendimento"]))])
        self.tabela.grid(row=2, column=0, sticky="nsew")
        self.carregar()
        if aviso:
            self.sucesso(aviso)

    def carregar(self):
        f = self.filtros
        f.update(busca=self.f_busca.get(), unidade=self.f_unidade.valor(),
                 status=self.f_status.valor(), de=self.f_de.get().strip(),
                 ate=self.f_ate.get().strip())
        self.mensagem.limpar()
        de, ate = converter_data(f["de"]), converter_data(f["ate"])
        if (f["de"] and not de) or (f["ate"] and not ate):
            self.erro("Período inválido. Use datas no formato dd/mm/aaaa.")
            return
        linhas = self.chamar(srv.listar, f["busca"], f["unidade"], f["status"], de, ate)
        if linhas is FALHOU:
            self.tabela.preencher([], vazio="A lista não pôde ser carregada.")
            return
        self.tabela.preencher([
            [formatar_data_hora(a["data_hora"]), a["paciente"], a["procedimentos"] or "—",
             a["nome_clinica"].replace("Unidade ", ""), (a["status"], COR_STATUS[a["status"]]),
             brl(a["valor_total"]) if a["qtd_itens"] else "—"] for a in linhas], linhas)

    # formulário
    def mostrar_formulario(self, id_atendimento=None):
        self.limpar()
        self.id_atual = id_atendimento
        a = None
        if id_atendimento:
            a = self.chamar(srv.obter, id_atendimento)
            if a is FALHOU:
                return
        editar = self.pode_editar
        self.cabecalho.trocar("Editar atendimento" if a else "Novo atendimento", "")
        self.colocar_rodape(RodapeFormulario(self, lambda: self.mostrar_lista(), self._salvar,
                                             somente_leitura=not editar))
        self.conteudo.grid_rowconfigure(0, weight=1)
        corpo = caixa_rolagem(self.conteudo)
        corpo.grid(row=0, column=0, sticky="nsew")
        corpo.grid_columnconfigure(0, weight=1)

        pacs = self.chamar(pacientes.listar)
        pacs = [] if pacs is FALHOU else pacs
        op_pac = [(p["id_paciente"], p["nome_completo"]) for p in pacs]
        if a and a["id_paciente"] not in {p for p, _ in op_pac}:
            p = self.chamar(pacientes.obter, a["id_paciente"])
            if p is not FALHOU:
                op_pac.append((p["id_paciente"], p["nome_completo"] + " (inativo)"))
        profs = self.chamar(cadastros.profissionais)
        op_prof = [] if profs is FALHOU else [(p["id_profissional"], p["nome_completo"])
                                              for p in profs]
        self.procedimentos = self.chamar(cadastros.procedimentos_ativos)
        if self.procedimentos is FALHOU:
            self.procedimentos = []

        cartao = Cartao(corpo)
        cartao.grid(row=0, column=0, sticky="ew")
        grade = ctk.CTkFrame(cartao, fg_color="transparent")
        grade.pack(fill="x", padx=Espaco.XL, pady=(Espaco.S, Espaco.XL))
        grade.grid_columnconfigure((0, 1), weight=1, uniform="campo")
        especs = [
            ("id_paciente", "Paciente", dict(opcoes=op_pac), True),
            ("id_profissional", "Profissional", dict(opcoes=op_prof), False),
            ("id_unidade", "Unidade", dict(opcoes=[(u["id_unidade"], u["nome_clinica"])
                                                   for u in self.unidades]), False),
            ("data", "Data", dict(dica="dd/mm/aaaa"), False),
            ("hora", "Hora", dict(dica="hh:mm"), False),
            ("status", "Situação", dict(opcoes=[(s, s) for s in srv.STATUS]), False),
            ("forma_pagamento", "Forma de pagamento",
             dict(opcoes=[(p, p) for p in srv.PAGAMENTOS],
                  dica="Obrigatória quando o atendimento for realizado"), False),
            ("desconto", "Desconto (R$)", dict(dica="Opcional"), False),
            ("observacao", "Observação", dict(dica="Opcional"), True),
        ]
        self.campos = {}
        linha, coluna = 0, 0
        for chave, rotulo, kw, largo in especs:
            if largo and coluna == 1:
                linha, coluna = linha + 1, 0
            campo = Campo(grade, rotulo, **kw)
            if largo:
                campo.grid(row=linha, column=0, columnspan=2, sticky="new", pady=(Espaco.L, 0))
                linha += 1
            else:
                campo.grid(row=linha, column=coluna, sticky="new", pady=(Espaco.L, 0),
                           padx=(0, Espaco.M) if coluna == 0 else (Espaco.M, 0))
                linha, coluna = (linha + 1, 0) if coluna == 1 else (linha, 1)
            self.campos[chave] = campo

        if a:
            valores = dict(id_paciente=a["id_paciente"], id_profissional=a["id_profissional"],
                           id_unidade=a["id_unidade"], data=formatar_data(a["data_hora"]),
                           hora=formatar_hora(a["data_hora"]), status=a["status"],
                           forma_pagamento=a["forma_pagamento"],
                           desconto=numero(a["desconto"]).replace(".", "")
                           if a["desconto"] else "",
                           observacao=a["observacao"] or "")
        else:
            valores = dict(status="Agendado", data=formatar_data(date.today()),
                           id_profissional=self.sessao.id_profissional
                           or (op_prof[0][0] if len(op_prof) == 1 else None))
        for chave, valor in valores.items():
            self.campos[chave].definir(valor)
        self.campos["desconto"].controle.bind("<KeyRelease>", lambda _e: self._atualizar_total())
        self.realizado_antes = bool(a and a["status"] == "Realizado")
        if a and a["qtd_consumos"]:
            self.campos["status"].mostrar_dica("Consumo de insumos já registrado.")

        # linhas de procedimento
        itens = Cartao(corpo)
        itens.grid(row=1, column=0, sticky="ew", pady=(Espaco.L, 0))
        caixa = ctk.CTkFrame(itens, fg_color="transparent")
        caixa.pack(fill="x", padx=Espaco.XL, pady=Espaco.XL)
        ctk.CTkLabel(caixa, text="Procedimentos do atendimento", font=Fonte.h2,
                     text_color=Cor.TEXTO, anchor="w").pack(fill="x", pady=(0, Espaco.M))
        cab = ctk.CTkFrame(caixa, fg_color="transparent")
        cab.pack(fill="x")
        self._colunas_item(cab)
        for col, texto in enumerate(["Procedimento", "Região de aplicação", "Quantidade",
                                     "Valor cobrado (R$)", ""]):
            ctk.CTkLabel(cab, text=texto, font=Fonte.rotulo, text_color=Cor.TEXTO,
                         anchor="w").grid(row=0, column=col, sticky="w",
                                          padx=(0 if col == 0 else Espaco.M, 0))
        self.caixa_itens = ctk.CTkFrame(caixa, fg_color="transparent")
        self.caixa_itens.pack(fill="x")
        self.linhas = []
        self.erro_itens = ctk.CTkLabel(caixa, text="", font=Fonte.pequeno, text_color=Cor.ERRO,
                                       anchor="w", justify="left")
        self.erro_itens.pack(fill="x")
        rodape_itens = ctk.CTkFrame(caixa, fg_color="transparent")
        rodape_itens.pack(fill="x", pady=(Espaco.S, 0))
        if editar:
            BotaoSecundario(rodape_itens, "Adicionar procedimento", self.nova_linha,
                            height=Medida.BOTAO_LINHA_ALTURA).pack(side="left")
        self.rotulo_total = ctk.CTkLabel(rodape_itens, text="", font=Fonte.corpo_bold,
                                         text_color=Cor.TEXTO, anchor="e")
        self.rotulo_total.pack(side="right")
        for it in (a["itens"] if a else []):
            self.nova_linha(it)
        if not self.linhas:
            self.nova_linha()
        if not editar:
            for campo in self.campos.values():
                campo.somente_leitura()
        self._atualizar_total()

    @staticmethod
    def _colunas_item(frame):
        frame.grid_columnconfigure(0, weight=3, uniform="item")
        frame.grid_columnconfigure(1, weight=2, uniform="item")
        frame.grid_columnconfigure(2, minsize=Medida.QTD_LARGURA)
        frame.grid_columnconfigure(3, minsize=Medida.QTD_LARGURA)
        frame.grid_columnconfigure(4, minsize=Medida.ITEM_LINHA_ACAO)

    def nova_linha(self, item=None):
        linha = ctk.CTkFrame(self.caixa_itens, fg_color="transparent")
        linha.pack(fill="x", pady=(Espaco.S, 0))
        self._colunas_item(linha)
        precos = {p["id_procedimento"]: p["preco_tabela"] for p in self.procedimentos}
        opcoes = [(p["id_procedimento"], p["nome_procedimento"]) for p in self.procedimentos]
        if item and item["id_procedimento"] not in precos:
            opcoes.append((item["id_procedimento"], item["nome_procedimento"]))
        valor = entrada(linha, width=Medida.QTD_LARGURA, placeholder_text="0,00")

        def escolheu(id_proc):
            if id_proc in precos:
                valor.delete(0, "end")
                valor.insert(0, numero(precos[id_proc]).replace(".", ""))
            self._atualizar_total()

        proc = Seletor(linha, opcoes, vazio="Selecione", comando=escolheu)
        proc.grid(row=0, column=0, sticky="ew")
        regiao = entrada(linha, placeholder_text="Ex.: Glabela e testa")
        regiao.grid(row=0, column=1, sticky="ew", padx=(Espaco.M, 0))
        qtd = entrada(linha, width=Medida.QTD_LARGURA, placeholder_text="Qtd.")
        qtd.grid(row=0, column=2, padx=(Espaco.M, 0))
        valor.grid(row=0, column=3, padx=(Espaco.M, 0))
        valor.bind("<KeyRelease>", lambda _e: self._atualizar_total())
        registro = dict(frame=linha, proc=proc, regiao=regiao, qtd=qtd, valor=valor)
        remover = BotaoSecundario(linha, "Remover", lambda: self._remover(registro),
                                  width=Medida.ITEM_LINHA_ACAO, height=Medida.BOTAO_LINHA_ALTURA)
        remover.grid(row=0, column=4, padx=(Espaco.M, 0))
        if item:
            proc.definir(item["id_procedimento"])
            regiao.insert(0, item["regiao_aplicada"])
            qtd.insert(0, numero(item["quantidade_aplicada"]))
            valor.insert(0, numero(item["valor_cobrado"]).replace(".", ""))
        if not self.pode_editar:
            for w in (proc, regiao, qtd, valor):
                w.configure(state="disabled")
            remover.grid_remove()
        self.linhas.append(registro)

    def _remover(self, registro):
        registro["frame"].destroy()
        self.linhas.remove(registro)
        if not self.linhas:
            self.nova_linha()
        self._atualizar_total()

    def _linhas_itens(self):
        return [dict(id_procedimento=r["proc"].valor(), regiao_aplicada=r["regiao"].get(),
                     quantidade_aplicada=r["qtd"].get(), valor_cobrado=r["valor"].get())
                for r in self.linhas]

    def _atualizar_total(self):
        soma = sum((converter_decimal(r["valor"].get()) or 0 for r in self.linhas), 0)
        desconto = converter_decimal(self.campos["desconto"].valor()) or 0
        texto = f"Subtotal {brl(soma)}"
        if desconto:
            texto += f"   Desconto {brl(desconto)}"
        texto += f"   Valor total {brl(max(soma - desconto, 0))}"
        self.rotulo_total.configure(text=texto)

    # salvar
    def _valores(self):
        return {k: c.valor() for k, c in self.campos.items()}

    def _invalido(self, erro):
        for chave, campo in self.campos.items():
            campo.mostrar_erro(erro.erros.get(chave, ""))
        self.erro_itens.configure(text=erro.erros.get("itens", ""))
        gerais = [m for k, m in erro.erros.items() if k not in self.campos and k != "itens"]
        self.erro(" ".join(gerais) if gerais else "Corrija os campos destacados.")

    def _salvar(self):
        dados, linhas = self._valores(), self._linhas_itens()
        for campo in self.campos.values():
            campo.mostrar_erro("")
        self.erro_itens.configure(text="")
        self.mensagem.limpar()
        consumos = None
        precisa = self.chamar(srv.precisa_registrar_consumo, dados.get("status"), self.id_atual)
        if precisa is FALHOU:
            return
        if precisa:
            sugestao = self.chamar(srv.sugerir_consumo, linhas, ao_invalido=self._invalido)
            if sugestao is FALHOU:
                return
            if sugestao:
                consumos = DialogoConsumo.perguntar(self, sugestao)
                if consumos is None:
                    self.erro("Atendimento não salvo: a confirmação dos insumos foi cancelada.")
                    return
            else:
                consumos = []
        r = self.chamar(srv.salvar, dados, linhas, consumos, self.id_atual,
                        ao_invalido=self._invalido)
        if r is FALHOU:
            return
        aviso = "Atendimento atualizado." if self.id_atual else "Atendimento registrado."
        if consumos:
            aviso += " Consumo de insumos registrado."
        self.mostrar_lista(aviso=aviso)


class DialogoConsumo(AgendaSegura, ctk.CTkToplevel):
    """Confirmação dos insumos usados, com a quantidade sugerida editável."""

    def __init__(self, master, sugestao):
        self.janela = master.winfo_toplevel()
        super().__init__(self.janela, fg_color=Cor.FUNDO)
        self.resultado = None
        self.sugestao = sugestao
        self.title("Insumos usados")
        self.resizable(False, False)
        self.transient(self.janela)
        corpo = ctk.CTkFrame(self, fg_color="transparent")
        corpo.pack(padx=Espaco.XL, pady=Espaco.XL, fill="both", expand=True)
        ctk.CTkLabel(corpo, text="Confirme os insumos usados", font=Fonte.h2,
                     text_color=Cor.TEXTO, anchor="w").pack(fill="x")
        ctk.CTkLabel(corpo, text=("As quantidades abaixo são sugestões do cadastro do "
                                  "procedimento. Ajuste para o que foi usado de fato; "
                                  "use 0 para um insumo que não foi usado."),
                     font=Fonte.corpo, text_color=Cor.TEXTO, anchor="w", justify="left",
                     wraplength=Medida.DIALOGO_LARGURA + Medida.BUSCA_LARGURA // 2
                     ).pack(fill="x", pady=(Espaco.S, Espaco.L))
        grade = ctk.CTkFrame(corpo, fg_color="transparent")
        grade.pack(fill="x")
        grade.grid_columnconfigure(0, weight=1)
        for col, texto in enumerate(["Insumo", "Saldo atual", "Quantidade usada"]):
            ctk.CTkLabel(grade, text=texto, font=Fonte.rotulo, text_color=Cor.TEXTO,
                         anchor="w").grid(row=0, column=col, sticky="w",
                                          padx=(0 if col == 0 else Espaco.L, 0))
        self.entradas = []
        for i, s in enumerate(sugestao, start=1):
            ctk.CTkLabel(grade, text=f"{s['nome_insumo']} ({s['unidade_medida']})",
                         font=Fonte.corpo, text_color=Cor.TEXTO, anchor="w"
                         ).grid(row=i, column=0, sticky="w", pady=Espaco.XS)
            saldo_cor = Cor.ERRO if s["saldo"] < s["quantidade_sugerida"] else Cor.TEXTO_SECUNDARIO
            ctk.CTkLabel(grade, text=numero(s["saldo"]), font=Fonte.corpo, text_color=saldo_cor,
                         anchor="e").grid(row=i, column=1, sticky="e", padx=(Espaco.L, 0))
            e = entrada(grade, width=Medida.QTD_LARGURA)
            e.insert(0, numero(s["quantidade_sugerida"]))
            e.grid(row=i, column=2, padx=(Espaco.L, 0), pady=Espaco.XS)
            self.entradas.append(e)
        botoes = ctk.CTkFrame(corpo, fg_color="transparent")
        botoes.pack(anchor="e", pady=(Espaco.L, 0))
        BotaoSecundario(botoes, "Cancelar", self.cancelar).pack(side="left")
        BotaoPrincipal(botoes, "Confirmar e salvar", self.confirmar
                       ).pack(side="left", padx=(Espaco.S, 0))
        self.bind("<Return>", lambda _e: self.confirmar())
        self.bind("<Escape>", lambda _e: self.cancelar())
        self.protocol("WM_DELETE_WINDOW", self.cancelar)
        self.update_idletasks()
        j = self.janela
        x = j.winfo_rootx() + (j.winfo_width() - self.winfo_reqwidth()) // 2
        y = j.winfo_rooty() + (j.winfo_height() - self.winfo_reqheight()) // 2
        tk.Toplevel.wm_geometry(self, f"+{max(x, 0)}+{max(y, 0)}")
        self._prender()

    def _prender(self):
        try:
            self.grab_set()
            self.focus_force()
        except tk.TclError:
            self.agendar(20, self._prender)

    def confirmar(self):
        self.resultado = [dict(id_insumo=s["id_insumo"], quantidade=e.get(),
                               nome_insumo=s["nome_insumo"])
                          for s, e in zip(self.sugestao, self.entradas)]
        self._fechar()

    def cancelar(self):
        self.resultado = None
        self._fechar()

    def _fechar(self):
        self.grab_release()
        self.cancelar_agendamentos()
        self.destroy()

    @classmethod
    def perguntar(cls, master, sugestao):
        d = cls(master, sugestao)
        d.wait_window()
        return d.resultado
