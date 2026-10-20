"""Cores, fontes e medidas da interface. As telas não usam valores soltos."""
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
    "Montserrat-Medium.ttf",
    "Montserrat-SemiBold.ttf",
    "Montserrat-Bold.ttf",
)


class Cor:
    # superfícies
    FUNDO = "#FFFFFF"
    MENU = "#E8DFD7"
    MENU_HOVER = "#F0E9E2"
    SUPERFICIE_SUAVE = "#F4F0EC"
    BORDA_SUAVE = "#E8DFD7"
    BORDA_CAMPO = "#9C8777"     # contraste mínimo de 3:1 com o branco
    FUNDO_LOGIN = "#F4F0EC"

    # dourado: OURO para detalhes, OURO_BOTAO para botões e texto
    OURO = "#A67C4E"
    OURO_BOTAO = "#946E45"
    OURO_BOTAO_HOVER = "#7F5F3B"
    SOBRE_OURO = "#FFFFFF"

    # texto
    TEXTO = "#4A3B30"
    TEXTO_SECUNDARIO = "#6B5646"
    TEXTO_DESABILITADO = "#8A7A6C"

    # estados
    ERRO = "#9B4A4A"
    SUCESSO = "#4F6B4B"

    # gráficos
    TAUPE = "#C9BAAC"
    SERIES = ("#946E45", "#A67C4E", "#C9BAAC", "#6B5646", "#9C8777", "#7F5F3B", "#E8DFD7")


class Espaco:
    XS, S, M, L, XL, XXL, XXXL = 4, 8, 12, 16, 24, 32, 48


class Raio:
    CONTROLE = 8
    CARTAO = 12
    ITEM_MENU = 10
    CAIXA_SELECAO = 4


class Medida:
    JANELA = "1280x720"         # tamanho inicial; depois a janela é maximizada
    JANELA_MIN = (1000, 600)
    MENU_LARGURA = 248
    CONTROLE_ALTURA = 40
    LINHA_TABELA = 48

    # bordas: com zoom de 150% no Windows, 1 px fica serrilhado nos cantos
    DIVISORIA = 1
    BORDA_BOTAO = 2
    BORDA_CAMPO = 2
    BORDA_CAIXA_SELECAO = 2

    SETA_LARGURA = 16
    ROLAGEM_PASSO = 72          # pixels por giro da roda do mouse
    BOTAO_LINHA_ALTURA = 32
    BOTAO_LINHA_LARGURA = 88
    BOTAO_LARGURA_MIN = 120
    BUSCA_LARGURA = 360
    FILTRO_LARGURA = 180
    DIALOGO_LARGURA = 440
    LOGIN_LARGURA = 360
    LOGO_LOGIN = 64
    LOGO_MENU = 64
    ABA_TRACO = 2
    TRACO_LARGURA = 48
    TRACO_ALTURA = 2
    MARCADOR_MENU = (3, 24)
    RODAPE_MENU_TEXTO = 190
    TEXTO_MAX_TABELA = 40
    ITEM_LINHA_ACAO = 96
    QTD_LARGURA = 110

    GRAFICO_ALTURA = 260
    GRAFICO_DPI = 100
    GRAFICO_FONTE = 9
    GRAFICO_FONTE_PEQUENA = 8
    GRAFICO_FONTE_TITULO = 10
    GRAFICO_LINHA = 2
    GRAFICO_MARCADOR = 3
    GRAFICO_BARRA = 0.38
    GRAFICO_ROSCA = 0.38
    GRAFICO_MAX_BAIRROS = 10
    GRAFICO_FOLGA_TOPO = 1.25   # espaço acima das colunas para a legenda


class Fonte:
    """Preenchida por preparar(), depois que a janela existe."""
    display = h1 = h2 = marca = kpi = None
    corpo = corpo_bold = rotulo = pequeno = botao = None


def preparar(janela):
    """Carrega a Montserrat (ou cai para a Segoe UI) e monta as fontes."""
    for nome in ARQUIVOS_FONTES:
        caminho = PASTA_FONTES / nome
        if caminho.exists():
            ctk.FontManager.load_font(str(caminho))

    # fontes privadas do processo não aparecem em families()
    def existe(familia):
        return tkfont.Font(janela, family=familia).actual("family") == familia

    tem_montserrat = existe("Montserrat")
    if tem_montserrat:
        leve = "Montserrat Light" if existe("Montserrat Light") else "Montserrat"
        titulo = "Montserrat"
        texto = "Montserrat Medium" if existe("Montserrat Medium") else "Montserrat"
        forte = "Montserrat SemiBold" if existe("Montserrat SemiBold") else "Montserrat"
        peso_forte = "normal" if forte != "Montserrat" else "bold"
    else:
        leve = "Segoe UI Light" if existe("Segoe UI Light") else "Segoe UI"
        titulo = texto = "Segoe UI"
        forte = "Segoe UI Semibold" if existe("Segoe UI Semibold") else "Segoe UI"
        peso_forte = "normal" if forte != "Segoe UI" else "bold"

    # a Regular fica fina demais no Windows, por isso o corpo é Medium
    Fonte.display = ctk.CTkFont(family=titulo, size=30)
    Fonte.kpi = ctk.CTkFont(family=leve, size=30)
    Fonte.h1 = ctk.CTkFont(family=titulo, size=28)
    Fonte.marca = ctk.CTkFont(family=titulo, size=18)
    Fonte.h2 = ctk.CTkFont(family=forte, size=17, weight=peso_forte)
    Fonte.corpo = ctk.CTkFont(family=texto, size=14)
    Fonte.corpo_bold = ctk.CTkFont(family=forte, size=14, weight=peso_forte)
    Fonte.rotulo = ctk.CTkFont(family=forte, size=13, weight=peso_forte)
    Fonte.pequeno = ctk.CTkFont(family=texto, size=12)
    Fonte.botao = ctk.CTkFont(family=forte, size=14, weight=peso_forte)
    return tem_montserrat


def imagem(nome, largura):
    """Carrega uma imagem de assets/ mantendo a proporção."""
    img = Image.open(ASSETS / nome)
    altura = round(largura * img.height / img.width)
    return ctk.CTkImage(light_image=img, dark_image=img, size=(largura, altura))
