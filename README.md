# Zenith

Sistema desktop de gestão do consultório de harmonização orofacial da
Dra. Gabriela Saraiva, desenvolvido como Projeto Integrador da FATEC.

Reúne o cadastro de pacientes (com anamnese e histórico), a agenda e o registro
de atendimentos nas três unidades, o catálogo de procedimentos com os insumos
usados em cada um, o controle de estoque (compras, consumo, validade), o
financeiro e um painel gerencial com os mesmos números do Power BI.

**Todos os dados do repositório são fictícios.**

## Requisitos

- Windows
- Python 3.14
- MySQL 8.0.47 (MySQL Workbench para rodar os scripts como root)
- Bibliotecas Python: ver `requirements.txt` (instaladas pelo `instalar.bat`)

## Instalação

1. Instale as dependências: dê dois cliques em `instalar.bat`
   (ou `python -m pip install -r requirements.txt`).
2. Copie `.env.example` para `.env` e preencha a conexão do usuário `zenith_app`.
   O `.env` **nunca** vai para o Git.

## Criar o banco

> **Atenção:** `banco/zenith_completo.sql` **apaga e recria** o schema `zenith`.
> Faça backup antes, se houver dados que você queira manter:
> `mysqldump -u root -p --routines --triggers --databases zenith > zenith_backup.sql`

1. No MySQL Workbench, conectado como **root**, abra e execute
   `banco/zenith_completo.sql`. Ele cria a estrutura (tabelas, gatilhos e
   views), carrega os dados fictícios e roda as consultas de conferência.
2. Abra `banco/zenith_permissoes.sql`, troque cada `TROQUE_ESTA_SENHA` por uma
   senha própria e execute como root. Isso cria os usuários do MySQL
   `zenith_app` (aplicativo) e `zenith_bi` (Power BI, só leitura). Não salve o
   arquivo com as senhas.

## Criar usuários do sistema

O script do banco **não** cria usuários do sistema. Para criar o primeiro
Gerente (e os demais usuários):

```
python criar_usuario.py
```

O script pede nome, e-mail e perfil (Gerente, Atendente ou Profissional). A
senha é digitada sem aparecer, precisa ter pelo menos 10 caracteres e é guardada
só como hash bcrypt.

## Iniciar

Dê dois cliques em `iniciar.bat` (ou rode `python main.py`) e entre com o e-mail
e a senha criados.

## Testes

`testar.bat` roda todos os testes. Os que gravam dados usam só o schema
separado `zenith_teste` (criado por `banco/teste/zenith_banco_teste.sql`) e
apagam o que criam.

## Estrutura de pastas

```
.
├── main.py                 ponto de entrada (abre a janela)
├── config.py               lê a conexão do .env
├── interface/              telas (CustomTkinter), componentes e tema visual
│   └── telas/              login, início, pacientes, atendimentos, cadastros,
│                           insumos, financeiro e dashboard
├── servicos/               regras de negócio (login, perfis, atendimentos, estoque...)
├── repositorios/           acesso ao banco (somente SQL parametrizado)
├── validacoes/             CPF, CNPJ, CEP, telefone, datas e valores
├── database/               conexão com o MySQL
├── banco/
│   ├── zenith_completo.sql     criação + população + consultas (rodar como root)
│   ├── zenith_permissoes.sql   usuários do MySQL (senhas a preencher)
│   ├── historico/              fontes do script completo (estrutura, dados, consultas)
│   └── teste/                  scripts do schema de testes zenith_teste
├── docs/                   documentação, entrega, modelo de dados, Power BI e prints
├── assets/                 logos, ícone e fonte Montserrat
├── popular_gerar.py        gera os dados fictícios (semente fixa)
├── gerar_sql_completo.py   monta banco/zenith_completo.sql a partir das fontes
├── criar_usuario.py        cria usuários do sistema
└── teste_*.py              testes automatizados
```

## Documentação

- [Requisitos e orientações dos professores](docs/requisitos_professores.md)
- [Entrega 2](docs/entrega2.md)
- [Modelo de dados (DER, cardinalidades, dicionário)](docs/modelo_dados.md)
- [Views e medidas do Power BI](docs/powerbi_views.md)
- [Resultados das consultas](docs/resultados_consultas.md) e [prints](docs/prints/)
