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

## Banco na nuvem (TiDB Cloud)

Com o banco no TiDB Cloud, o aplicativo e o Power BI funcionam de qualquer
lugar, sem o MySQL instalado. Os scripts ficam em `banco/tidb/`: são os mesmos
dados e as mesmas views, mas sem os gatilhos (a regra do saldo fica no
aplicativo) e com a data de Brasília.

1. Em [tidbcloud.com](https://tidbcloud.com), crie um cluster **Starter** na
   região mais próxima (São Paulo, se houver).
2. No botão **Connect** do cluster, anote host, porta (4000) e o prefixo do
   usuário (ex.: `3xYz.root`), e baixe o certificado CA (`isrgrootx1.pem`).
   Guarde o certificado fora do repositório.
3. Rode `banco/tidb/zenith_completo_tidb.sql` com o usuário administrador, pelo
   **SQL Editor** do console ou pelo MySQL Workbench (porta 4000, aba SSL com
   *Use SSL: Require and Verify Identity* e o arquivo CA). A conferência no
   fim deve mostrar `check_ligado = 1`, 14 tabelas e 12 views.
4. Em `banco/tidb/permissoes_tidb.sql`, troque `PREFIXO` pelo prefixo do
   cluster e `TROQUE_ESTA_SENHA` pelas senhas, direto no editor (não salve o
   arquivo com as senhas), e execute.
5. No `.env`, use o bloco do TiDB do `.env.example`: host e porta do cluster,
   `DB_USER=PREFIXO.zenith_app`, `DB_SSL=on` e `DB_SSL_CA` com o caminho do
   certificado.
6. Rode `python -m testes.teste_conexao` para conferir.

Para voltar ao MySQL local basta usar de novo o bloco local no `.env`.

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
