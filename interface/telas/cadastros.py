"""Telas de cadastro: Unidades, Procedimentos (com insumos padrão),
Insumos e Fornecedores."""
import customtkinter as ctk

from interface.componentes import BotaoSecundario, Cartao, Seletor, entrada
from interface.formatos import (brl, formatar_cep, formatar_cnpj, formatar_telefone,
                                numero)
from interface.tema import Cor, Espaco, Fonte, Medida
from interface.telas.base import FALHOU, TelaCadastro
from servicos import cadastros as srv


def _situacao(r):
    return ("Ativo", Cor.TEXTO) if r["ativo"] else ("Inativo", Cor.TEXTO_SECUNDARIO)


# ======================================================================
class TelaUnidades(TelaCadastro):
    MODULO = "unidades"
    TITULO, SUBTITULO = "Unidades", "Locais de atendimento"
    TEXTO_NOVO, TITULO_NOVO, TITULO_EDITAR = "Nova unidade", "Nova unidade", "Editar unidade"
    BUSCA_DICA = "Buscar unidade"
    VAZIO = "Nenhuma unidade cadastrada."
    VAZIO_BUSCA = "Nenhuma unidade encontrada para esta busca."
    CHAVE_ID = "id_unidade"
    MSG_INATIVAR = ("Inativar esta unidade? Ela deixa de aparecer para novos "
                    "atendimentos, mas o histórico é mantido.")
    MSG_SALVO_NOVO, MSG_SALVO_EDITAR = "Unidade cadastrada.", "Unidade atualizada."
    COLUNAS = [("Unidade", 3, "w"), ("Bairro", 2, "w"), ("Cidade/UF", 2, "w"),
               ("Locação por dia", 2, "e"), ("Situação", 1, "w")]
    CAMPOS = [
        dict(chave="nome_clinica", rotulo="Nome da unidade", largo=True),
        dict(chave="bairro_unidade", rotulo="Bairro"),
        dict(chave="cidade_unidade", rotulo="Cidade"),
        dict(chave="uf_unidade", rotulo="UF"),
        dict(chave="valor_locacao", rotulo="Valor de locação por dia (R$)",
             dica="SUPOSIÇÃO: valor por dia com atendimento realizado."),
    ]

    def listar(self, busca, inativos):
        return srv.listar_unidades(self.sessao, busca, inativos)

    def linha(self, r):
        return [r["nome_clinica"], r["bairro_unidade"],
                f"{r['cidade_unidade']} / {r['uf_unidade']}", brl(r["valor_locacao"]),
                _situacao(r)]

    def para_form(self, r):
        d = super().para_form(r)
        d["valor_locacao"] = numero(r["valor_locacao"]).replace(".", "")
        return d

    def salvar_servico(self, dados, id_):
        return srv.salvar_unidade(self.sessao, dados, id_)

    def ativar_servico(self, id_, ativo):
        srv.ativar_unidade(self.sessao, id_, ativo)


