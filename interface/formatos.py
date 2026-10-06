"""Lógica pura da tela de pacientes: formatação para exibição, conversão
de data e checagens do formulário. Não importa nada gráfico, para poder
ser testada sem abrir janela (ver teste_formatos.py)."""
from datetime import date, datetime
import re

# Campos do formulário: (chave no repositório, rótulo, limite de caracteres)
# Limites iguais aos do banco (zenith_banco.sql, tabela paciente).
# Limite None = campo com formato próprio, conferido pelo repositório.
CAMPOS = [
    ("nome_completo", "Nome completo", 100),
    ("cpf", "CPF", None),
    ("data_nasc", "Data de nascimento", None),
    ("telefone_paciente", "Telefone", None),
    ("email_paciente", "E-mail", 100),
    ("cep_paciente", "CEP", None),
    ("endereco_paciente", "Endereço", 100),
    ("bairro_paciente", "Bairro", 40),
    ("cidade_paciente", "Cidade", 40),
    ("origem_captacao", "Origem da captação", 30),
]
ROTULOS = {chave: rotulo for chave, rotulo, _ in CAMPOS}
SUGESTOES_ORIGEM = ["Instagram", "Indicação"]


def _digitos(texto):
    return re.sub(r"\D", "", texto or "")


def formatar_cpf(cpf):
    """'52998224725' -> '529.982.247-25'. Fora do padrão, devolve como veio."""
    d = _digitos(cpf)
    if len(d) != 11:
        return cpf or ""
    return f"{d[:3]}.{d[3:6]}.{d[6:9]}-{d[9:]}"


def formatar_telefone(telefone):
    """Celular '11987654321' -> '(11) 98765-4321'; fixo '1133334444' ->
    '(11) 3333-4444'. Fora do padrão, devolve como veio."""
    d = _digitos(telefone)
    if len(d) == 11:
        return f"({d[:2]}) {d[2:7]}-{d[7:]}"
    if len(d) == 10:
        return f"({d[:2]}) {d[2:6]}-{d[6:]}"
    return telefone or ""


def formatar_cep(cep):
    """'03047000' -> '03047-000'. Fora do padrão, devolve como veio."""
    d = _digitos(cep)
    if len(d) != 8:
        return cep or ""
    return f"{d[:5]}-{d[5:]}"


def formatar_data(valor):
    """date -> 'dd/mm/aaaa'. None -> ''."""
    return valor.strftime("%d/%m/%Y") if isinstance(valor, date) else ""


def converter_data(texto):
    """'dd/mm/aaaa' (ou 'ddmmaaaa') -> date. Retorna None se for inválida."""
    texto = (texto or "").strip()
    if re.fullmatch(r"\d{8}", texto):
        texto = f"{texto[:2]}/{texto[2:4]}/{texto[4:]}"
    if not re.fullmatch(r"\d{2}/\d{2}/\d{4}", texto):
        return None
    try:
        return datetime.strptime(texto, "%d/%m/%Y").date()
    except ValueError:  # ex.: 31/02/2000
        return None


def montar_dados(valores):
    """Recebe os textos digitados {chave: texto} e devolve (dados, erros).

    dados: dicionário pronto para repositorios.paciente.inserir/atualizar.
    erros: {chave: mensagem} com o que o repositório não confere
    (tamanho máximo e formato da data). O resto (obrigatórios, CPF,
    telefone, CEP, e-mail, duplicidade) é conferido pelo repositório."""
    dados, erros = {}, {}
    for chave, rotulo, limite in CAMPOS:
        texto = (valores.get(chave) or "").strip()
        if limite and len(texto) > limite:
            erros[chave] = f"{rotulo}: máximo de {limite} caracteres."
        dados[chave] = texto

    texto_data = dados["data_nasc"]
    dados["data_nasc"] = converter_data(texto_data)
    if texto_data and dados["data_nasc"] is None:
        erros["data_nasc"] = "Data de nascimento inválida. Use dd/mm/aaaa."
    return dados, erros


def distribuir_erros(erros):
    """Associa cada mensagem de DadosInvalidos.erros ao campo a que se
    refere. Devolve ({chave: mensagem}, [mensagens sem campo])."""
    por_campo, gerais = {}, []
    # rótulos mais longos primeiro ("CEP" não pode capturar outro rótulo)
    ordem = sorted(ROTULOS.items(), key=lambda par: -len(par[1]))
    for msg in erros:
        chave = next((c for c, r in ordem if msg.startswith(r)), None)
        if chave is None and "CPF" in msg:  # "Já existe um paciente com este CPF."
            chave = "cpf"
        if chave and chave not in por_campo:
            por_campo[chave] = msg
        else:
            gerais.append(msg)
    return por_campo, gerais
