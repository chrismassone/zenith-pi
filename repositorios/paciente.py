from mysql.connector import Error
from database.conexao import conectar
from validacoes.documentos import somente_digitos
from validacoes.paciente import validar_paciente

ERRO_CPF_DUPLICADO = 1062  # código do MySQL para violação de UNIQUE


class DadosInvalidos(Exception):
    """Dados do paciente reprovados na validação. Carrega a lista de erros."""

    def __init__(self, erros):
        self.erros = erros
        super().__init__("; ".join(erros))


def _normalizar(dados):
    """Limpa os dados para o formato que o banco espera."""
    return {
        "nome_completo": dados["nome_completo"].strip(),
        "cpf": somente_digitos(dados["cpf"]),
        "data_nasc": dados["data_nasc"],
        "telefone_paciente": somente_digitos(dados["telefone_paciente"]),
        "email_paciente": (dados.get("email_paciente") or "").strip() or None,
        "cep_paciente": somente_digitos(dados["cep_paciente"]),
        "endereco_paciente": dados["endereco_paciente"].strip(),
        "bairro_paciente": dados["bairro_paciente"].strip(),
        "cidade_paciente": dados["cidade_paciente"].strip(),
        "origem_captacao": dados["origem_captacao"].strip(),
    }


def _executar(sql, parametros=(), consulta=False, um=False):
    """Abre a conexão, executa e fecha. Traduz erros técnicos em mensagens claras."""
    conn = conectar()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(sql, parametros)
        if consulta:
            return cursor.fetchone() if um else cursor.fetchall()
        conn.commit()
        return cursor.lastrowid, cursor.rowcount
    except Error as erro:
        conn.rollback()
        if erro.errno == ERRO_CPF_DUPLICADO:
            raise DadosInvalidos(["Já existe um paciente com este CPF."]) from erro
        raise RuntimeError(
            "Não foi possível concluir a operação no banco de dados."
        ) from erro
    finally:
        conn.close()


def inserir(dados):
    erros = validar_paciente(dados)
    if erros:
        raise DadosInvalidos(erros)
    d = _normalizar(dados)
    sql = """INSERT INTO paciente
             (nome_completo, cpf, data_nasc, telefone_paciente, email_paciente,
              cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente,
              origem_captacao)
             VALUES (%(nome_completo)s, %(cpf)s, %(data_nasc)s, %(telefone_paciente)s,
                     %(email_paciente)s, %(cep_paciente)s, %(endereco_paciente)s,
                     %(bairro_paciente)s, %(cidade_paciente)s, %(origem_captacao)s)"""
    novo_id, _ = _executar(sql, d)
    return novo_id


def buscar_por_id(id_paciente):
    return _executar("SELECT * FROM paciente WHERE id_paciente = %s",
                     (id_paciente,), consulta=True, um=True)


def listar(busca="", incluir_inativos=False):
    """Lista pacientes. 'busca' procura no nome ou no CPF (só dígitos)."""
    sql = "SELECT * FROM paciente WHERE 1=1"
    parametros = []
    if not incluir_inativos:
        sql += " AND ativo = TRUE"
    busca = busca.strip()
    if busca:
        digitos = somente_digitos(busca)
        if digitos:
            sql += " AND (nome_completo LIKE %s OR cpf LIKE %s)"
            parametros += [f"%{busca}%", f"%{digitos}%"]
        else:
            sql += " AND nome_completo LIKE %s"
            parametros.append(f"%{busca}%")
    sql += " ORDER BY nome_completo"
    return _executar(sql, parametros, consulta=True)


def atualizar(id_paciente, dados):
    erros = validar_paciente(dados)
    if erros:
        raise DadosInvalidos(erros)
    d = _normalizar(dados)
    d["id_paciente"] = id_paciente
    sql = """UPDATE paciente SET
                nome_completo = %(nome_completo)s, cpf = %(cpf)s,
                data_nasc = %(data_nasc)s, telefone_paciente = %(telefone_paciente)s,
                email_paciente = %(email_paciente)s, cep_paciente = %(cep_paciente)s,
                endereco_paciente = %(endereco_paciente)s,
                bairro_paciente = %(bairro_paciente)s,
                cidade_paciente = %(cidade_paciente)s,
                origem_captacao = %(origem_captacao)s
             WHERE id_paciente = %(id_paciente)s"""
    _, linhas = _executar(sql, d)
    return linhas > 0


def inativar(id_paciente):
    _, linhas = _executar("UPDATE paciente SET ativo = FALSE WHERE id_paciente = %s",
                          (id_paciente,))
    return linhas > 0


def reativar(id_paciente):
    _, linhas = _executar("UPDATE paciente SET ativo = TRUE WHERE id_paciente = %s",
                          (id_paciente,))
    return linhas > 0
