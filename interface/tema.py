"""Sistema visual do Zenith.

Única fonte de verdade para cores, fontes, espaçamentos e medidas.
Nenhuma outra parte do código deve conter cor ou tamanho fixo.

Os números de contraste (escala WCAG) estão ao lado de cada cor de texto
e de cada elemento de interface. Mínimos: 4,5 para texto normal e 3,0 para
texto grande e bordas de campos.
"""
from pathlib import Path
import tkinter.font as tkfont

import customtkinter as ctk
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
ASSETS = RAIZ / "assets"
PASTA_FONTES = ASSETS / "fontes"
ARQUIVOS_FONTES = (
    "Montserrat-Light.ttf",
    "Montserrat-Regular.ttf",
    "Montserrat-Bold.ttf",
)


class Cor:
    # --- Superfícies (paleta da marca) ---
    FUNDO = "#FFFFFF"                 # área de trabalho e cartões
    MENU = "#E8DFD7"                  # menu lateral (creme da marca)
    MENU_HOVER = "#F0E9E2"            # item de menu sob o mouse
    SUPERFICIE_SUAVE = "#F4F0EC"      # cabeçalho de tabela, faixas
    BORDA_SUAVE = "#E8DFD7"           # divisórias e contorno de cartões

    # --- Bordas de campos (precisam ser identificáveis: >= 3:1) ---
    BORDA_CAMPO = "#9C8777"           # 3,42 sobre branco

    # --- Dourado: dois tons, dois papéis ---
    OURO = "#A67C4E"                  # acento: linhas, marcadores (3,74 s/ branco)
    OURO_BOTAO = "#946E45"            # fundo de botão e texto dourado (4,59 s/ branco)
    OURO_BOTAO_HOVER = "#7F5F3B"      # botão pressionado/hover (5,83)
    SOBRE_OURO = "#FFFFFF"            # texto sobre o botão dourado

    # --- Texto ---
    TEXTO = "#4A3B30"                 # 10,72 s/ branco | 8,15 s/ menu
    TEXTO_SECUNDARIO = "#6B5646"      # 6,90 s/ branco | 5,24 s/ menu
    TEXTO_DESABILITADO = "#8A7A6C"    # 4,13 s/ branco (item inativo)

    # --- Estado ---
    ERRO = "#9B4A4A"                  # 6,05 s/ branco
    SUCESSO = "#4F6B4B"               # 5,94 s/ branco


class Espaco:
    """Grade de 4 pontos."""
    XS, S, M, L, XL, XXL, XXXL = 4, 8, 12, 16, 24, 32, 48


class Raio:
    CONTROLE = 8      # campos e botões
    CARTAO = 12
    ITEM_MENU = 10
    CAIXA_SELECAO = 4  # caixa "Mostrar inativos" (acrescentado na tela de Pacientes)


class Medida:
    JANELA = "1280x800"
    JANELA_MIN = (1100, 700)
    MENU_LARGURA = 248
    CONTROLE_ALTURA = 40
    LINHA_TABELA = 44
    # --- Acrescentados para a tela de Pacientes ---
    DIVISORIA = 1                 # espessura de divisórias e bordas
    BOTAO_LINHA_ALTURA = 32       # botões de ação dentro da linha da tabela (cabe em 44)
    BOTAO_LINHA_LARGURA = 88      # largura fixa para "Editar"/"Inativar"/"Reativar"
    BOTAO_LARGURA_MIN = 120       # largura mínima de botões de formulário
    BUSCA_LARGURA = 360           # campo de busca da lista
    BORDA_CAIXA_SELECAO = 2       # contorno da caixa "Mostrar inativos" (1 px some na tela)
    DIALOGO_LARGURA = 440         # largura do texto no diálogo de confirmação


class Fonte:
    """Preenchida por preparar(), depois que a janela existe."""
    display = h1 = h2 = marca = kpi = None
    corpo = corpo_bold = rotulo = pequeno = botao = None


def preparar(janela):
    """Carrega a Montserrat e monta as fontes. Retorna True se a Montserrat
    foi encontrada; senão usa a fonte do sistema como alternativa."""
    for nome in ARQUIVOS_FONTES:
        caminho = PASTA_FONTES / nome
        if caminho.exists():
            ctk.FontManager.load_font(str(caminho))

    familias = set(tkfont.families(janela))
    tem_montserrat = "Montserrat" in familias
    normal = "Montserrat" if tem_montserrat else "Segoe UI"
    if "Montserrat Light" in familias:
        leve = "Montserrat Light"
    elif "Segoe UI Light" in familias:
        leve = "Segoe UI Light"
    else:
        leve = normal

    # Escala tipográfica (pontos). Títulos leves, rótulos em negrito.
    Fonte.display = ctk.CTkFont(family=leve, size=30)
    Fonte.kpi = ctk.CTkFont(family=leve, size=34)
    Fonte.h1 = ctk.CTkFont(family=leve, size=22)
    Fonte.marca = ctk.CTkFont(family=leve, size=15)
    Fonte.h2 = ctk.CTkFont(family=normal, size=14, weight="bold")
    Fonte.corpo = ctk.CTkFont(family=normal, size=11)
    Fonte.corpo_bold = ctk.CTkFont(family=normal, size=11, weight="bold")
    Fonte.rotulo = ctk.CTkFont(family=normal, size=10, weight="bold")
    Fonte.pequeno = ctk.CTkFont(family=normal, size=9)
    Fonte.botao = ctk.CTkFont(family=normal, size=11, weight="bold")
    return tem_montserrat


def imagem(nome, largura):
    """Carrega uma imagem de assets/ mantendo a proporção."""
    img = Image.open(ASSETS / nome)
    altura = round(largura * img.height / img.width)
    return ctk.CTkImage(light_image=img, dark_image=img, size=(largura, altura))
