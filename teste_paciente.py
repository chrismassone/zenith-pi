from datetime import date
from database.conexao import conectar
from repositorios import paciente as repo

dados = {
    "nome_completo": "Paciente de Teste",
    "cpf": "529.982.247-25",          # CPF de exemplo, matematicamente válido
    "data_nasc": date(1990, 5, 10),
    "telefone_paciente": "(11) 98765-4321",
    "email_paciente": "",
    "cep_paciente": "03047-000",
    "endereco_paciente": "Rua de Teste, 10",
    "bairro_paciente": "Mooca",
    "cidade_paciente": "Sao Paulo",
    "origem_captacao": "Instagram",
}

id_teste = None
try:
    id_teste = repo.inserir(dados)
    print("1. Inserido, id =", id_teste)

    print("2. Buscado:", repo.buscar_por_id(id_teste)["nome_completo"])
    print("3. Listar 'Teste':", len(repo.listar("Teste")), "resultado(s)")

    dados["telefone_paciente"] = "(11) 91234-5678"
    print("4. Atualizado:", repo.atualizar(id_teste, dados))

    try:
        repo.inserir(dados)
        print("5. FALHA: aceitou CPF duplicado")
    except repo.DadosInvalidos as e:
        print("5. CPF duplicado recusado:", e.erros)

    try:
        repo.inserir({**dados, "cpf": "11111111111"})
        print("6. FALHA: aceitou CPF inválido")
    except repo.DadosInvalidos as e:
        print("6. CPF inválido recusado:", e.erros)

    repo.inativar(id_teste)
    print("7. Inativado. Aparece na lista de ativos?",
          len(repo.listar("Teste")) > 0, "(esperado: False)")
    print("   Aparece com inativos?",
          len(repo.listar("Teste", incluir_inativos=True)) > 0, "(esperado: True)")
finally:
    if id_teste:
        conn = conectar()
        conn.cursor().execute("DELETE FROM paciente WHERE id_paciente = %s", (id_teste,))
        conn.commit()
        conn.close()
        print("Registro de teste removido.")
