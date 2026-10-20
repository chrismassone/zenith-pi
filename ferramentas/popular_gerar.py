"""Gera banco/2_populacao.sql com dados fictícios.

A semente é fixa: rodar de novo gera o mesmo arquivo. Preços, locação,
retornos e quantidades padrão são suposições a confirmar com a cliente.

Uso: python -m ferramentas.popular_gerar
"""
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
import math
import random

SEMENTE = 20261016
rnd = random.Random(SEMENTE)

HOJE = date(2026, 10, 16)            # data de referência da população
INICIO = date(2025, 10, 1)           # primeiro atendimento
FIM_PASSADO = date(2026, 10, 15)     # último atendimento já ocorrido
FIM_FUTURO = date(2026, 11, 15)      # agendamentos futuros até aqui
ESTOQUE_INICIAL = date(2025, 9, 22)  # primeira compra de cada insumo
AGENDA_INICIO = date(2026, 10, 19)   # agenda futura: 15 dias úteis a partir daqui
AGENDA_DIAS_UTEIS = 15
FERIADOS = {date(2026, 11, 2)}       # Finados: sem atendimento
SAIDA = Path(__file__).resolve().parents[1] / "banco" / "2_populacao.sql"

META = dict(paciente=120, atendimento=250, atendimento_procedimento=300,
            compra=100, consumo=150, anamnese=60, lancamento=60)


def dec(valor, casas=2):
    return Decimal(str(valor)).quantize(Decimal(1).scaleb(-casas), ROUND_HALF_UP)


# CPF e CNPJ válidos só pelo algoritmo
def gerar_cpf(usados):
    while True:
        base = [rnd.randint(0, 9) for _ in range(9)]
        if len(set(base)) == 1:
            continue
        for tamanho in (9, 10):
            soma = sum(d * (tamanho + 1 - i) for i, d in enumerate(base))
            dv = soma * 10 % 11
            base.append(0 if dv == 10 else dv)
        cpf = "".join(map(str, base))
        if cpf not in usados:
            usados.add(cpf)
            return cpf


