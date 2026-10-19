"""Desenha como tabela (PNG) o resultado REAL dos blocos de
docs/prints_consultas.sql, para as figuras do relatório. Somente leitura.

Uso:  python prints_imagens.py [schema]      (padrão: zenith_teste)

Não são capturas do Workbench: os valores vêm direto da consulta. Só a
apresentação muda: dinheiro como R$ 1.234,56 e datas como dd/mm/aaaa. Os
demais valores saem exatamente como o MySQL devolveu (sem arredondar).
"""
import sys
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from prints_executar import executar

RAIZ = Path(__file__).resolve().parent
SAIDA = RAIZ / "docs" / "prints"
FONTES = RAIZ / "assets" / "fontes"

FUNDO, CABECALHO, TEXTO, LINHA = "#FFFFFF", "#E8DFD7", "#4A3B30", "#9C8777"
LARGURA_MAX = 1400
MARGEM, PAD_X, ALTURA_LINHA = 24, 14, 40
TAMANHO = 17

# bloco -> (arquivo, colunas monetárias)
FIGURAS = {
    1: ("fig06_contagem.png", set()),
    4: ("fig07_agenda.png", set()),
    5: ("fig08_retornos_pendentes.png", set()),
    6: ("fig09_margem_unidade.png", {"faturamento", "custo_locacao", "despesas", "margem"}),
    7: ("fig10_fat_procedimento.png", {"faturamento"}),
    8: ("fig11_comparecimento.png", set()),
    9: ("fig12_estoque.png", set()),
}


def fonte(nome, tamanho):
    caminho = FONTES / nome
    if caminho.exists():
        return ImageFont.truetype(str(caminho), tamanho)
    for alternativa in ("segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(alternativa, tamanho)
        except OSError:
            continue
    return ImageFont.load_default()


def brl(valor):
    v = Decimal(valor)
    texto = f"{abs(v):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return f"-R$ {texto}" if v < 0 else f"R$ {texto}"


def formatar(coluna, valor, monetarias):
    if valor is None:
        return "NULL"
    if coluna in monetarias:
        return brl(valor)
    if isinstance(valor, datetime):
        return valor.strftime("%d/%m/%Y %H:%M")
    if isinstance(valor, date):
        return valor.strftime("%d/%m/%Y")
    return str(valor)


def desenhar(colunas, linhas, destino, tamanho=TAMANHO):
    corpo = fonte("Montserrat-Medium.ttf", tamanho)
    negrito = fonte("Montserrat-SemiBold.ttf", tamanho)
    medir = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    larg = lambda t, f: medir.textlength(t, font=f)
    if not linhas:
        linhas_txt = [["nenhuma linha"] + [""] * (len(colunas) - 1)]
    else:
        linhas_txt = linhas
    larguras = [max([larg(c, negrito)] + [larg(l[i], corpo) for l in linhas_txt]) + 2 * PAD_X
                for i, c in enumerate(colunas)]
    total = sum(larguras) + 2 * MARGEM
    if total > LARGURA_MAX and tamanho > 11:
        return desenhar(colunas, linhas, destino, tamanho - 1)   # cabe em 1400 px
    altura_linha = ALTURA_LINHA * tamanho // TAMANHO
    largura = int(min(total, LARGURA_MAX))
    altura = 2 * MARGEM + altura_linha * (len(linhas_txt) + 1)
    img = Image.new("RGB", (largura, altura), FUNDO)
    d = ImageDraw.Draw(img)
    y = MARGEM
    d.rectangle([MARGEM, y, largura - MARGEM, y + altura_linha], fill=CABECALHO)
    x = MARGEM
    numericas = [all(isinstance(l[i], str) and _numerico(l[i]) for l in linhas_txt if l[i])
                 and bool(linhas) for i in range(len(colunas))]
    for i, c in enumerate(colunas):
        tx = x + larguras[i] - PAD_X - larg(c, negrito) if numericas[i] else x + PAD_X
        d.text((tx, y + altura_linha / 2), c, font=negrito, fill=TEXTO, anchor="lm")
        x += larguras[i]
    y += altura_linha
    d.line([MARGEM, y, largura - MARGEM, y], fill=LINHA, width=1)
    for l in linhas_txt:
        x = MARGEM
        for i, valor in enumerate(l):
            tx = x + larguras[i] - PAD_X - larg(valor, corpo) if numericas[i] else x + PAD_X
            d.text((tx, y + altura_linha / 2), valor, font=corpo, fill=TEXTO, anchor="lm")
            x += larguras[i]
        y += altura_linha
        d.line([MARGEM, y, largura - MARGEM, y], fill=LINHA, width=1)
    destino.parent.mkdir(parents=True, exist_ok=True)
    img.save(destino, dpi=(220, 220))
    return largura, altura


def _numerico(texto):
    """Número ou dinheiro (alinha à direita). '2026-07' e datas não são."""
    t = texto.strip()
    if t.startswith("-"):
        t = t[1:]
    t = t.replace("R$", "").replace(".", "").replace(",", "").strip()
    return t.isdigit()


def gerar(schema="zenith_teste"):
    resultados = executar(schema, list(FIGURAS))
    relatorio = []
    for numero, (arquivo, monetarias) in FIGURAS.items():
        titulo, colunas, linhas = resultados[numero]
        texto = [[formatar(c, v, monetarias) for c, v in zip(colunas, l)] for l in linhas]
        largura, altura = desenhar(colunas, texto, SAIDA / arquivo)
        relatorio.append((arquivo, numero, titulo, len(linhas), largura, altura))
        aviso = "  AVISO: consulta vazia ('nenhuma linha')" if not linhas else ""
        print(f"{arquivo:32s} bloco {numero:2d}  {len(linhas):3d} linha(s)  {largura}x{altura}{aviso}")
    return relatorio


if __name__ == "__main__":
    gerar(sys.argv[1] if len(sys.argv) > 1 else "zenith_teste")
