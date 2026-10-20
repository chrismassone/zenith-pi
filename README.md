# Zenith

Sistema desktop para o consultório de harmonização orofacial da
Dra. Gabriela Saraiva. Projeto Integrador da FATEC.

Cadastro de pacientes (com anamnese e histórico), agenda e atendimentos nas três
unidades, procedimentos com os insumos que cada um consome, estoque (compras,
consumo e validade), financeiro e um painel com os mesmos números do Power BI.

Todos os dados do repositório são fictícios.

## Entrega de Banco de Dados

- **[`banco/`](banco/)**: script SQL de criação, população e consultas, e a
  verificação dos requisitos (5+ tabelas, tabela principal com 100+ linhas).
  Comece pelo [`banco/README.md`](banco/README.md).
- [Modelo de dados e correções pedidas pelo professor](docs/banco_de_dados.md)
- [Requisitos e orientações dos professores](docs/requisitos_professores.md)
- [Power BI: views e medidas](docs/powerbi.md)

## Requisitos

- Windows
- Python 3.14
- MySQL 8.0.47 (e o MySQL Workbench)

## Instalação

1. Rode `instalar.bat` (ou `python -m pip install -r requirements.txt`).
2. Copie `.env.example` para `.env` e preencha os dados do usuário `zenith_app`.
   O `.env` não vai para o Git.

## Banco de dados

`banco/zenith_completo.sql` apaga e recria o schema `zenith`. Se houver dados a
manter, faça backup antes:

```
mysqldump -u root -p --routines --triggers --databases zenith > zenith_backup.sql
```

1. No Workbench, como root, execute `banco/zenith_completo.sql`.
2. Em `banco/permissoes.sql`, troque `TROQUE_ESTA_SENHA` pelas senhas de
   `zenith_app` (a mesma do `.env`) e `zenith_bi` (Power BI) e execute como root.

## Usuários do sistema

O script do banco não cria usuários. Para criar o primeiro Gerente:

```
python criar_usuario.py
```

A senha é digitada sem aparecer na tela e guardada só como hash (bcrypt).

## Uso

Rode `iniciar.bat` (ou `python main.py`) e entre com e-mail e senha.

## Testes

`testar.bat` roda todos. Os que gravam usam o schema separado `zenith_teste`
(criado por `banco/teste/zenith_banco_teste.sql`) e apagam o que criam.

## Estrutura

```
main.py, config.py, criar_usuario.py, *.bat
interface/     telas e componentes (CustomTkinter)
servicos/      regras de negócio
repositorios/  acesso ao banco (SQL parametrizado)
validacoes/    CPF, CNPJ, CEP, telefone, datas e valores
database/      conexão
assets/        logos, ícone e fonte
banco/         scripts SQL da entrega, verificação dos requisitos e permissões
ferramentas/   geração e conferência dos dados, figuras das consultas
testes/        testes automatizados
docs/          material da disciplina e Power BI
```

Para regenerar `banco/zenith_completo.sql` depois de mudar `1_criacao.sql`,
`2_populacao.sql` ou `3_consultas.sql`:

```
python -m ferramentas.gerar_sql_completo
```
