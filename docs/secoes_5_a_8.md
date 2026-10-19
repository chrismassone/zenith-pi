# Relatório - Seções 5 a 8 (texto atualizado pelo novo modelo)

> Os títulos das seções abaixo são uma SUPOSIÇÃO: o documento original do
> relatório não estava disponível. Ajuste a numeração e os títulos ao modelo
> da FATEC antes de colar. O texto não trata de normalização, conforme pedido.

## 5. Modelo conceitual

O banco de dados do Zenith foi modelado a partir das atividades do consultório
da Dra. Gabriela Saraiva: cadastro de pacientes, agenda e registro dos
atendimentos em três unidades, controle dos insumos usados nos procedimentos e
acompanhamento financeiro.

As entidades principais são PACIENTE, PROFISSIONAL, UNIDADE, PROCEDIMENTO,
ATENDIMENTO, INSUMO, FORNECEDOR, USUARIO, ANAMNESE e LANCAMENTO. Os atributos de
cada uma estão listados dentro do retângulo da entidade no Diagrama
Entidade-Relacionamento (DER), sem o uso de elipses.

Três relacionamentos têm atributos próprios e, por isso, aparecem no DER como
entidades associativas:

- **ATENDIMENTO_PROCEDIMENTO** (Atendimento x Procedimento): registra cada
  procedimento realizado em um atendimento, com região aplicada, quantidade e
  valor cobrado.
- **COMPRA** (Fornecedor x Insumo): cada compra é uma entrada de estoque, com
  data, quantidade, preço unitário, lote e validade. O relacionamento é N:M,
  porque o mesmo insumo pode ser comprado de fornecedores diferentes ao longo do
  tempo. Assim, lote, validade e preço deixam de ser atributos do insumo e
  passam a pertencer a cada compra.
- **CONSUMO** (Insumo x Atendimento): cada consumo é uma saída de estoque com a
  quantidade realmente usada. Quando não há atendimento (perda, descarte ou
  vencimento), o consumo é avulso e o motivo é obrigatório.

A antiga entidade de movimentação de estoque foi substituída por COMPRA e
CONSUMO. Com isso, a movimentação passa a ser representada por relacionamentos
entre as entidades envolvidas, como recomendado na avaliação do modelo.

Para responder quanto cada procedimento consome de insumo, foi criado o
relacionamento **PROCEDIMENTO_INSUMO** (Procedimento x Insumo), com a quantidade
padrão de cada insumo por procedimento. Esse valor é uma sugestão inicial: a
profissional pode alterá-lo no cadastro do procedimento e ajustá-lo em cada
atendimento antes de confirmar. O consumo registrado guarda sempre a quantidade
real, e alterar a quantidade padrão não muda os consumos passados.

As cardinalidades mínimas e máximas de todos os relacionamentos, no formato
(min,max), estão na tabela da seção 2 de `docs/modelo_dados.md`, junto com a
justificativa de cada mínima. Exemplos: um paciente realiza (0,n) atendimentos,
porque pode estar cadastrado sem ter sido atendido; cada atendimento pertence a
(1,1) paciente.

## 6. Modelo lógico e físico

O modelo foi implementado no MySQL 8 com o conjunto de caracteres utf8mb4, que
aceita acentos e qualquer caractere de uma futura versão web. Todas as tabelas
usam chave primária substituta inteira (`id_...`), com exceção de
PROCEDIMENTO_INSUMO, cuja chave é composta pelos identificadores do procedimento
e do insumo.

As regras de integridade ficam no próprio banco, e não apenas no aplicativo:

- chaves estrangeiras em todos os relacionamentos;
- restrições UNIQUE para CPF, CNPJ, e-mail de usuário e nomes de unidade e
  procedimento;
- restrições CHECK para formatos (CPF com 11 dígitos, CEP com 8, CNPJ com 14),
  situações válidas do atendimento, formas de pagamento, perfis de usuário,
  valores não negativos e validade posterior à compra;
- gatilhos (triggers) que impedem que qualquer consumo deixe o saldo de um
  insumo negativo, mesmo que a gravação venha de fora do aplicativo.

