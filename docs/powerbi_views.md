# Zenith - Views para o Power BI

O Power BI e a tela Dashboard do aplicativo leem **as mesmas views**. Por isso
os números são idênticos nos dois lugares. Nenhum cálculo de negócio deve ser
refeito no Power BI. As views já aplicam as regras:

- só atendimentos **Realizado** contam como faturamento (Faltou e Cancelado nunca);
- o valor do atendimento é a soma dos itens menos o desconto;
- o custo de locação segue a SUPOSIÇÃO documentada em `vw_dash_unidade`.

## Conexão

1. Power BI Desktop > Obter dados > Banco de dados MySQL.
2. Servidor `127.0.0.1:3306`, banco `zenith`.
3. Credenciais: um usuário **só de leitura** (recomendado), criado por você
   como root, por exemplo:
   ```sql
   CREATE USER 'zenith_bi'@'localhost' IDENTIFIED BY '<defina uma senha>';
   GRANT SELECT ON zenith.* TO 'zenith_bi'@'localhost';
   ```
   Não use o root e não grave a senha em nenhum arquivo do projeto.
4. Selecione apenas as views `vw_*` listadas abaixo.

## Relacionamentos sugeridos no modelo do Power BI

- Tabela de calendário (Power BI) `ano_mes` -> `ano_mes` das views mensais.
- `unidade` (ou a coluna `id_unidade`) -> `id_unidade` das views.
- `procedimento` -> `id_procedimento` de `vw_dash_procedimento` e `vw_custo_procedimento`.

## Views, colunas e visuais

| View | Colunas | Visual que alimenta |
|---|---|---|
| **vw_dash_kpis_mensal** | ano_mes, id_unidade, nome_clinica, realizados, faltas, cancelados, agendados, faturamento, ticket_medio, pacientes_atendidos | Cartões **Faturamento total** (soma de faturamento) e **Ticket médio** (soma de faturamento / soma de realizados; não use média de ticket_medio). **Linha do faturamento mensal** (eixo ano_mes, valor faturamento). |
| **vw_dash_unidade** | ano_mes, id_unidade, nome_clinica, faturamento, dias_com_atendimento, custo_locacao, despesas, margem | **Colunas agrupadas Faturamento x Custo por unidade** (eixo nome_clinica; valores faturamento e custo_locacao + despesas). Cartões **Faturamento por unidade** e **Margem líquida** (soma de margem). Tabela financeira por unidade e mês. |
| **vw_dash_procedimento** | ano_mes, id_unidade, id_procedimento, nome_procedimento, quantidade_realizada, faturamento | **Rosca (donut) do faturamento por procedimento** (legenda nome_procedimento, valores faturamento). Segmentação **Procedimento**. |
| **vw_dash_retorno** | id_paciente, nome_completo, telefone_paciente, id_procedimento, nome_procedimento, id_unidade, ultima_data, data_retorno_prevista, retornou, vencido | Cartões **Retornos pendentes**, **Retornos vencidos** e **Taxa de retorno** (medidas DAX da seção "Regra de retorno"). **Tabela de retornos pendentes** (filtro vencido = 1 e retornou = 0). |
| **vw_dash_comparecimento** | ano_mes, id_unidade, realizados, faltas, taxa_comparecimento | Cartão **Taxa de comparecimento** = soma de realizados / (soma de realizados + soma de faltas). Pode virar linha mensal. |
| **vw_dash_pacientes_cidade_bairro** | cidade, bairro, pacientes_ativos, pacientes_total | **Barras de pacientes por cidade/bairro** (hierarquia cidade > bairro). Cartão **Pacientes ativos** (soma de pacientes_ativos). |
| **vw_estoque_atual** | id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo, ativo, total_comprado, total_consumido, saldo, abaixo_minimo | **Tabela de alertas de estoque** (filtro abaixo_minimo = 1). Cartão "Itens abaixo do mínimo". |
| **vw_alerta_validade** | id_compra, id_insumo, nome_insumo, marca, unidade_medida, lote, data_compra, data_validade, dias_para_vencer, vencido, quantidade_comprada, saldo_insumo | **Tabela de validade** (ordenar por data_validade; formatação condicional em vencido). |
| **vw_faturamento** | id_atendimento, id_paciente, id_unidade, nome_clinica, data_atendimento, ano_mes, forma_pagamento, subtotal, desconto, valor_total | Detalhamento (drill-through) e gráfico por forma de pagamento. |
| **vw_valor_atendimento** | id_atendimento, id_paciente, id_unidade, id_profissional, data_hora, status, forma_pagamento, subtotal, desconto, valor_total, qtd_itens | Apoio: atendimentos de todos os status, com valor calculado. |
| **vw_custo_procedimento** | id_procedimento, nome_procedimento, preco_tabela, custo_insumos, margem_estimada, qtd_insumos, insumos_sem_preco | Barras de **margem estimada por procedimento**. |
| **vw_preco_insumo_atual** | id_insumo, preco_unitario, data_compra | Apoio para custo de insumos. |