# ======================================================================
class TelaProcedimentos(TelaCadastro):
    MODULO = "procedimentos"
    TITULO = "Procedimentos"
    SUBTITULO = "Catálogo de procedimentos, intervalos de retorno e insumos padrão"
    TEXTO_NOVO, TITULO_NOVO, TITULO_EDITAR = ("Novo procedimento", "Novo procedimento",
                                              "Editar procedimento")
    BUSCA_DICA = "Buscar procedimento"
    VAZIO = "Nenhum procedimento cadastrado."
    VAZIO_BUSCA = "Nenhum procedimento encontrado para esta busca."
    CHAVE_ID = "id_procedimento"
    MSG_INATIVAR = ("Inativar este procedimento? Ele deixa de aparecer para novos "
                    "atendimentos, mas o histórico é mantido.")
    MSG_SALVO_NOVO, MSG_SALVO_EDITAR = "Procedimento cadastrado.", "Procedimento atualizado."
    COLUNAS = [("Procedimento", 4, "w"), ("Preço de tabela", 2, "e"),
               ("Retorno", 2, "e"), ("Custo de insumos", 2, "e"), ("Situação", 1, "w")]
    CAMPOS = [
        dict(chave="nome_procedimento", rotulo="Nome do procedimento", largo=True),
        dict(chave="preco_tabela", rotulo="Preço de tabela (R$)"),
        dict(chave="intervalo_retorno_dias", rotulo="Intervalo de retorno (dias)",
             dica="Opcional"),
    ]

    def listar(self, busca, inativos):
        return srv.listar_procedimentos(self.sessao, busca, inativos)

    def linha(self, r):
        retorno = f"{r['intervalo_retorno_dias']} dias" if r["intervalo_retorno_dias"] else "—"
        return [r["nome_procedimento"], brl(r["preco_tabela"]), retorno,
                brl(r["custo_insumos"]), _situacao(r)]

    def para_form(self, r):
        d = super().para_form(r)
        d["preco_tabela"] = numero(r["preco_tabela"]).replace(".", "")
        return d

    # ----- lista de insumos padrão (editável) -----
    def secao_extra(self, corpo, linha_grade):
        r = self.registro
        self._insumos = self.chamar(srv.insumos_ativos)
        atuais = []
        if r:
            atuais = self.chamar(srv.insumos_do_procedimento, r["id_procedimento"])
        if self._insumos is FALHOU or atuais is FALHOU:
            return
        cartao = Cartao(corpo)
        cartao.grid(row=linha_grade, column=0, sticky="ew", pady=(Espaco.L, 0))
        caixa = ctk.CTkFrame(cartao, fg_color="transparent")
        caixa.pack(fill="x", padx=Espaco.XL, pady=Espaco.XL)
        ctk.CTkLabel(caixa, text="Insumos usados (quantidade padrão por procedimento)",
                     font=Fonte.h2, text_color=Cor.TEXTO, anchor="w").pack(fill="x")
        ctk.CTkLabel(caixa, text=srv.AVISO_PADRAO, font=Fonte.pequeno,
                     text_color=Cor.TEXTO_SECUNDARIO, anchor="w", justify="left"
                     ).pack(fill="x", pady=(Espaco.XS, Espaco.M))
        cab = ctk.CTkFrame(caixa, fg_color="transparent")
        cab.pack(fill="x")
        cab.grid_columnconfigure(0, weight=1)
        for col, (texto, larg) in enumerate([("Insumo", 0), ("Quantidade", Medida.QTD_LARGURA),
                                             ("", Medida.ITEM_LINHA_ACAO)]):
            ctk.CTkLabel(cab, text=texto, font=Fonte.rotulo, text_color=Cor.TEXTO, anchor="w",
                         width=larg).grid(row=0, column=col, sticky="w",
                                          padx=(0 if col == 0 else Espaco.M, 0))
        self._caixa_linhas = ctk.CTkFrame(caixa, fg_color="transparent")
        self._caixa_linhas.pack(fill="x")
        self._linhas_insumo = []
        self._erro_insumos = ctk.CTkLabel(caixa, text="", font=Fonte.pequeno,
                                          text_color=Cor.ERRO, anchor="w")
        self._erro_insumos.pack(fill="x")
        if self.pode_editar:
            BotaoSecundario(caixa, "Adicionar insumo", self._nova_linha,
                            height=Medida.BOTAO_LINHA_ALTURA).pack(anchor="w",
                                                                   pady=(Espaco.S, 0))
        for item in atuais:
            self._nova_linha(item["id_insumo"], numero(item["quantidade_padrao"]))

    def _nova_linha(self, id_insumo=None, quantidade=""):
        opcoes = [(i["id_insumo"], f"{i['nome_insumo']} ({i['unidade_medida']})")
                  for i in self._insumos]
        linha = ctk.CTkFrame(self._caixa_linhas, fg_color="transparent")
        linha.pack(fill="x", pady=(Espaco.S, 0))
        linha.grid_columnconfigure(0, weight=1)
        seletor = Seletor(linha, opcoes, vazio="Selecione o insumo")
        seletor.grid(row=0, column=0, sticky="ew")
        seletor.definir(id_insumo)
        qtd = entrada(linha, width=Medida.QTD_LARGURA, placeholder_text="Qtd.")
        qtd.grid(row=0, column=1, padx=(Espaco.M, 0))
        if quantidade:
            qtd.insert(0, quantidade)
        registro = (linha, seletor, qtd)
        remover = BotaoSecundario(linha, "Remover", lambda: self._remover_linha(registro),
                                  width=Medida.ITEM_LINHA_ACAO,
                                  height=Medida.BOTAO_LINHA_ALTURA)
        remover.grid(row=0, column=2, padx=(Espaco.M, 0))
        if not self.pode_editar:
            seletor.configure(state="disabled")
            qtd.configure(state="disabled")
            remover.grid_remove()
        self._linhas_insumo.append(registro)

    def _remover_linha(self, registro):
        registro[0].destroy()
        self._linhas_insumo.remove(registro)

    def dados_extra(self):
        return {}

    def erros_extra(self, erros):
        if hasattr(self, "_erro_insumos") and self._erro_insumos.winfo_exists():
            self._erro_insumos.configure(text=erros.get("insumos", ""))

    def salvar_servico(self, dados, id_):
        linhas = [dict(id_insumo=s.valor(), quantidade_padrao=q.get())
                  for _, s, q in getattr(self, "_linhas_insumo", [])]
        return srv.salvar_procedimento(self.sessao, dados, linhas, id_)

    def ativar_servico(self, id_, ativo):
        srv.ativar_procedimento(self.sessao, id_, ativo)


