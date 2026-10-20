from ferramentas import banco_teste
banco_teste.usar()  # grava só no banco zenith_teste

from repositorios.base import transacao
from servicos import pacientes
from servicos.erros import DadosInvalidos
from servicos.sessao import Sessao

S = Sessao(dict(id_usuario=0, nome="Teste", email="t@exemplo.invalid", perfil="Gerente"))
dados = {
    "nome_completo": "Paciente de Teste",
    "cpf": "111.444.777-35",          # CPF de exemplo, válido só pelo algoritmo
    "data_nasc": "10/05/1990",
    "telefone_paciente": "(11) 98765-4321",
    "email_paciente": "",
    "cep_paciente": "03047-000",
    "endereco_paciente": "Rua de Teste, 10",
    "bairro_paciente": "Mooca",
    "cidade_paciente": "São Paulo",
    "origem_captacao": "Instagram",
}

id_teste = None
try:
    id_teste = pacientes.salvar(S, dados)
    print("1. Inserido, id =", id_teste)
    print("2. Buscado:", pacientes.obter(S, id_teste)["nome_completo"])
    print("3. Listar 'Paciente de Teste':", len(pacientes.listar(S, "Paciente de Teste")),
          "resultado(s)")
    pacientes.salvar(S, {**dados, "telefone_paciente": "(11) 91234-5678"}, id_teste)
    print("4. Atualizado:", pacientes.obter(S, id_teste)["telefone_paciente"])
    try:
        pacientes.salvar(S, dados)
        print("5. FALHA: aceitou CPF duplicado")
    except DadosInvalidos as e:
        print("5. CPF duplicado recusado:", list(e.erros.values()))
    try:
        pacientes.salvar(S, {**dados, "cpf": "11111111111"})
        print("6. FALHA: aceitou CPF inválido")
    except DadosInvalidos as e:
        print("6. CPF inválido recusado:", list(e.erros.values()))
    pacientes.definir_ativo(S, id_teste, False)
    print("7. Inativado. Aparece na lista de ativos?",
          len(pacientes.listar(S, "Paciente de Teste")) > 0, "(esperado: False)")
    print("   Aparece com inativos?",
          len(pacientes.listar(S, "Paciente de Teste", True)) > 0, "(esperado: True)")
finally:
    if id_teste:
        with transacao() as cur:
            cur.execute("DELETE FROM paciente WHERE id_paciente = %s", (id_teste,))
        print("Registro de teste removido.")
