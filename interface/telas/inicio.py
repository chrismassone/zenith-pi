"""Tela Início: cartões com números reais e a agenda do dia."""
import customtkinter as ctk

from interface.componentes import Mensagem, Tabela, grade_kpis
from interface.formatos import formatar_hora
from interface.tema import Espaco, Fonte, Cor
from interface.telas.base import FALHOU, TelaBase
from servicos import relatorios


class TelaInicio(TelaBase):
    MODULO = "inicio"

    def __init__(self, master, app):
        super().__init__(master, app, "Início", f"Olá, {app.sessao.nome}. Visão geral do consultório")
        self.mensagem = Mensagem(self.conteudo)
        self.mensagem.grid(row=0, column=0, sticky="ew")
        r = self.chamar(relatorios.inicio)
        if r is FALHOU:
            return
        kpis = [
            ("Pacientes ativos", str(r["pacientes_ativos"]), "Cadastros não inativados"),
            ("Atendimentos hoje", str(r["atendimentos_hoje"]), "Agendados e realizados"),
            ("Atendimentos na semana", str(r["atendimentos_semana"]), "De hoje até domingo"),
            ("Retornos pendentes", str(r["retornos_pendentes"]),
             "Prazo de retorno vencido e sem novo agendamento"),
            ("Itens em alerta", str(r["itens_em_alerta"]),
             f"{r['abaixo_minimo']} abaixo do mínimo · {r['alerta_validade']} com validade próxima"),
        ]
        grade_kpis(self.conteudo, kpis, colunas=3).grid(row=1, column=0, sticky="ew")
        ctk.CTkLabel(self.conteudo, text="Agenda de hoje", font=Fonte.h2, text_color=Cor.TEXTO,
                     anchor="w").grid(row=2, column=0, sticky="ew", pady=(Espaco.XL, Espaco.M))
        self.conteudo.grid_rowconfigure(3, weight=1)
        tabela = Tabela(self.conteudo, [("Hora", 1, "w"), ("Paciente", 4, "w"),
                                        ("Unidade", 2, "w"), ("Situação", 1, "w")],
                        "Nenhum atendimento marcado para hoje.")
        tabela.grid(row=3, column=0, sticky="nsew")
        tabela.preencher([[formatar_hora(a["data_hora"]), a["paciente"],
                           a["nome_clinica"].replace("Unidade ", ""), a["status"]]
                          for a in r["agenda"]])