Pensando na versão web futura, todas as tabelas têm as colunas `criado_em` e
`atualizado_em`. Os cadastros nunca são apagados: são inativados pela coluna
`ativo`. A senha dos usuários é guardada só como hash bcrypt. O usuário do
aplicativo no MySQL (zenith_app) tem permissão de consultar, incluir e alterar
dados, mas não pode apagar cadastros nem alterar a estrutura. A única exceção é
o DELETE em duas tabelas de detalhe (itens do atendimento e insumos padrão do
procedimento), necessário para editar essas listas.

Valores calculados não são armazenados, e sim obtidos por visões (views):

- o valor do atendimento (soma dos procedimentos menos o desconto);
- o saldo de cada insumo (compras menos consumos);
- os alertas de validade;
- os indicadores do painel gerencial.

O dicionário de dados completo da entidade PACIENTE e o esquema de relações
estão em `docs/modelo_dados.md`.

## 7. Consultas e relatórios

As consultas que atendem aos requisitos de agenda, retornos, financeiro e
estoque estão em `zenith_consultas.sql`, numeradas e comentadas. São 20
consultas, entre elas:

- agenda por unidade e período;
- retornos pendentes (prazo de retorno vencido sem novo agendamento);
- faturamento, custo de locação e margem por unidade e mês;
- faturamento por procedimento e ticket médio;
- pacientes por cidade e bairro;
- taxa de comparecimento;
- estoque atual e alertas de validade;
- custo de insumos por procedimento;
- ranking da origem de captação;
- novos pacientes por mês.

Há consultas com junção de três ou mais tabelas, com subconsultas (inclusive
correlacionadas) e com agrupamento filtrado por HAVING.

Os indicadores gerenciais usam as mesmas visões no aplicativo (tela Dashboard)
e no Power BI. Com isso, os números são idênticos nos dois lugares. Um teste
automatizado compara cada indicador da tela com um cálculo independente feito
direto nas tabelas. A relação entre visões e visuais do Power BI está em
`docs/powerbi_views.md`.

Só atendimentos com situação Realizado contam como faturamento; faltas e
cancelamentos nunca entram. O custo de locação foi calculado como o valor diário
da unidade multiplicado pelos dias com atendimento realizado no mês. Essa regra
é uma SUPOSIÇÃO ainda não confirmada pela cliente e pode ser trocada alterando
uma única visão.

## 8. Implementação do sistema

O sistema é um aplicativo desktop em Python com interface CustomTkinter,
organizado em camadas:

- **interface** (telas): só exibe dados e repassa o que o usuário digita;
- **serviços**: contêm as regras de negócio e podem ser reaproveitados por uma
  futura API web;
- **repositórios**: contêm apenas comandos SQL parametrizados.

O acesso exige login com e-mail e senha. Depois de cinco tentativas erradas o
acesso fica bloqueado temporariamente, e a sessão expira após 30 minutos sem
uso. Cada perfil vê apenas os módulos permitidos:

- **Gerente:** acesso a todos os módulos;
- **Atendente:** Pacientes, Atendimentos, Procedimentos e Insumos, além de
  Unidades só para consulta;
- **Profissional:** Pacientes, Atendimentos e anamnese.

As telas seguem a identidade visual da marca (menu creme, dourado como acento,
fonte Montserrat). Todas oferecem busca, filtros, validação com mensagens
claras, estado vazio e inativação de registros. As principais são:

- Pacientes, com ficha, anamnese e histórico de atendimentos;
- Atendimentos, com procedimentos, desconto e forma de pagamento; ao marcar um
  atendimento como realizado, a tela mostra os insumos sugeridos com a
  quantidade editável e bloqueia o registro se faltar saldo;
- Procedimentos, com a lista de insumos padrão;
- Unidades;
- Insumos, com estoque, compras, consumo avulso e fornecedores;
- Financeiro e Dashboard, com gráficos.

O banco foi populado com dados exclusivamente fictícios, gerados por um script
determinístico. São mais de 100 registros em cada uma das tabelas principais:
120 ou mais pacientes, 250 atendimentos, 300 itens de atendimento, 100 compras
e 150 consumos. Consultas de verificação confirmam que não há saldo negativo,
referência órfã nem receita de atendimentos não realizados.
