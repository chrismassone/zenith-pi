# Banco de dados do Zenith: entrega

MySQL 8.0.47. Todos os dados são fictícios.

## Entregável: script SQL com a criação, população e consultas do BD

| Arquivo | O que tem |
|---|---|
| [`zenith_completo.sql`](zenith_completo.sql) | **Script entregue, completo**: criação, população e consultas, nessa ordem, em um arquivo só |
| [`1_criacao.sql`](1_criacao.sql) | Só a criação: 14 tabelas, chaves, CHECKs, índices, 3 gatilhos e 12 views |
| [`2_populacao.sql`](2_populacao.sql) | Só a população (dados fictícios) |
| [`3_consultas.sql`](3_consultas.sql) | Só as 20 consultas operacionais e gerenciais, comentadas |

Para rodar: no MySQL Workbench, conectado como root, abra
`zenith_completo.sql` e execute tudo. **O script apaga e recria o schema
`zenith`.**

## BD com pelo menos 5 tabelas e tabela principal com pelo menos 100 linhas

O arquivo [`4_verificacao_requisitos.sql`](4_verificacao_requisitos.sql)
confere os dois itens direto no banco. Resultado depois de rodar o script
completo:

| Requisito | Pedido | No banco |
|---|---|---|
| Tabelas | pelo menos 5 | **14** |
| Tabela principal | pelo menos 100 linhas | **paciente 126, atendimento 314** |

Linhas por tabela:

| Tabela | Linhas | Papel |
|---|---|---|
| paciente | 126 | principal |
| atendimento | 314 | principal |
| atendimento_procedimento | 383 | principal |
| compra | 146 | principal |
| consumo | 1.432 | principal |
| anamnese | 80 | apoio |
| lancamento | 89 | apoio |
| procedimento_insumo | 36 | apoio |
| insumo | 22 | apoio |
| procedimento | 7 | apoio |
| fornecedor | 4 | apoio |
| unidade | 3 | apoio |
| profissional | 1 | apoio |
| usuario | 0 | criados pelo aplicativo |

A figura com essa contagem está em
[`docs/prints/fig06_contagem.png`](../docs/prints/fig06_contagem.png).

## Consultas

| Nº | Consulta | Tipo |
|---|---|---|
| 01 | Agenda por unidade e período | operacional |
| 02 | Retornos pendentes | operacional |
| 03 | Faturamento, custo de locação, despesas e margem por unidade e mês | gerencial |
| 04 | Faturamento por procedimento no período | gerencial |
| 05 | Ticket médio por unidade | gerencial |
| 06 | Pacientes ativos por cidade e bairro | gerencial |
| 07 | Taxa de comparecimento por unidade | gerencial |
| 08 | Estoque atual com alerta de mínimo | operacional |
| 09 | Alertas de validade | operacional |
| 10 | Custo de insumos e margem por procedimento | gerencial |
| 11 | Ranking da origem de captação | gerencial |
| 12 | Novos pacientes por mês | gerencial |
| 13 | Histórico de atendimentos de um paciente | operacional |
| 14 | Consumo real x quantidade padrão de insumo | gerencial |
| 15 | Compras por fornecedor e insumo | operacional |
| 16 | Pacientes sem atendimento nos últimos 180 dias | gerencial |
| 17 | Procedimentos com faturamento acima da média | gerencial |
| 18 | Insumos com preço acima da média histórica | gerencial |
| 19 | Faturamento por forma de pagamento | gerencial |
| 20 | Faturamento mensal | gerencial |

Há consultas com JOIN de 3 ou mais tabelas (01, 13, 14, 15), subconsultas
(16, 17, 18) e GROUP BY com HAVING (06, 11, 17, 19). Os resultados das
consultas usadas nas figuras do relatório estão em [`docs/prints/`](../docs/prints/).

## Outros arquivos

| Arquivo | Uso |
|---|---|
| [`permissoes.sql`](permissoes.sql) | Usuários do MySQL para o aplicativo e o Power BI (trocar `TROQUE_ESTA_SENHA`) |
| [`consultas_figuras.sql`](consultas_figuras.sql) | Consultas que geram as figuras do relatório |
| [`teste/`](teste/) | O mesmo banco no schema `zenith_teste`, usado pelos testes automáticos |

Modelo de dados, cardinalidades e as correções pedidas pelo professor:
[`docs/banco_de_dados.md`](../docs/banco_de_dados.md).
