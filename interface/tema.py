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
    "Montserrat-Medium.ttf",     # corpo do texto (mais legível na tela que a Regular)
    "Montserrat-SemiBold.ttf",   # rótulos, botões e destaques
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

    # --- Acrescentados para Financeiro e Dashboard ---
    TAUPE = "#C9BAAC"                 # barra de custo nos gráficos (par do OURO)
    FUNDO_LOGIN = "#F4F0EC"           # fundo atrás do cartão de login (= superfície suave)
    # Séries dos gráficos (rosca por procedimento etc.): só tons da marca,
    # do mais escuro ao mais claro, sem gradiente.
    SERIES = ("#946E45", "#A67C4E", "#C9BAAC", "#6B5646", "#9C8777", "#7F5F3B", "#E8DFD7")


class Espaco:
    """Grade de 4 pontos."""
    XS, S, M, L, XL, XXL, XXXL = 4, 8, 12, 16, 24, 32, 48


class Raio:
    CONTROLE = 8      # campos e botões
    CARTAO = 12
    ITEM_MENU = 10
    CAIXA_SELECAO = 4  # caixa "Mostrar inativos" (acrescentado na tela de Pacientes)


class Medida:
    # A janela abre maximizada na área útil da tela (sem a barra de tarefas).
    # JANELA é só o tamanho inicial antes de maximizar.
    JANELA = "1280x720"
    JANELA_MIN = (1000, 600)
    MENU_LARGURA = 248
    CONTROLE_ALTURA = 40
    LINHA_TABELA = 48             # cabe o texto de 14 px com folga
    # --- Acrescentados para a tela de Pacientes ---
    DIVISORIA = 1                 # espessura de divisórias e bordas
    BORDA_BOTAO = 2               # contorno do botão secundário: 1 px serrilha nos cantos
                                  # com zoom de 150%; 2 px fica nítido
    BORDA_CAMPO = 2               # contorno de campos e caixas de opções (nítido no zoom)
    SETA_LARGURA = 16             # seta das caixas de opções
    ROLAGEM_PASSO = 72            # pixels lógicos por giro da roda do mouse
    BOTAO_LINHA_ALTURA = 32       # botões de ação dentro da linha da tabela (cabe em 44)
    BOTAO_LINHA_LARGURA = 88      # largura fixa para "Editar"/"Inativar"/"Reativar"
    BOTAO_LARGURA_MIN = 120       # largura mínima de botões de formulário
    BUSCA_LARGURA = 360           # campo de busca da lista
    BORDA_CAIXA_SELECAO = 2       # contorno da caixa "Mostrar inativos" (1 px some na tela)
    DIALOGO_LARGURA = 440         # largura do texto no diálogo de confirmação
    # --- Acrescentados na versão 2 (telas novas) ---
    FILTRO_LARGURA = 180          # caixas de filtro (unidade, situação...)
    DATA_LARGURA = 120            # campos de data dd/mm/aaaa nos filtros
    LOGIN_LARGURA = 360           # cartão da tela de login
    LOGO_LOGIN = 64               # monograma no login
    LOGO_MENU = 64                # monograma no menu lateral
    ABA_TRACO = 2                 # sublinhado dourado da aba ativa
    TRACO_LARGURA = 48            # traço dourado de assinatura sob os títulos
    TRACO_ALTURA = 2
    MARCADOR_MENU = (3, 24)       # barra dourada do item de menu ativo (largura, altura)
    RODAPE_MENU_TEXTO = 190       # largura do texto do rodapé do menu
    TEXTO_MAX_TABELA = 40         # caracteres antes de abreviar com "..."
    ITEM_LINHA_ACAO = 96          # coluna do botão "Remover" nas linhas de procedimento
    QTD_LARGURA = 110             # campos de quantidade e valor nas linhas
    GRAFICO_ALTURA = 260          # altura dos gráficos do dashboard
    GRAFICO_DPI = 100
    GRAFICO_FONTE = 9             # texto dos eixos (pontos)
    GRAFICO_FONTE_PEQUENA = 8     # legendas e rótulos de barras
    GRAFICO_FONTE_TITULO = 10
    GRAFICO_LINHA = 2             # espessura da linha do faturamento mensal
    GRAFICO_MARCADOR = 3
    GRAFICO_BARRA = 0.38          # largura relativa de cada coluna do par
    GRAFICO_ROSCA = 0.38          # espessura relativa do anel da rosca
    GRAFICO_MAX_BAIRROS = 10      # bairros mostrados no gráfico de pacientes
    GRAFICO_FOLGA_TOPO = 1.25     # eixo vai 25% acima da maior coluna (lugar da legenda)


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

    # Fontes carregadas só para este programa não aparecem em families();
    # por isso perguntamos ao Tk qual família ele realmente aplica.
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

    # Escala tipográfica em pixels lógicos (o CustomTkinter aplica o zoom do
    # Windows por cima), igual à do protótipo zenith_simulacao.html.
    # Corpo em Medium e destaques em SemiBold: na tela do Windows a Regular
    # fica fina demais; os títulos usam Regular (a Light some em fundo claro).
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