## Regra de retorno (única: view, app, consultas e Power BI)

Por paciente ativo e procedimento com `intervalo_retorno_dias` definido:

| Termo | Definição |
|---|---|
| data_retorno_prevista | data do último procedimento Realizado + intervalo de retorno |
| retornou | existe atendimento Agendado ou Realizado do paciente depois da data do último procedimento |
| vencido | data_retorno_prevista **<** hoje (estritamente antes; hoje ainda não está vencido) |
| pendente | vencido **E** não retornou. Retorno ainda não vencido **não** é pendente |
| taxa de retorno | vencidos que retornaram ÷ vencidos |

A view `vw_dash_retorno` já entrega a coluna `vencido` calculada com `< CURDATE()`.
**No Power BI, não recalcule com `TODAY()`**: use a coluna `vencido` da view. Uma
medida com `<= TODAY()` conta como vencido o retorno previsto para hoje e diverge
do aplicativo.

**Por que apareciam 107 "pendentes":** a medida contava todo par
paciente/procedimento com `retornou = 0`, inclusive retornos que ainda não
venceram (datas previstas até julho de 2027). Pela regra única, pendente exige
`vencido = 1`. No banco de trabalho, antes da agenda futura: 107 sem retorno,
mas só 24 pendentes vencidos. Com a agenda futura (53 Agendado novos), 13
pendentes vencidos e taxa de 81,4%.

### Medidas DAX

No modelo, as colunas booleanas do MySQL chegam como número inteiro (0/1).
Se aparecerem como Verdadeiro/Falso, troque `= 1` por `= TRUE()` e `= 0` por
`= FALSE()`.

```DAX
Retornos vencidos =
CALCULATE (
    COUNTROWS ( 'zenith vw_dash_retorno' ),
    'zenith vw_dash_retorno'[vencido] = 1
)

Retornos pendentes =
CALCULATE (
    COUNTROWS ( 'zenith vw_dash_retorno' ),
    'zenith vw_dash_retorno'[vencido] = 1,
    'zenith vw_dash_retorno'[retornou] = 0
)

Retornos vencidos que retornaram =
CALCULATE (
    COUNTROWS ( 'zenith vw_dash_retorno' ),
    'zenith vw_dash_retorno'[vencido] = 1,
    'zenith vw_dash_retorno'[retornou] = 1
)

Taxa de retorno =
DIVIDE ( [Retornos vencidos que retornaram], [Retornos vencidos] )
```

A taxa é sempre `DIVIDE` de contagens. Nunca some nem tire média de taxas
(por unidade ou por mês): com filtros, o Power BI recalcula a divisão no
contexto certo.

## Agenda futura

A população inclui 64 atendimentos Agendado em 15 dias úteis, de 19/10/2026 a
09/11/2026, sem fins de semana e sem o feriado de 02/11/2026 (Finados). São de 2
a 5 por dia, exceto 19/10, que já tinha 7 na carga original. Agendados não têm
valor faturado, forma de pagamento nem consumo de insumo. Eles aparecem na agenda
(consulta [01]) e contam como "retornou" para quem tinha retorno pendente.

## Filtros (segmentações) usados no dashboard

- **Unidade**: `id_unidade`, presente em todas as views mensais e em `vw_dash_retorno`.
- **Período**: `ano_mes` (ou `data_atendimento` em `vw_faturamento`).
- **Procedimento**: `id_procedimento` em `vw_dash_procedimento` e `vw_dash_retorno`.
  As views de unidade e KPIs não têm procedimento. Com esse filtro, o
  aplicativo recalcula o faturamento a partir de `vw_dash_procedimento`;
  no Power BI use a mesma view.

## Atenção

- **Taxas e médias:** some numeradores e denominadores. Nunca tire a média de
  uma coluna que já é taxa ou média.
- **Custo de locação:** é SUPOSIÇÃO (valor por dia com atendimento). Se a
  cliente confirmar outra regra, muda só a view `vw_dash_unidade` e o Power BI
  acompanha sozinho.