def gerar_cnpj(usados):
    while True:
        base = [rnd.randint(0, 9) for _ in range(8)] + [0, 0, 0, 1]
        for pesos in ([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
                      [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]):
            resto = sum(d * p for d, p in zip(base, pesos)) % 11
            base.append(0 if resto < 2 else 11 - resto)
        cnpj = "".join(map(str, base))
        if cnpj not in usados:
            usados.add(cnpj)
            return cnpj


def celular():
    return "11" + "9" + "".join(str(rnd.randint(0, 9)) for _ in range(8))


def fixo():
    return "11" + str(rnd.randint(2, 4)) + "".join(str(rnd.randint(0, 9)) for _ in range(7))


# suposição: valor_locacao é por dia de uso da sala
UNIDADES = [
    # nome, bairro, cidade, uf, valor_locacao
    ("Unidade Mooca", "Mooca", "São Paulo", "SP", 350),
    ("Unidade Tatuapé", "Tatuapé", "São Paulo", "SP", 400),
    ("Unidade Mogi das Cruzes", "Centro", "Mogi das Cruzes", "SP", 250),  # bairro a confirmar
]

# suposição: preços e intervalos de retorno
PROCEDIMENTOS = [
    # nome, preço, retorno (dias), regiões possíveis
    ("Toxina botulínica", 1200, 150, ["Glabela e testa", "Pés de galinha", "Testa",
                                      "Glabela", "Terço superior"]),
    ("Preenchimento facial", 1500, 300, ["Mandíbula", "Malar", "Mento", "Sulco nasogeniano"]),
    ("Preenchimento labial", 1300, 270, ["Lábios", "Contorno labial"]),
    ("Bioestimulador", 2300, 180, ["Face (terço médio)", "Face (terço inferior)", "Pescoço"]),
    ("Skinbooster", 950, 120, ["Face", "Face e pescoço"]),
    ("Avaliação facial", 100, None, ["Face"]),
    ("Tratamento de olheiras", 1600, 270, ["Região periorbital"]),
]
P_TOXINA, P_FACIAL, P_LABIAL, P_BIO, P_SKIN, P_AVAL, P_OLHEIRA = range(1, 8)

FORNECEDORES = [
    # razão social (fictícia), bairro, cidade, cep-prefixo
    ("Alfa Exemplo Distribuidora de Produtos Estéticos Ltda", "Vila Mariana", "São Paulo", "041"),
    ("Beta Exemplo Produtos Médicos Ltda", "Santana", "São Paulo", "020"),
    ("Gama Exemplo Dermocosméticos Ltda", "Centro", "Mogi das Cruzes", "087"),
    ("Delta Exemplo Materiais Hospitalares Ltda", "Brás", "São Paulo", "030"),
]

# (nome, marca, apresentação, unidade, mínimo, preço unitário, embalagem,
#  fornecedores possíveis, validade em meses). Preço, mínimo e embalagem são suposições.
INSUMOS = [
    ("Botox", "Allergan", "Frasco 100U", "U", 200, 14.50, 100, [1, 3], 18),
    ("Letybo", "Hugel", "Frasco 50U", "U", 100, 17.80, 50, [1], 18),
    ("Botulift", "Biolab", "Frasco 100U", "U", 100, 7.60, 100, [1, 3], 18),
    ("Yvoire Contour", "LG Chem", "Seringa 1,0 mL", "mL", 4, 980.00, 1, [1, 2], 24),
    ("Up Ilikia", "Ilikia", "Seringa 1,0 mL", "mL", 4, 620.00, 1, [1], 24),
    ("Alur Medical", "Alur Medical", "Seringa 1,0 mL", "mL", 4, 540.00, 1, [2, 3], 24),
    ("Milimetric", "Milimetric", "Seringa 1,0 mL", "mL", 3, 580.00, 1, [1, 2], 24),
    ("Radiesse", "Merz Aesthetics", "Seringa 1,5 mL", "seringa", 1, 1850.00, 1, [1], 24),
    ("Sculptra", "Galderma", "Frasco 367,5 mg", "frasco", 2, 2100.00, 1, [1, 3], 30),
    ("PLLA Cimed", "Cimed", "Frasco 150 mg", "frasco", 1, 890.00, 1, [3], 24),
    ("Stim", "Stim", "Seringa 1,0 mL", "seringa", 1, 720.00, 1, [2], 24),
    ("Agulha 30G 13 mm", "Genérico", "Caixa 100 un", "un", 60, 0.45, 100, [4, 2], 48),
    ("Cânula 25G 50 mm", "Genérico", "Caixa 20 un", "un", 15, 9.90, 20, [4], 48),
    ("Seringa 1 mL", "Genérico", "Caixa 100 un", "un", 60, 0.60, 100, [4, 2], 48),
    ("Luva de procedimento", "Genérico", "Caixa 50 pares", "par", 40, 0.90, 50, [4], 36),
    ("Gaze estéril", "Genérico", "Pacote 10 un", "un", 60, 0.35, 100, [4, 2], 36),
    ("Clorexidina alcoólica 0,5%", "Genérico", "Frasco 1000 mL", "mL", 500, 0.03, 1000, [4], 24),
    ("Soro fisiológico 0,9%", "Genérico", "Frasco 250 mL", "mL", 250, 0.02, 250, [4, 2], 24),
    ("Água para injeção", "Genérico", "Ampola 10 mL", "mL", 50, 0.20, 100, [4], 24),
    ("Anestésico tópico", "Genérico", "Bisnaga 30 g", "g", 30, 2.50, 30, [2, 3], 18),
    ("Algodão", "Genérico", "Pacote 500 g", "g", 200, 0.04, 500, [4], 60),
    ("Máscara descartável", "Genérico", "Caixa 50 un", "un", 30, 0.30, 50, [4], 60),
]
NOME_INSUMO = {i + 1: dados[0] for i, dados in enumerate(INSUMOS)}
ID_INSUMO = {dados[0]: i + 1 for i, dados in enumerate(INSUMOS)}

# quantidade padrão por procedimento (suposição; editável no app)
PADRAO = {
    P_TOXINA: [("Botox", 50), ("Agulha 30G 13 mm", 3), ("Seringa 1 mL", 1),
               ("Soro fisiológico 0,9%", 2.5), ("Luva de procedimento", 1),
               ("Clorexidina alcoólica 0,5%", 5), ("Gaze estéril", 4)],
    P_FACIAL: [("Yvoire Contour", 1.5), ("Cânula 25G 50 mm", 1), ("Agulha 30G 13 mm", 1),
               ("Anestésico tópico", 2), ("Luva de procedimento", 1),
               ("Clorexidina alcoólica 0,5%", 5), ("Gaze estéril", 4)],
    P_LABIAL: [("Alur Medical", 1), ("Agulha 30G 13 mm", 2), ("Anestésico tópico", 2),
               ("Luva de procedimento", 1), ("Gaze estéril", 3)],
    P_BIO: [("Sculptra", 1), ("Água para injeção", 8), ("Cânula 25G 50 mm", 1),
            ("Seringa 1 mL", 2), ("Luva de procedimento", 1),
            ("Clorexidina alcoólica 0,5%", 5), ("Gaze estéril", 4)],
    P_SKIN: [("Up Ilikia", 2), ("Agulha 30G 13 mm", 4), ("Anestésico tópico", 3),
             ("Luva de procedimento", 1), ("Gaze estéril", 3)],
    P_AVAL: [],  # avaliação não consome insumo (mostra a mínima 0)
    P_OLHEIRA: [("Milimetric", 1), ("Cânula 25G 50 mm", 1), ("Anestésico tópico", 1),
                ("Luva de procedimento", 1), ("Gaze estéril", 3)],
}
# às vezes a profissional usa outro produto
TROCAS = {"Botox": ["Letybo", "Botulift"], "Sculptra": ["Radiesse", "PLLA Cimed", "Stim"]}

PRENOMES = ["Ana", "Beatriz", "Camila", "Daniela", "Eduarda", "Fernanda", "Gabriela",
            "Helena", "Isabela", "Juliana", "Larissa", "Mariana", "Natália", "Patrícia",
            "Renata", "Sofia", "Tatiana", "Vanessa", "Yasmin", "Aline", "Bruna", "Carla",
            "Débora", "Elisa", "Flávia", "Giovana", "Lívia", "Marina", "Priscila", "Raquel",
            "Bruno", "Carlos", "Diego", "Felipe", "Gustavo", "Henrique", "Lucas", "Mateus",
            "Rafael", "Thiago"]
SOBRENOMES = ["Almeida", "Barros", "Cardoso", "Dias", "Esteves", "Faria", "Gomes", "Lacerda",
              "Macedo", "Nogueira", "Pacheco", "Queiroz", "Rezende", "Siqueira", "Teixeira",
              "Vasconcelos", "Antunes", "Brandão", "Coutinho", "Duarte", "Fontes", "Guimarães",
              "Leal", "Moura", "Peixoto", "Ramos", "Sampaio", "Tavares", "Valente", "Xavier"]
# (cidade, bairro, prefixo de CEP, peso)
BAIRROS = [
    ("São Paulo", "Mooca", "031", 14), ("São Paulo", "Tatuapé", "033", 14),
    ("São Paulo", "Água Rasa", "032", 5), ("São Paulo", "Belém", "030", 5),
    ("São Paulo", "Carrão", "034", 6), ("São Paulo", "Vila Formosa", "035", 5),
    ("São Paulo", "Penha", "036", 5), ("São Paulo", "Vila Prudente", "031", 4),
    ("São Paulo", "Brás", "030", 3), ("São Paulo", "Vila Mariana", "041", 3),
    ("São Paulo", "Santana", "020", 2), ("São Paulo", "Itaquera", "082", 3),
    ("Mogi das Cruzes", "Centro", "087", 7), ("Mogi das Cruzes", "Mogilar", "087", 4),
    ("Mogi das Cruzes", "Vila Oliveira", "087", 3), ("Mogi das Cruzes", "Braz Cubas", "087", 3),
    ("Suzano", "Centro", "086", 3), ("Guarulhos", "Macedo", "071", 1),
]
LOGRADOUROS = ["Rua das Acácias", "Rua dos Ipês", "Rua das Palmeiras", "Avenida das Flores",
               "Rua dos Girassóis", "Rua das Hortênsias", "Rua dos Jacarandás",
               "Avenida dos Pinheiros Exemplo", "Rua das Magnólias", "Rua dos Cedros",
               "Travessa das Orquídeas", "Rua das Violetas"]
ORIGENS = [("Instagram", 45), ("Indicação", 30), ("Google", 12), ("WhatsApp", 8),
           ("Facebook", 5)]
PAGAMENTOS = [("Pix", 40), ("Cartão de crédito", 35), ("Cartão de débito", 15),
              ("Dinheiro", 10)]


def sorteio(pares):
    itens, pesos = zip(*pares)
    return rnd.choices(itens, weights=pesos)[0]


def sem_acento(texto):
    tabela = str.maketrans("áàâãéêíóôõúçÁÉÍÓÚÇ", "aaaaeeiooouc" + "AEIOUC")
    return texto.translate(tabela)


def gerar():
    linhas_unidade = [dict(id=i + 1, nome=n, bairro=b, cidade=c, uf=uf, loc=dec(v))
                      for i, (n, b, c, uf, v) in enumerate(UNIDADES)]

    cnpjs = set()
    fornecedores = []
    for i, (razao, bairro, cidade, pref) in enumerate(FORNECEDORES):
        fornecedores.append(dict(
            id=i + 1, razao=razao, cnpj=gerar_cnpj(cnpjs), tel=fixo(),
            cep=pref + "".join(str(rnd.randint(0, 9)) for _ in range(5)),
            end=f"{rnd.choice(LOGRADOUROS)}, {rnd.randint(10, 2500)}",
            bairro=bairro, cidade=cidade))

    # pacientes
    cpfs, emails = set(), set()
    pacientes = []
    for i in range(META["paciente"] + 6):
        nome = f"{rnd.choice(PRENOMES)} {rnd.choice(SOBRENOMES)} {rnd.choice(SOBRENOMES)}"
        cidade, bairro, pref, _ = rnd.choices(BAIRROS, weights=[b[3] for b in BAIRROS])[0]
        email = None
        if rnd.random() < 0.8:
            base = sem_acento(nome.lower()).split()
            email = f"{base[0]}.{base[-1]}{i + 1}@exemplo.invalid"
        nasc = date(rnd.randint(1965, 2004), rnd.randint(1, 12), rnd.randint(1, 28))
        pacientes.append(dict(
            id=i + 1, nome=nome, cpf=gerar_cpf(cpfs), nasc=nasc, tel=celular(),
            email=email, cep=pref + "".join(str(rnd.randint(0, 9)) for _ in range(5)),
            end=f"{rnd.choice(LOGRADOUROS)}, {rnd.randint(10, 3000)}",
            bairro=bairro, cidade=cidade, origem=sorteio(ORIGENS), ativo=True))
    # alguns pacientes inativos e alguns só cadastrados, sem atendimento
    for p in rnd.sample(pacientes, 9):
        p["ativo"] = False
    sem_atendimento = {p["id"] for p in rnd.sample([p for p in pacientes if p["ativo"]], 5)}

    # atendimentos (simulação da jornada de cada paciente)
    ocupados = set()

    def horario(dia, unidade):
        horas = [9, 10, 11, 13, 14, 15, 16, 17]
        rnd.shuffle(horas)
        for h in horas:
            for minuto in (0, 30):
                dh = datetime(dia.year, dia.month, dia.day, h, minuto)
                if (unidade, dh) not in ocupados:
                    ocupados.add((unidade, dh))
                    return dh
        return None

    def dia_util(d):
        while d.weekday() >= 5:      # sábado e domingo não atendem (SUPOSIÇÃO)
            d += timedelta(days=1)
        return d

    def unidade_do(p):
        if p["cidade"] in ("Mogi das Cruzes", "Suzano"):
            return 3 if rnd.random() < 0.85 else rnd.choice([1, 2])
        if p["bairro"] in ("Mooca", "Água Rasa", "Vila Prudente", "Brás", "Belém"):
            return 1 if rnd.random() < 0.75 else rnd.choice([2, 3])
        return 2 if rnd.random() < 0.7 else rnd.choice([1, 3])

    atendimentos, itens = [], []

    def novo_atendimento(p, dia, status, procs):
        unid = unidade_do(p)
        dh = horario(dia, unid)
        if dh is None:
            return None
        a = dict(id=len(atendimentos) + 1, pac=p["id"], unid=unid, dh=dh, status=status,
                 pag=None, desc=dec(0), itens=[])
        atendimentos.append(a)
        if status in ("Realizado", "Agendado"):
            for proc in procs:
                nome, preco, _, regioes = PROCEDIMENTOS[proc - 1]
                if proc == P_TOXINA:
                    qtd = dec(rnd.choice([20, 30, 40, 50, 60]))
                elif proc in (P_FACIAL, P_SKIN):
                    qtd = dec(rnd.choice([1, 1.5, 2]))
                else:
                    qtd = dec(1)
                item = dict(id=len(itens) + 1, at=a["id"], proc=proc, qtd=qtd,
                            regiao=rnd.choice(regioes), valor=dec(preco))
                itens.append(item)
                a["itens"].append(item)
        if status == "Realizado":
            a["pag"] = sorteio(PAGAMENTOS)
            subtotal = sum(i["valor"] for i in a["itens"])
            if rnd.random() < 0.15:     # desconto ocasional de 5% ou 10%
                a["desc"] = dec(subtotal * Decimal(rnd.choice(["0.05", "0.10"])))
        return a

    def status_passado():
        return sorteio([("Realizado", 82), ("Faltou", 10), ("Cancelado", 8)])

    procs_principais = [P_TOXINA, P_FACIAL, P_LABIAL, P_BIO, P_SKIN, P_OLHEIRA]
    pesos_principais = [35, 15, 15, 10, 15, 10]
    janela = (FIM_PASSADO - INICIO).days

    for p in pacientes:
        if p["id"] in sem_atendimento:
            continue
        dia = dia_util(INICIO + timedelta(days=rnd.randint(0, janela - 20)))
        primeira = True
        proc = rnd.choices(procs_principais, weights=pesos_principais)[0]
        while True:
            if dia > FIM_PASSADO:
                # próximo retorno cai no futuro: às vezes já está agendado
                if dia <= FIM_FUTURO and rnd.random() < 0.6:
                    novo_atendimento(p, dia, "Agendado", [proc])
                break
            status = status_passado()
            procs = [proc]
            if primeira and rnd.random() < 0.55:
                procs = [P_AVAL, proc]
            elif rnd.random() < 0.2:
                extra = rnd.choices(procs_principais, weights=pesos_principais)[0]
                if extra != proc:
                    procs.append(extra)
            a = novo_atendimento(p, dia, status, procs)
            if a is None:
                dia = dia_util(dia + timedelta(days=1))
                continue
            primeira = False
            if status in ("Faltou", "Cancelado"):
                if rnd.random() < 0.7:            # remarca em 1 a 3 semanas
                    dia = dia_util(dia + timedelta(days=rnd.randint(7, 21)))
                    continue
                break
            intervalo = PROCEDIMENTOS[proc - 1][2]
            if rnd.random() < 0.55:               # volta no prazo de retorno
                dia = dia_util(dia + timedelta(days=int(intervalo * rnd.uniform(0.9, 1.15))))
                if rnd.random() < 0.3:
                    proc = rnd.choices(procs_principais, weights=pesos_principais)[0]
                continue
            break

    # completa as metas com atendimentos avulsos de pacientes já atendidos
    atendidos = [p for p in pacientes if p["id"] not in sem_atendimento]
    def passados():
        return [a for a in atendimentos if a["dh"].date() <= FIM_PASSADO]
    while len(passados()) < META["atendimento"] or len(itens) < META["atendimento_procedimento"]:
        p = rnd.choice(atendidos)
        dia = dia_util(INICIO + timedelta(days=rnd.randint(0, janela)))
        if dia > FIM_PASSADO:
            continue
        proc = rnd.choices(procs_principais, weights=pesos_principais)[0]
        novo_atendimento(p, dia, "Realizado" if rnd.random() < 0.9 else status_passado(),
                         [proc] if rnd.random() < 0.6 else [proc, P_AVAL])
    # alguns agendamentos ainda hoje e nos próximos dias
    for _ in range(8):
        p = rnd.choice([p for p in atendidos if p["ativo"]])
        dia = dia_util(HOJE + timedelta(days=rnd.choice([0, 0, 1, 3, 5, 7])))
        novo_atendimento(p, dia, "Agendado",
                         [rnd.choices(procs_principais, weights=pesos_principais)[0]])

    # renumera por data, para os ids seguirem a ordem cronológica
    atendimentos.sort(key=lambda a: (a["dh"], a["unid"]))
    novo_id = {a["id"]: i + 1 for i, a in enumerate(atendimentos)}
    for a in atendimentos:
        a["id"] = novo_id[a["id"]]
    itens = [i for a in atendimentos for i in a["itens"]]
    for n, i in enumerate(itens):
        i["id"] = n + 1
        i["at"] = novo_id[i["at"]]

    # cadastro alguns dias antes do primeiro atendimento; gerador próprio
    # para não mexer na sequência dos outros dados
    rnd_cad = random.Random(SEMENTE + 1)
    primeiro = {}
    for a in atendimentos:
        primeiro.setdefault(a["pac"], a["dh"])
    for p in pacientes:
        if p["id"] in primeiro:
            base = primeiro[p["id"]] - timedelta(days=rnd_cad.randint(1, 12))
        else:
            dia = INICIO + timedelta(days=rnd_cad.randint(0, janela))
            base = datetime(dia.year, dia.month, dia.day)
        p["criado"] = base.replace(hour=rnd_cad.randint(9, 18), minute=rnd_cad.randint(0, 59), second=0)

    # estoque: simulação cronológica (saldo nunca negativo)
    saldo = defaultdict(Decimal)
    compras, consumos = [], []
    ultima_compra = {}
    poucos = {ID_INSUMO[n] for n in ("Milimetric", "Up Ilikia", "Anestésico tópico")}
    vencendo = [ID_INSUMO[n] for n in ("Alur Medical", "Soro fisiológico 0,9%", "Letybo")]
    data_corte_poucos = date(2026, 8, 15)

    def comprar(id_ins, dia, quantidade):
        nome, _, _, _, _, preco, emb, forns, meses = INSUMOS[id_ins - 1]
        dia = max(dia, ultima_compra.get(id_ins, ESTOQUE_INICIAL))
        lote = f"{sem_acento(nome)[:3].upper()}{dia:%y%m}{rnd.randint(10, 99)}"
        validade = dia + timedelta(days=int(30.4 * meses) + rnd.randint(-20, 20))
        compras.append(dict(id=len(compras) + 1, forn=rnd.choice(forns), ins=id_ins, dia=dia,
                            qtd=dec(quantidade),
                            preco=dec(preco * rnd.uniform(0.95, 1.06)),
                            lote=lote, validade=validade))
        ultima_compra[id_ins] = dia
        saldo[id_ins] += dec(quantidade)

    def reposicao(id_ins):
        _, _, _, _, minimo, _, emb, _, _ = INSUMOS[id_ins - 1]
        # suposição: compras pequenas, cerca de um estoque mínimo por pedido
        pacotes = max(1, math.ceil(minimo / emb))
        return emb * pacotes

    for id_ins in range(1, len(INSUMOS) + 1):
        comprar(id_ins, ESTOQUE_INICIAL + timedelta(days=rnd.randint(0, 6)), reposicao(id_ins))

    def arredonda(id_ins, valor):
        unidade = INSUMOS[id_ins - 1][3]
        if unidade in ("U", "un", "par", "frasco", "seringa"):
            return dec(max(1, round(valor)))
        return dec(max(0.5, round(valor * 2) / 2))   # mL e g em passos de 0,5

    def consumir(id_ins, quantidade, quando, atendimento=None, obs=None):
        minimo = Decimal(INSUMOS[id_ins - 1][4])
        dia = quando.date()
        if id_ins in poucos and dia >= data_corte_poucos:
            if saldo[id_ins] < quantidade:            # compra só o necessário
                emb = INSUMOS[id_ins - 1][6]
                comprar(id_ins, dia - timedelta(days=rnd.randint(1, 4)),
                        emb * max(1, math.ceil((quantidade - saldo[id_ins]) / emb)))
        elif saldo[id_ins] - quantidade < minimo:
            emb = INSUMOS[id_ins - 1][6]
            falta = quantidade + minimo - saldo[id_ins]
            comprar(id_ins, dia - timedelta(days=rnd.randint(1, 5)),
                    max(reposicao(id_ins), emb * math.ceil(falta / emb)))
        assert saldo[id_ins] >= quantidade
        saldo[id_ins] -= quantidade
        consumos.append(dict(id=len(consumos) + 1, ins=id_ins, at=atendimento,
                             qtd=quantidade, quando=quando, obs=obs))

    # consumos avulsos (sem atendimento), com motivo obrigatório
    motivos = ["Perda no preparo: frasco contaminado", "Descarte: embalagem violada",
               "Uso em demonstração interna", "Descarte: material vencido",
               "Perda: seringa danificada no transporte"]
    avulsos = []
    for _ in range(14):
        id_ins = rnd.choice([ID_INSUMO[n] for n in ("Gaze estéril", "Luva de procedimento",
                                                    "Agulha 30G 13 mm", "Seringa 1 mL",
                                                    "Algodão", "Máscara descartável",
                                                    "Clorexidina alcoólica 0,5%")])
        dia = dia_util(INICIO + timedelta(days=rnd.randint(0, janela)))
        if dia > FIM_PASSADO:
            continue
        quando = datetime(dia.year, dia.month, dia.day, 18, rnd.randint(0, 59))
        avulsos.append((quando, id_ins, rnd.choice(motivos)))

    # saídas em ordem cronológica, para o saldo nunca ficar negativo
    eventos = [(a["dh"], 0, a) for a in atendimentos if a["status"] == "Realizado"]
    eventos += [(quando, 1, (id_ins, motivo)) for quando, id_ins, motivo in avulsos]
    eventos.sort(key=lambda e: (e[0], e[1]))
    for quando, tipo, dado in eventos:
        if tipo == 1:
            id_ins, motivo = dado
            consumir(id_ins, arredonda(id_ins, INSUMOS[id_ins - 1][6] * 0.1), quando,
                     obs=motivo)
            continue
        a, minutos = dado, 0
        for item in a["itens"]:
            for nome, padrao in PADRAO[item["proc"]]:
                if nome in TROCAS and rnd.random() < 0.25:
                    nome = rnd.choice(TROCAS[nome])
                id_ins = ID_INSUMO[nome]
                if INSUMOS[id_ins - 1][3] == "U":
                    # toxina: usa o aplicado no paciente, com pequena perda de preparo
                    qtd = dec(item["qtd"] + rnd.choice([0, 0, 2, 5]))
                else:
                    # a profissional ajusta a quantidade sugerida (até 15% a mais ou a menos)
                    qtd = arredonda(id_ins, float(padrao) * rnd.uniform(0.85, 1.15))
                consumir(id_ins, qtd, a["dh"] + timedelta(minutes=minutos), a["id"])
                minutos += 1
    consumos.sort(key=lambda c: c["quando"])
    for n, c in enumerate(consumos):
        c["id"] = n + 1

    # insumos próximos do vencimento: a compra mais recente vence em breve
    for id_ins, dias in zip(vencendo, (18, 34, 52)):
        ultima = max((c for c in compras if c["ins"] == id_ins), key=lambda c: c["dia"])
        ultima["validade"] = HOJE + timedelta(days=dias)
    # um lote de PLLA já vencido, para o alerta aparecer
    plla = [c for c in compras if c["ins"] == ID_INSUMO["PLLA Cimed"]][0]
    plla["validade"] = date(2026, 9, 30)

    compras.sort(key=lambda c: (c["dia"], c["ins"]))
    for n, c in enumerate(compras):
        c["id"] = n + 1

    # mínimo acima do saldo final em alguns insumos, para o alerta aparecer
    minimos = {i + 1: dec(d[4]) for i, d in enumerate(INSUMOS)}
    for id_ins in poucos:
        emb = INSUMOS[id_ins - 1][6]
        minimos[id_ins] = max(minimos[id_ins], dec(saldo[id_ins] + emb * 2))

    procedimento_insumo = [(proc, ID_INSUMO[nome], dec(qtd))
                           for proc, lista in PADRAO.items() for nome, qtd in lista]

    # anamneses (texto fictício)
    queixas = ["Linhas de expressão na testa", "Perda de volume no rosto",
               "Lábios finos e assimétricos", "Olheiras profundas", "Flacidez facial",
               "Pele desidratada e sem viço", "Rugas ao redor dos olhos",
               "Contorno mandibular pouco definido"]
    historicos = ["Sem doenças crônicas relatadas.", "Hipotireoidismo controlado.",
                  "Hipertensão controlada com medicação.", "Nenhum procedimento estético anterior.",
                  "Já realizou toxina botulínica há mais de um ano.", "Rinite alérgica."]
    alergias = ["Nenhuma conhecida", "Nenhuma conhecida", "Nenhuma conhecida", "Dipirona",
                "Látex", "Penicilina"]
    remedios = ["Nenhum", "Nenhum", "Anticoncepcional oral", "Levotiroxina",
                "Losartana", "Vitamina D"]
    observacoes = [None, None, "Paciente prefere resultado natural.",
                   "Orientada sobre cuidados pós-procedimento.",
                   "Retorno sugerido conforme evolução."]
    anamneses = []
    primeiros = {}
    for a in atendimentos:
        if a["status"] == "Realizado" and a["pac"] not in primeiros:
            primeiros[a["pac"]] = a["dh"]
    for pac, dh in sorted(primeiros.items(), key=lambda x: x[1]):
        if len(anamneses) >= 80:
            break
        anamneses.append(dict(id=len(anamneses) + 1, pac=pac,
                              dh=dh - timedelta(minutes=10),
                              queixa=rnd.choice(queixas), hist=rnd.choice(historicos),
                              alergia=rnd.choice(alergias), rem=rnd.choice(remedios),
                              obs=rnd.choice(observacoes)))

    # lançamentos financeiros (valores fictícios, suposição)
    lancamentos = []
    mes = date(INICIO.year, INICIO.month, 1)
    while mes <= FIM_PASSADO:
        def lanc(unid, cat, desc, valor, tipo="DESPESA", dia=5):
            lancamentos.append(dict(id=len(lancamentos) + 1, unid=unid, cat=cat, desc=desc,
                                    valor=dec(valor), dia=mes.replace(day=dia), tipo=tipo))
        lanc(None, "Marketing", "Impulsionamento de publicações", rnd.randint(600, 1200), dia=3)
        lanc(None, "Contabilidade", "Honorários do escritório contábil", 650, dia=10)
        lanc(None, "Software", "Assinatura de sistemas e agenda", 189, dia=12)
        for u in (1, 2, 3):
            lanc(u, "Limpeza", "Material de limpeza da sala", rnd.randint(80, 180), dia=15)
        if rnd.random() < 0.5:
            lanc(rnd.choice([1, 2, 3]), "Manutenção", "Manutenção de equipamento",
                 rnd.randint(150, 600), dia=20)
        if rnd.random() < 0.4:
            lanc(None, "Venda de produtos", "Venda de dermocosmético home care",
                 rnd.randint(150, 500), tipo="RECEITA", dia=25)
        mes = (mes + timedelta(days=32)).replace(day=1)

    # agenda futura: 15 dias úteis a partir de 19/10/2026
    # gerador próprio e chamado por último, para não alterar os dados anteriores;
    # de 2 a 5 atendimentos por dia útil, contando os que já existem
    rnd_ag = random.Random(SEMENTE + 2)
    ja_agendados = {a["pac"] for a in atendimentos if a["status"] == "Agendado"}
    candidatos = [p for p in pacientes if p["ativo"] and p["id"] not in sem_atendimento
                  and p["id"] not in ja_agendados]
    por_dia = defaultdict(int)
    for a in atendimentos:
        if a["status"] == "Agendado":
            por_dia[a["dh"].date()] += 1

    def unidade_agenda(p):
        if p["cidade"] in ("Mogi das Cruzes", "Suzano"):
            return 3 if rnd_ag.random() < 0.85 else rnd_ag.choice([1, 2])
        if p["bairro"] in ("Mooca", "Água Rasa", "Vila Prudente", "Brás", "Belém"):
            return 1 if rnd_ag.random() < 0.75 else rnd_ag.choice([2, 3])
        return 2 if rnd_ag.random() < 0.7 else rnd_ag.choice([1, 3])

    def horario_agenda(dia, unidade):
        horas = [9, 10, 11, 13, 14, 15, 16, 17]
        rnd_ag.shuffle(horas)
        for h in horas:
            for minuto in (0, 30):
                dh = datetime(dia.year, dia.month, dia.day, h, minuto)
                if (unidade, dh) not in ocupados:
                    ocupados.add((unidade, dh))
                    return dh
        return None

    dia, uteis = AGENDA_INICIO, []
    while len(uteis) < AGENDA_DIAS_UTEIS:
        if dia.weekday() < 5 and dia not in FERIADOS:
            uteis.append(dia)
        dia += timedelta(days=1)
    for dia in uteis:
        alvo = rnd_ag.randint(2, 5)
        for _ in range(max(0, alvo - por_dia[dia])):
            p = candidatos.pop(rnd_ag.randrange(len(candidatos)))
            unid = unidade_agenda(p)
            dh = horario_agenda(dia, unid)
            a = dict(id=len(atendimentos) + 1, pac=p["id"], unid=unid, dh=dh,
                     status="Agendado", pag=None, desc=dec(0), itens=[])
            atendimentos.append(a)
            n_procs = 1 if rnd_ag.random() < 0.75 else 2
            procs = []
            while len(procs) < n_procs:
                proc = rnd_ag.choices(procs_principais, weights=pesos_principais)[0]
                if proc not in procs:
                    procs.append(proc)
            for proc in procs:
                nome, preco, _, regioes = PROCEDIMENTOS[proc - 1]
                if proc == P_TOXINA:
                    qtd = dec(rnd_ag.choice([20, 30, 40, 50, 60]))
                elif proc in (P_FACIAL, P_SKIN):
                    qtd = dec(rnd_ag.choice([1, 1.5, 2]))
                else:
                    qtd = dec(1)
                item = dict(id=len(itens) + 1, at=a["id"], proc=proc, qtd=qtd,
                            regiao=rnd_ag.choice(regioes), valor=dec(preco))
                itens.append(item)
                a["itens"].append(item)
            por_dia[dia] += 1

    return dict(unidades=linhas_unidade, fornecedores=fornecedores, pacientes=pacientes,
                atendimentos=atendimentos, itens=itens, compras=compras, consumos=consumos,
                procedimento_insumo=procedimento_insumo, minimos=minimos,
                anamneses=anamneses, lancamentos=lancamentos, saldo=saldo)


def q(valor):
    if valor is None:
        return "NULL"
    if isinstance(valor, bool):
        return "TRUE" if valor else "FALSE"
    if isinstance(valor, (int, Decimal)):
        return str(valor)
    if isinstance(valor, datetime):
        return f"'{valor:%Y-%m-%d %H:%M:%S}'"
    if isinstance(valor, date):
        return f"'{valor:%Y-%m-%d}'"
    return "'" + str(valor).replace("\\", "\\\\").replace("'", "''") + "'"


def insert(tabela, colunas, linhas):
    cab = f"INSERT INTO {tabela} ({', '.join(colunas)}) VALUES "
    return [cab + "(" + ", ".join(q(v) for v in linha) + ");" for linha in linhas]


def escrever(d):
    out = [
        "-- ============================================================",
        "-- ZENITH - populacao do banco v2 (gerado por popular_gerar.py)",
        f"-- Semente {SEMENTE}; data de referencia {HOJE:%Y-%m-%d}.",
        "-- TODOS OS DADOS SAO FICTICIOS. CPF/CNPJ validos apenas pelo algoritmo.",
        "-- SUPOSICAO: precos, locacao, retornos, quantidades padrao e valores",
        "-- financeiros sao ficticios, a confirmar com a cliente.",
        "-- Nao edite a mao: altere popular_gerar.py e gere de novo.",
        "-- Execute DEPOIS de 1_criacao.sql, com o banco vazio.",
        "-- ============================================================",
        "SET NAMES utf8mb4;",
        "USE zenith;",
        "START TRANSACTION;",
    ]
    out += insert("unidade", ["id_unidade", "nome_clinica", "bairro_unidade", "cidade_unidade",
                              "uf_unidade", "valor_locacao"],
                  [(u["id"], u["nome"], u["bairro"], u["cidade"], u["uf"], u["loc"])
                   for u in d["unidades"]])
    out += insert("profissional", ["id_profissional", "nome_completo"], [(1, "Gabriela Saraiva")])
    out += insert("procedimento", ["id_procedimento", "nome_procedimento", "preco_tabela",
                                   "intervalo_retorno_dias"],
                  [(i + 1, n, dec(p), r) for i, (n, p, r, _) in enumerate(PROCEDIMENTOS)])
    out += insert("fornecedor", ["id_fornecedor", "razao_social", "cnpj", "telefone_fornecedor",
                                 "cep_fornecedor", "endereco_fornecedor", "bairro_fornecedor",
                                 "cidade_fornecedor"],
                  [(f["id"], f["razao"], f["cnpj"], f["tel"], f["cep"], f["end"], f["bairro"],
                    f["cidade"]) for f in d["fornecedores"]])
    out += insert("insumo", ["id_insumo", "nome_insumo", "marca", "apresentacao",
                             "unidade_medida", "estoque_minimo"],
                  [(i + 1, x[0], x[1], x[2], x[3], d["minimos"][i + 1])
                   for i, x in enumerate(INSUMOS)])
    out += insert("procedimento_insumo", ["id_procedimento", "id_insumo", "quantidade_padrao"],
                  d["procedimento_insumo"])
    out += insert("paciente", ["id_paciente", "nome_completo", "cpf", "data_nasc",
                               "telefone_paciente", "email_paciente", "cep_paciente",
                               "endereco_paciente", "bairro_paciente", "cidade_paciente",
                               "origem_captacao", "ativo", "criado_em"],
                  [(p["id"], p["nome"], p["cpf"], p["nasc"], p["tel"], p["email"], p["cep"],
                    p["end"], p["bairro"], p["cidade"], p["origem"], p["ativo"], p["criado"])
                   for p in d["pacientes"]])
    out += insert("atendimento", ["id_atendimento", "id_profissional", "id_paciente",
                                  "id_unidade", "data_hora", "status", "forma_pagamento",
                                  "desconto"],
                  [(a["id"], 1, a["pac"], a["unid"], a["dh"], a["status"], a["pag"], a["desc"])
                   for a in d["atendimentos"]])
    out += insert("atendimento_procedimento", ["id_atend_proc", "id_atendimento",
                                               "id_procedimento", "quantidade_aplicada",
                                               "regiao_aplicada", "valor_cobrado"],
                  [(i["id"], i["at"], i["proc"], i["qtd"], i["regiao"], i["valor"])
                   for i in d["itens"]])
    out += insert("compra", ["id_compra", "id_fornecedor", "id_insumo", "data_compra",
                             "quantidade", "preco_unitario", "lote", "data_validade"],
                  [(c["id"], c["forn"], c["ins"], c["dia"], c["qtd"], c["preco"], c["lote"],
                    c["validade"]) for c in d["compras"]])
    out += insert("consumo", ["id_consumo", "id_insumo", "id_atendimento", "quantidade",
                              "data_consumo", "observacao"],
                  [(c["id"], c["ins"], c["at"], c["qtd"], c["quando"], c["obs"])
                   for c in d["consumos"]])
    out += insert("anamnese", ["id_anamnese", "id_paciente", "id_profissional", "data_registro",
                               "queixa_principal", "historico_saude", "alergias",
                               "medicamentos_em_uso", "observacoes"],
                  [(a["id"], a["pac"], 1, a["dh"], a["queixa"], a["hist"], a["alergia"],
                    a["rem"], a["obs"]) for a in d["anamneses"]])
    out += insert("lancamento", ["id_lancamento", "id_unidade", "categoria", "descricao", "valor",
                                 "data_lancamento", "tipo"],
                  [(l["id"], l["unid"], l["cat"], l["desc"], l["valor"], l["dia"], l["tipo"])
                   for l in d["lancamentos"]])
    out.append("COMMIT;")
    SAIDA.write_text("\n".join(out) + "\n", encoding="utf-8")

    contagem = dict(paciente=len(d["pacientes"]), atendimento=len(d["atendimentos"]),
                    atendimento_procedimento=len(d["itens"]), compra=len(d["compras"]),
                    consumo=len(d["consumos"]), procedimento_insumo=len(d["procedimento_insumo"]),
                    insumo=len(INSUMOS), fornecedor=len(d["fornecedores"]),
                    anamnese=len(d["anamneses"]), lancamento=len(d["lancamentos"]))
    return contagem


if __name__ == "__main__":
    contagem = escrever(gerar())
    for tabela, n in contagem.items():
        meta = META.get(tabela)
        aviso = "" if meta is None or n >= meta else f"  ABAIXO DA META ({meta})"
        print(f"{tabela:26s} {n:5d}{aviso}")
    print(f"\nArquivo gerado: {SAIDA.name}")
