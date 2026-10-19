"""SQL de paciente, anamnese e histórico. Sem regra de negócio
(ver servicos/pacientes.py)."""
from repositorios.base import consultar, executar
from validacoes.documentos import somente_digitos

CAMPOS = ("nome_completo", "cpf", "data_nasc", "telefone_paciente", "email_paciente",
          "cep_paciente", "endereco_paciente", "bairro_paciente", "cidade_paciente",
          "origem_captacao")


def inserir(d):
    colunas = ", ".join(CAMPOS)
    marcas = ", ".join(f"%({c})s" for c in CAMPOS)
    novo_id, _ = executar(f"INSERT INTO paciente ({colunas}) VALUES ({marcas})", d)
    return novo_id


def atualizar(id_paciente, d):
    sets = ", ".join(f"{c} = %({c})s" for c in CAMPOS)
    _, linhas = executar(f"UPDATE paciente SET {sets} WHERE id_paciente = %(id)s",
                         {**d, "id": id_paciente})
    return linhas


def buscar_por_id(id_paciente):
    return consultar("SELECT * FROM paciente WHERE id_paciente = %s", (id_paciente,), um=True)


def listar(busca="", incluir_inativos=False):
    """'busca' procura no nome ou no CPF (só dígitos)."""
    sql = "SELECT * FROM paciente WHERE 1=1"
    parametros = []
    if not incluir_inativos:
        sql += " AND ativo = TRUE"
    busca = (busca or "").strip()
    if busca:
        digitos = somente_digitos(busca)
        if digitos:
            sql += " AND (nome_completo LIKE %s OR cpf LIKE %s)"
            parametros += [f"%{busca}%", f"%{digitos}%"]
        else:
            sql += " AND nome_completo LIKE %s"
            parametros.append(f"%{busca}%")
    return consultar(sql + " ORDER BY nome_completo", parametros)


def definir_ativo(id_paciente, ativo):
    _, linhas = executar("UPDATE paciente SET ativo = %s WHERE id_paciente = %s",
                         (ativo, id_paciente))
    return linhas


# ---------- anamnese ----------
CAMPOS_ANAMNESE = ("queixa_principal", "historico_saude", "alergias",
                   "medicamentos_em_uso", "observacoes")


def listar_anamneses(id_paciente):
    return consultar(
        """SELECT an.*, pr.nome_completo AS profissional
             FROM anamnese an JOIN profissional pr USING (id_profissional)
            WHERE an.id_paciente = %s ORDER BY an.data_registro DESC""", (id_paciente,))


def inserir_anamnese(id_paciente, id_profissional, d):
    novo_id, _ = executar(
        f"""INSERT INTO anamnese (id_paciente, id_profissional, {", ".join(CAMPOS_ANAMNESE)})
            VALUES (%s, %s, {", ".join(["%s"] * len(CAMPOS_ANAMNESE))})""",
        (id_paciente, id_profissional, *[d[c] for c in CAMPOS_ANAMNESE]))
    return novo_id


def atualizar_anamnese(id_anamnese, d):
    sets = ", ".join(f"{c} = %({c})s" for c in CAMPOS_ANAMNESE)
    _, linhas = executar(f"UPDATE anamnese SET {sets} WHERE id_anamnese = %(id)s",
                         {**d, "id": id_anamnese})
    return linhas


# ---------- histórico ----------
def historico(id_paciente):
    return consultar(
        """SELECT v.id_atendimento, v.data_hora, v.status, v.valor_total,
                  u.nome_clinica,
                  GROUP_CONCAT(pr.nome_procedimento ORDER BY ap.id_atend_proc SEPARATOR ', ')
                      AS procedimentos
             FROM vw_valor_atendimento v
             JOIN unidade u ON u.id_unidade = v.id_unidade
             LEFT JOIN atendimento_procedimento ap ON ap.id_atendimento = v.id_atendimento
             LEFT JOIN procedimento pr ON pr.id_procedimento = ap.id_procedimento
            WHERE v.id_paciente = %s
            GROUP BY v.id_atendimento, v.data_hora, v.status, v.valor_total, u.nome_clinica
            ORDER BY v.data_hora DESC""", (id_paciente,))