# ======================================================================
class CadastroInsumos(TelaCadastro):
    """Cadastro de insumos (aba da tela Insumos)."""
    MODULO = "insumos"
    TITULO, SUBTITULO = "Insumos", "Controle de estoque, compras e validade"
    TEXTO_NOVO, TITULO_NOVO, TITULO_EDITAR = "Novo insumo", "Novo insumo", "Editar insumo"
    BUSCA_DICA = "Buscar insumo"
    VAZIO = "Nenhum insumo cadastrado."
    VAZIO_BUSCA = "Nenhum insumo encontrado para esta busca."
    CHAVE_ID = "id_insumo"
    MSG_INATIVAR = ("Inativar este insumo? Ele deixa de aparecer no estoque e nas "
                    "sugestões, mas o histórico é mantido.")
    MSG_SALVO_NOVO, MSG_SALVO_EDITAR = "Insumo cadastrado.", "Insumo atualizado."
    COLUNAS = [("Insumo", 4, "w"), ("Marca", 2, "w"), ("Apresentação", 2, "w"),
               ("Unidade", 1, "w"), ("Mínimo", 1, "e"), ("Situação", 1, "w")]
    CAMPOS = [
        dict(chave="nome_insumo", rotulo="Nome do insumo", largo=True),
        dict(chave="marca", rotulo="Marca"),
        dict(chave="apresentacao", rotulo="Apresentação"),
        dict(chave="unidade_medida", rotulo="Unidade de medida do estoque",
             sugestoes=srv.UNIDADES_MEDIDA, dica="Ex.: U, mL, g, un, frasco"),
        dict(chave="estoque_minimo", rotulo="Estoque mínimo"),
    ]

    def listar(self, busca, inativos):
        return srv.listar_insumos(self.sessao, busca, inativos)

    def linha(self, r):
        return [r["nome_insumo"], r["marca"], r["apresentacao"], r["unidade_medida"],
                numero(r["estoque_minimo"]), _situacao(r)]

    def para_form(self, r):
        d = super().para_form(r)
        d["estoque_minimo"] = numero(r["estoque_minimo"]).replace(".", "")
        return d

    def salvar_servico(self, dados, id_):
        return srv.salvar_insumo(self.sessao, dados, id_)

    def ativar_servico(self, id_, ativo):
        srv.ativar_insumo(self.sessao, id_, ativo)


class CadastroFornecedores(TelaCadastro):
    """Cadastro de fornecedores (aba da tela Insumos)."""
    MODULO = "insumos"
    TITULO, SUBTITULO = "Insumos", "Controle de estoque, compras e validade"
    TEXTO_NOVO, TITULO_NOVO, TITULO_EDITAR = ("Novo fornecedor", "Novo fornecedor",
                                              "Editar fornecedor")
    BUSCA_DICA = "Buscar fornecedor"
    VAZIO = "Nenhum fornecedor cadastrado."
    VAZIO_BUSCA = "Nenhum fornecedor encontrado para esta busca."
    CHAVE_ID = "id_fornecedor"
    MSG_INATIVAR = ("Inativar este fornecedor? Ele deixa de aparecer para novas "
                    "compras, mas o histórico é mantido.")
    MSG_SALVO_NOVO, MSG_SALVO_EDITAR = "Fornecedor cadastrado.", "Fornecedor atualizado."
    COLUNAS = [("Razão social", 4, "w"), ("CNPJ", 2, "w"), ("Telefone", 2, "w"),
               ("Cidade", 2, "w"), ("Situação", 1, "w")]
    CAMPOS = [
        dict(chave="razao_social", rotulo="Razão social", largo=True),
        dict(chave="cnpj", rotulo="CNPJ", dica="00.000.000/0000-00"),
        dict(chave="telefone_fornecedor", rotulo="Telefone", dica="(00) 0000-0000"),
        dict(chave="cep_fornecedor", rotulo="CEP", dica="00000-000"),
        dict(chave="endereco_fornecedor", rotulo="Endereço"),
        dict(chave="bairro_fornecedor", rotulo="Bairro"),
        dict(chave="cidade_fornecedor", rotulo="Cidade"),
    ]

    def listar(self, busca, inativos):
        return srv.listar_fornecedores(self.sessao, busca, inativos)

    def linha(self, r):
        return [r["razao_social"], formatar_cnpj(r["cnpj"]),
                formatar_telefone(r["telefone_fornecedor"]), r["cidade_fornecedor"],
                _situacao(r)]

    def para_form(self, r):
        d = super().para_form(r)
        d["cnpj"] = formatar_cnpj(r["cnpj"])
        d["telefone_fornecedor"] = formatar_telefone(r["telefone_fornecedor"])
        d["cep_fornecedor"] = formatar_cep(r["cep_fornecedor"])
        return d

    def salvar_servico(self, dados, id_):
        return srv.salvar_fornecedor(self.sessao, dados, id_)

    def ativar_servico(self, id_, ativo):
        srv.ativar_fornecedor(self.sessao, id_, ativo)
