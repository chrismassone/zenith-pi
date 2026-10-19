# Zenith - Relatório de entrega (versão 2)

Data: 17/10/2026. Todos os dados de exemplo são fictícios.

## 1. O que foi entregue

| Fase | Situação |
|---|---|
| 0. Diagnóstico | Testes antigos passando; vocabulário extraído do script da colega; defeitos listados (seção 9) |
| 1. Banco v2 | `zenith_banco.sql` executado por você; `docs/modelo_dados.md` |
| 2. População | `popular_gerar.py` (semente fixa) gera `zenith_populacao.sql`; carregada e validada |
| 3. Consultas | `zenith_consultas.sql` (20 consultas); `docs/powerbi_views.md` |
| 4. Serviços e login | `servicos/`, `repositorios/`, bcrypt, bloqueio, perfis, sessão de 30 min, `criar_usuario.py` |
| 5. Telas | Login, Início, Pacientes, Atendimentos, Procedimentos, Unidades, Insumos, Financeiro |
| 6. Dashboard | Lê só as views; teste compara cada número com SQL independente |
| 7. Verificação | Testes automatizados, fluxo completo pela interface, capturas |

Contagens da população: paciente 126, atendimento 261, atendimento_procedimento 321,
compra 146, consumo 1.432, procedimento_insumo 36, insumo 22, fornecedor 4,
unidade 3, profissional 1, anamnese 80, lançamento 89.

## 2. Arquivos

**Criados**
- **Banco e dados:**
  - `popular_gerar.py`, `zenith_populacao.sql`, `popular_validar.py`;
  - `gerar_banco_teste.py`, `zenith_banco_teste.sql`, `banco_teste.py`;
  - `zenith_consultas.sql`, `consultas_executar.py`.
- **Serviços:** `servicos/` (`autenticacao`, `sessao`, `permissoes`, `erros`, `validador`,
  `base`, `pacientes`, `cadastros`, `atendimentos`, `estoque`, `relatorios`).
- **Repositórios:** `repositorios/` com `base`, `usuario`, `profissional`, `cadastros`,
  `atendimento`, `estoque`, `relatorios`.
- **Validação:** `validacoes/valores.py`.
- **Telas:** `interface/telas/` com `base`, `login`, `inicio`, `cadastros`, `atendimentos`,
  `insumos`, `financeiro`, `dashboard`.
- **Usuários:** `criar_usuario.py`.
- **Testes:** `teste_login.py`, `teste_servicos.py`, `teste_dashboard.py`,
  `teste_fluxo_interface.py`, `fluxo_util.py`.
- **Documentação:** `docs/modelo_dados.md`, `docs/powerbi_views.md`, `docs/secoes_5_a_8.md`,
  `docs/entrega.md`.

**Alterados**
- **Banco:** `zenith_banco.sql` (v2).
- **Interface:** `interface/app.py`, `tema.py`, `componentes.py`, `formatos.py`,
  `telas/pacientes.py`.
- **Repositório e validação:** `repositorios/paciente.py`, `validacoes/documentos.py`.
- **Testes:** `teste_formatos.py`, `teste_paciente.py`, `teste_fluxo_pacientes.py`.
- **Apoio:** `testar.bat`, `LEIA-ME.txt`, `requirements.txt` (bcrypt, matplotlib).

## 3. Como rodar do zero

1. **Backup** (Prompt de Comando, na pasta `bin` do MySQL):
   `mysqldump -u root -p --routines --triggers --databases zenith > "%USERPROFILE%\Documents\zenith_backup.sql"`
2. **No Workbench, como root:**
   - executar `zenith_banco.sql` (apaga e recria o banco);
   - executar o bloco de GRANTs da seção 6 do script;
   - executar os dois GRANTs de DELETE só nas tabelas de detalhe (estão no `LEIA-ME.txt`);
   - executar `zenith_populacao.sql`.
3. **Testes (opcional):** executar `zenith_banco_teste.sql` como root e depois
   `python banco_teste.py carregar`.
4. **Primeiro usuário:** `python criar_usuario.py`. A senha é digitada sem aparecer
   na tela e precisa ter no mínimo 10 caracteres.
5. **Abrir:** `iniciar.bat` (ou `python main.py`).
6. **Testar tudo:** `testar.bat`.

## 4. O que foi testado

| Teste | Resultado |
|---|---|
| teste_validacoes (CPF, CEP, telefone) | 15/15 |
| teste_formatos (formatação e conversões) | 37/37 |
| teste_login (bcrypt, mensagem genérica, bloqueio após 5 erros, expiração de 30 min, Sair, perfis) | 28/28 |
| teste_servicos (consumo com quantidade ajustada, saldo negativo bloqueado no serviço e no banco, padrão alterado não muda o passado, regras do atendimento, consumo avulso, permissões) | 27/27 |
| teste_dashboard (cada número da tela comparado com cálculo direto nas tabelas; 4 combinações de filtro) | 44/44 |
| teste_fluxo_pacientes (interface: login, cadastro, busca, edição, CPF inválido e duplicado, diálogo de inativar com Esc e Enter, reativar, anamnese, histórico, menus por perfil, expiração) | 21/21 |
| teste_fluxo_interface (interface: atendimentos, preço de tabela, total, confirmação de insumos com quantidade editada, saldo insuficiente, procedimento com insumos, unidades, compra, consumo avulso, lançamento, dashboard filtrado, Atendente só leitura em Unidades) | 18/18 |
| popular_validar (sanidade: metas, saldo nunca negativo, FKs, Realizado com item, Faltou/Cancelado sem receita, gatilho de saldo) | Tudo certo |
| teste_paciente / 20 consultas como zenith_app | OK / 20 executadas |

- Os testes que gravam usam só o banco `zenith_teste` e apagam o que criam. Conferi
  que ele volta exatamente à carga original.
- A rolagem do mouse foi testada com giros reais da roda sobre uma lista longa.

**Visual (conferido nas capturas):**
- Login igual ao template.
- Início com os cartões na largura toda.
- Formulários com Salvar e Cancelar em rodapé fixo e visível.
- Diálogo de inativar com o visual do sistema e centralizado.
- Confirmação de insumos editável.
- Financeiro com cartões, tabela e barras.
- Dashboard com gráficos nas cores da marca.
- Ajustes visuais da última rodada: fonte Medium/SemiBold maior; contornos de 2 px
  nítidos; seletor próprio com borda contínua e texto inteiro.

## 5. O que NÃO foi testado

- Uso real com mouse e teclado por uma pessoa: os testes acionam as telas por código.
- O tamanho exato de 1280x720: esta tela equivale a cerca de 1200x700 com o zoom de
  150%. Testei com a janela maximizada, que é como o app abre.
- A conexão do Power BI às views.
- A queda do MySQL durante o uso: a mensagem amigável existe no código, mas não
  desliguei o servidor para ver.
- Uma vez apareceu um erro interno do componente de rolagem do CustomTkinter (um
  `lambda` chamado sem argumento). Não se repetiu em três rodadas e a causa não foi
  identificada.

## 6. Decisões tomadas sozinho

- Fornecedores ficam numa aba da tela Insumos.
- O usuário pode ser ligado a um cadastro de profissional (coluna opcional).
- Um atendimento Realizado não muda mais de situação.
- Gatilhos no banco impedem saldo negativo.
- DELETE liberado só em `atendimento_procedimento` e `procedimento_insumo`
  (aprovado por você).
- Os testes usam o banco separado `zenith_teste` (opção A, aprovada por você).
- O desconto não deixa o atendimento negativo.
- Rolagem e seletor próprios, no lugar dos do CustomTkinter.
- Correção da detecção da Montserrat: antes ela nunca era usada.

## 7. SUPOSIÇÕES (a confirmar com a Dra. Gabriela)

- **Locação:** custo = valor por dia x dias com atendimento realizado no mês; valores
  de R$ 350, R$ 400 e R$ 250.
- **Cadastros fictícios:** preços de tabela, intervalos de retorno, quantidades padrão
  de insumo e preços de compra.
- **Validade:** sem controle por lote (FIFO); o alerta usa o saldo do insumo inteiro.
- **Margem:** faturamento − locação − despesas lançadas para a unidade.
- **Retorno:** conta como retorno um atendimento agendado ou realizado depois do último
  procedimento. Cancelamentos não entram na taxa de comparecimento.
- **Login:** bloqueio de 15 minutos.
- **Atendimento:** forma de pagamento obrigatória quando Realizado.
- **Anamnese:** a Atendente não vê.
- **Agenda:** sem atendimento nos fins de semana (só na população fictícia).

## 8. Pendências

- Confirmar com a cliente as suposições da seção 7 e as perguntas de
  `docs/modelo_dados.md`.
- Ajustar os títulos de `docs/secoes_5_a_8.md` ao modelo do relatório da FATEC e
  conferir a associação das consultas a RF03, RF07, RF08 e RF09.
- A população não tem agendamentos para a semana de 16/10, então os cartões
  "hoje" e "semana" do Início mostram zero.
- Criar um usuário só de leitura para o Power BI (`docs/powerbi_views.md`).
- Commit e push das mudanças (aguardando sua autorização).

## 9. Defeitos do script da colega (para repassar)

- Erro de sintaxe (`,;` no fim de atendimento_procedimento).
- CNPJ, CEP e telefone gravados como número: perdem o zero à esquerda, e
  `04101000` reprova no próprio CHECK.
- Cidade com UF junto ("São Paulo, SP").
- Fornecedores com nome e CNPJ de empresas reais.
- E-mails `@email.com` com cara de dado real.
- `valor_total` guardado na tabela e somando Faltou e Cancelado.
- Nomes de procedimento sem acento.
- Valor de locação com 0,00.

## 10. Telas para os prints do relatório

1. Login.
2. Início.
3. Pacientes: lista e busca.
4. Ficha do paciente com as abas Dados, Anamnese e Histórico.
5. Mensagens de validação (campo obrigatório, CPF inválido e duplicado).
6. Diálogo de inativar.
7. Atendimentos: lista com filtros.
8. Formulário de atendimento com procedimentos e total.
9. Confirmação dos insumos usados.
10. Saldo insuficiente.
11. Procedimento com insumos padrão.
12. Unidades (Gerente e Atendente).
13. Insumos: Estoque com alertas.
14. Insumos: Compras e consumos.
15. Insumos: Fornecedores.
16. Financeiro: resumo.
17. Financeiro: lançamentos.
18. Dashboard: cartões.
19. Dashboard: gráficos.
20. Menu do perfil Profissional.
