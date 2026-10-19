-- ============================================================
-- ZENITH - SCRIPT COMPLETO (gerado por gerar_sql_completo.py em
-- 19/10/2026 20:49; nao edite a mao)
--
-- ############################################################
-- ##  AVISO: ESTE SCRIPT APAGA E RECRIA O SCHEMA `zenith`.  ##
-- ##  TODOS OS DADOS ATUAIS DE `zenith` SERAO PERDIDOS.      ##
-- ##  FACA O BACKUP ANTES (mysqldump; docs/entrega2.md). ##
-- ############################################################
--
-- O que e: estrutura + dados ficticios + consultas do Zenith, em um
-- unico arquivo, para rodar de ponta a ponta no MySQL Workbench como root.
-- Ordem:
--   1. Criacao (zenith_banco.sql sem a secao de permissoes): tabelas,
--      indices, gatilhos (com DELIMITER) e views.
--   2. Populacao (zenith_populacao.sql): dados 100% ficticios, numa
--      transacao (START TRANSACTION ... COMMIT).
--   3. Consultas (zenith_consultas.sql): 20 consultas de conferencia.
--   4. COMMIT final.
--
-- Contagens finais esperadas por tabela:
--   anamnese                      80
--   atendimento                  314
--   atendimento_procedimento     383
--   compra                       146
--   consumo                     1432
--   fornecedor                     4
--   insumo                        22
--   lancamento                    89
--   paciente                     126
--   procedimento                   7
--   procedimento_insumo           36
--   profissional                   1
--   unidade                        3
--   usuario                        0
--
-- Os USUARIOS DO SISTEMA NAO estao neste script. Depois de rodar, crie o
-- primeiro Gerente com:  python criar_usuario.py
-- (a senha e digitada sem aparecer e guardada so como hash bcrypt).
-- As permissoes do MySQL estao a parte, em zenith_permissoes.sql.
-- ============================================================

-- ====================== 1. CRIACAO ======================
-- ============================================================
-- ZENITH - Projeto Integrador (FATEC)
-- Banco de dados: clinica de harmonizacao orofacial - Dra. Gabriela Saraiva
-- SGBD: MySQL 8.0.16+ (necessario para o CHECK ser aplicado)
-- Versao do script: 2.0
--
-- O QUE MUDOU EM RELACAO A 1.0
--   * movimentacao_estoque foi substituida por duas entidades associativas:
--       compra  (Fornecedor x Insumo)  -> entrada de estoque, N:M
--       consumo (Insumo x Atendimento) -> saida de estoque (avulsa se sem atendimento)
--   * procedimento_insumo (Procedimento x Insumo): quanto cada procedimento
--     consome de cada insumo (quantidade padrao SUGERIDA, editavel).
--   * insumo perdeu fornecedor, lote, validade, preco e estoque atual
--     (lote/validade/preco ficam na compra; estoque e calculado por view).
--   * atendimento perdeu valor_total (calculado por view) e ganhou
--     forma_pagamento e desconto.
--   * Novas: usuario, anamnese, lancamento.
--   * criado_em / atualizado_em, exclusao logica (ativo), utf8mb4.
--   * Views para o aplicativo e para o Power BI.
--
-- ATENCAO: este script APAGA o banco zenith e o recria vazio.
-- Faca o backup antes (ver docs/modelo_dados.md, secao "Backup").
-- Os dados sao carregados depois por zenith_populacao.sql.
-- Execute como root no MySQL Workbench.
-- ============================================================

DROP DATABASE IF EXISTS zenith_teste;
CREATE DATABASE zenith_teste
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;
USE zenith_teste;

-- ------------------------------------------------------------
-- 1. TABELAS SEM DEPENDENCIA
-- ------------------------------------------------------------

CREATE TABLE unidade (
    id_unidade      TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome_clinica    VARCHAR(50)      NOT NULL,
    bairro_unidade  VARCHAR(40)      NOT NULL,
    cidade_unidade  VARCHAR(40)      NOT NULL,
    uf_unidade      CHAR(2)          NOT NULL,
    -- SUPOSICAO: valor da locacao por DIA de uso da sala (ver vw_dash_unidade).
    -- A regra de cobranca da locacao NAO foi confirmada pela cliente.
    valor_locacao   DECIMAL(10,2)    NOT NULL DEFAULT 0,
    ativo           BOOLEAN          NOT NULL DEFAULT TRUE,
    criado_em       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_unidade PRIMARY KEY (id_unidade),
    CONSTRAINT uq_unidade_nome UNIQUE (nome_clinica),
    CONSTRAINT ck_unidade_valor CHECK (valor_locacao >= 0),
    CONSTRAINT ck_unidade_uf CHECK (uf_unidade REGEXP '^[A-Z]{2}$')
) ENGINE=InnoDB;

CREATE TABLE profissional (
    id_profissional TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome_completo   VARCHAR(100)     NOT NULL,
    ativo           BOOLEAN          NOT NULL DEFAULT TRUE,
    criado_em       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_profissional PRIMARY KEY (id_profissional)
) ENGINE=InnoDB;

CREATE TABLE paciente (
    id_paciente       INT           NOT NULL AUTO_INCREMENT,
    nome_completo     VARCHAR(100)  NOT NULL,
    cpf               CHAR(11)      NOT NULL,
    data_nasc         DATE          NOT NULL,
    telefone_paciente VARCHAR(11)   NOT NULL,
    email_paciente    VARCHAR(100)  NULL,
    cep_paciente      CHAR(8)       NOT NULL,
    endereco_paciente VARCHAR(100)  NOT NULL,
    bairro_paciente   VARCHAR(40)   NOT NULL,
    cidade_paciente   VARCHAR(40)   NOT NULL,
    origem_captacao   VARCHAR(30)   NOT NULL,
    ativo             BOOLEAN       NOT NULL DEFAULT TRUE,
    criado_em         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_paciente PRIMARY KEY (id_paciente),
    CONSTRAINT uq_paciente_cpf UNIQUE (cpf),
    CONSTRAINT ck_paciente_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
    CONSTRAINT ck_paciente_cep CHECK (cep_paciente REGEXP '^[0-9]{8}$'),
    CONSTRAINT ck_paciente_telefone CHECK (telefone_paciente REGEXP '^[0-9]{10,11}$'),
    CONSTRAINT ck_paciente_email CHECK (email_paciente IS NULL
                                        OR email_paciente LIKE '%_@_%._%')
) ENGINE=InnoDB;

CREATE TABLE procedimento (
    id_procedimento         INT               NOT NULL AUTO_INCREMENT,
    nome_procedimento       VARCHAR(60)       NOT NULL,
    preco_tabela            DECIMAL(10,2)     NOT NULL,
    intervalo_retorno_dias  SMALLINT UNSIGNED NULL,   -- NULL = sem retorno previsto
    ativo                   BOOLEAN           NOT NULL DEFAULT TRUE,
    criado_em               DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em           DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP
                                              ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_procedimento PRIMARY KEY (id_procedimento),
    CONSTRAINT uq_procedimento_nome UNIQUE (nome_procedimento),
    CONSTRAINT ck_procedimento_preco CHECK (preco_tabela >= 0),
    CONSTRAINT ck_procedimento_retorno CHECK (intervalo_retorno_dias IS NULL
                                              OR intervalo_retorno_dias > 0)
) ENGINE=InnoDB;

CREATE TABLE fornecedor (
    id_fornecedor        INT          NOT NULL AUTO_INCREMENT,
    razao_social         VARCHAR(100) NOT NULL,
    cnpj                 CHAR(14)     NOT NULL,
    telefone_fornecedor  VARCHAR(11)  NOT NULL,
    cep_fornecedor       CHAR(8)      NOT NULL,
    endereco_fornecedor  VARCHAR(100) NOT NULL,
    bairro_fornecedor    VARCHAR(40)  NOT NULL,
    cidade_fornecedor    VARCHAR(40)  NOT NULL,
    ativo                BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                      ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_fornecedor PRIMARY KEY (id_fornecedor),
    CONSTRAINT uq_fornecedor_cnpj UNIQUE (cnpj),
    CONSTRAINT ck_fornecedor_cnpj CHECK (cnpj REGEXP '^[0-9]{14}$'),
    CONSTRAINT ck_fornecedor_cep CHECK (cep_fornecedor REGEXP '^[0-9]{8}$'),
    CONSTRAINT ck_fornecedor_telefone CHECK (telefone_fornecedor REGEXP '^[0-9]{10,11}$')
) ENGINE=InnoDB;

CREATE TABLE insumo (
    id_insumo       INT           NOT NULL AUTO_INCREMENT,
    nome_insumo     VARCHAR(60)   NOT NULL,
    marca           VARCHAR(40)   NOT NULL,
    apresentacao    VARCHAR(40)   NOT NULL,     -- ex.: 'Frasco 100U', 'Seringa 1,0 mL'
    unidade_medida  VARCHAR(10)   NOT NULL,     -- unidade do estoque: 'U', 'mL', 'frasco'...
    estoque_minimo  DECIMAL(10,2) NOT NULL DEFAULT 0,
    ativo           BOOLEAN       NOT NULL DEFAULT TRUE,
    criado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_insumo PRIMARY KEY (id_insumo),
    CONSTRAINT uq_insumo UNIQUE (nome_insumo, marca, apresentacao),
    CONSTRAINT ck_insumo_minimo CHECK (estoque_minimo >= 0)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 2. TABELAS COM DEPENDENCIA
-- ------------------------------------------------------------

CREATE TABLE usuario (
    id_usuario        INT              NOT NULL AUTO_INCREMENT,
    nome              VARCHAR(100)     NOT NULL,
    email             VARCHAR(100)     NOT NULL,
    senha_hash        VARCHAR(100)     NOT NULL,   -- bcrypt; nunca a senha em texto
    perfil            VARCHAR(15)      NOT NULL,
    -- Vinculo opcional: usuario com perfil Profissional aponta para o seu
    -- cadastro de profissional (usado na anamnese e nos atendimentos).
    id_profissional   TINYINT UNSIGNED NULL,
    ativo             BOOLEAN          NOT NULL DEFAULT TRUE,
    tentativas_falhas TINYINT UNSIGNED NOT NULL DEFAULT 0,
    bloqueado_ate     DATETIME         NULL,
    ultimo_acesso     DATETIME         NULL,
    criado_em         DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                       ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_email UNIQUE (email),
    CONSTRAINT fk_usuario_profissional FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional),
    CONSTRAINT ck_usuario_perfil CHECK (perfil IN ('Gerente', 'Atendente', 'Profissional')),
    CONSTRAINT ck_usuario_hash CHECK (senha_hash LIKE '$2%' AND CHAR_LENGTH(senha_hash) >= 59)
) ENGINE=InnoDB;

CREATE TABLE anamnese (
    id_anamnese          INT              NOT NULL AUTO_INCREMENT,
    id_paciente          INT              NOT NULL,
    id_profissional      TINYINT UNSIGNED NOT NULL,
    data_registro        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    queixa_principal     VARCHAR(500)     NOT NULL,
    historico_saude      TEXT             NULL,
    alergias             VARCHAR(500)     NULL,
    medicamentos_em_uso  VARCHAR(500)     NULL,
    observacoes          TEXT             NULL,
    criado_em            DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                          ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_anamnese PRIMARY KEY (id_anamnese),
    CONSTRAINT fk_anamnese_paciente FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente),
    CONSTRAINT fk_anamnese_profissional FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional)
) ENGINE=InnoDB;

CREATE TABLE atendimento (
    id_atendimento  INT              NOT NULL AUTO_INCREMENT,
    id_profissional TINYINT UNSIGNED NOT NULL,
    id_paciente     INT              NOT NULL,
    id_unidade      TINYINT UNSIGNED NOT NULL,
    data_hora       DATETIME         NOT NULL,
    status          VARCHAR(15)      NOT NULL DEFAULT 'Agendado',
    forma_pagamento VARCHAR(20)      NULL,          -- NULL enquanto nao pago
    desconto        DECIMAL(10,2)    NOT NULL DEFAULT 0,
    observacao      VARCHAR(255)     NULL,
    criado_em       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_atendimento PRIMARY KEY (id_atendimento),
    CONSTRAINT fk_atend_profissional FOREIGN KEY (id_profissional)
        REFERENCES profissional (id_profissional),
    CONSTRAINT fk_atend_paciente FOREIGN KEY (id_paciente)
        REFERENCES paciente (id_paciente),
    CONSTRAINT fk_atend_unidade FOREIGN KEY (id_unidade)
        REFERENCES unidade (id_unidade),
    CONSTRAINT ck_atend_status CHECK
        (status IN ('Agendado', 'Realizado', 'Cancelado', 'Faltou')),
    CONSTRAINT ck_atend_pagamento CHECK (forma_pagamento IS NULL OR forma_pagamento IN
        ('Pix', 'Cartão de crédito', 'Cartão de débito', 'Dinheiro')),
    CONSTRAINT ck_atend_desconto CHECK (desconto >= 0)
) ENGINE=InnoDB;

CREATE TABLE atendimento_procedimento (
    id_atend_proc       INT           NOT NULL AUTO_INCREMENT,
    id_atendimento      INT           NOT NULL,
    id_procedimento     INT           NOT NULL,
    quantidade_aplicada DECIMAL(6,2)  NOT NULL,
    regiao_aplicada     VARCHAR(30)   NOT NULL,
    valor_cobrado       DECIMAL(10,2) NOT NULL,
    criado_em           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                      ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_atend_proc PRIMARY KEY (id_atend_proc),
    CONSTRAINT fk_ap_atendimento FOREIGN KEY (id_atendimento)
        REFERENCES atendimento (id_atendimento),
    CONSTRAINT fk_ap_procedimento FOREIGN KEY (id_procedimento)
        REFERENCES procedimento (id_procedimento),
    CONSTRAINT ck_ap_qtd CHECK (quantidade_aplicada > 0),
    CONSTRAINT ck_ap_valor CHECK (valor_cobrado >= 0)
) ENGINE=InnoDB;

-- Procedimento x Insumo: quanto cada procedimento consome de cada insumo.
-- quantidade_padrao e um valor SUGERIDO, editavel pela profissional a
-- qualquer momento. Altera-lo NAO muda consumos ja registrados: o consumo
-- guarda a quantidade real usada.
CREATE TABLE procedimento_insumo (
    id_procedimento    INT           NOT NULL,
    id_insumo          INT           NOT NULL,
    quantidade_padrao  DECIMAL(10,2) NOT NULL,
    criado_em          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                     ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_procedimento_insumo PRIMARY KEY (id_procedimento, id_insumo),
    CONSTRAINT fk_pi_procedimento FOREIGN KEY (id_procedimento)
        REFERENCES procedimento (id_procedimento),
    CONSTRAINT fk_pi_insumo FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT ck_pi_qtd CHECK (quantidade_padrao > 0)
) ENGINE=InnoDB;

-- Fornecedor x Insumo (N:M): cada compra e uma entrada de estoque.
-- Lote, validade e preco pertencem a compra, nao ao insumo.
CREATE TABLE compra (
    id_compra       INT           NOT NULL AUTO_INCREMENT,
    id_fornecedor   INT           NOT NULL,
    id_insumo       INT           NOT NULL,
    data_compra     DATE          NOT NULL,
    quantidade      DECIMAL(10,2) NOT NULL,   -- na unidade_medida do insumo
    preco_unitario  DECIMAL(10,2) NOT NULL,   -- por unidade_medida
    lote            VARCHAR(30)   NOT NULL,
    data_validade   DATE          NOT NULL,
    criado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_compra PRIMARY KEY (id_compra),
    CONSTRAINT fk_compra_fornecedor FOREIGN KEY (id_fornecedor)
        REFERENCES fornecedor (id_fornecedor),
    CONSTRAINT fk_compra_insumo FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT ck_compra_qtd CHECK (quantidade > 0),
    CONSTRAINT ck_compra_preco CHECK (preco_unitario >= 0),
    CONSTRAINT ck_compra_validade CHECK (data_validade > data_compra)
) ENGINE=InnoDB;

-- Insumo x Atendimento: cada consumo e uma saida de estoque com a
-- quantidade REAL usada. id_atendimento NULL = consumo avulso
-- (perda, vencimento, teste...), e entao o motivo em observacao e obrigatorio.
CREATE TABLE consumo (
    id_consumo      INT           NOT NULL AUTO_INCREMENT,
    id_insumo       INT           NOT NULL,
    id_atendimento  INT           NULL,
    quantidade      DECIMAL(10,2) NOT NULL,
    data_consumo    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacao      VARCHAR(255)  NULL,
    criado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_consumo PRIMARY KEY (id_consumo),
    CONSTRAINT fk_consumo_insumo FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo),
    CONSTRAINT fk_consumo_atendimento FOREIGN KEY (id_atendimento)
        REFERENCES atendimento (id_atendimento),
    CONSTRAINT ck_consumo_qtd CHECK (quantidade > 0),
    CONSTRAINT ck_consumo_avulso CHECK (id_atendimento IS NOT NULL
        OR (observacao IS NOT NULL AND CHAR_LENGTH(TRIM(observacao)) > 0))
) ENGINE=InnoDB;

-- Lancamentos financeiros avulsos (despesas e receitas que nao sao
-- atendimentos). id_unidade NULL = lancamento geral, sem unidade.
CREATE TABLE lancamento (
    id_lancamento    INT              NOT NULL AUTO_INCREMENT,
    id_unidade       TINYINT UNSIGNED NULL,
    categoria        VARCHAR(40)      NOT NULL,
    descricao        VARCHAR(200)     NOT NULL,
    valor            DECIMAL(10,2)    NOT NULL,
    data_lancamento  DATE             NOT NULL,
    tipo             VARCHAR(7)       NOT NULL,
    criado_em        DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                      ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_lancamento PRIMARY KEY (id_lancamento),
    CONSTRAINT fk_lancamento_unidade FOREIGN KEY (id_unidade)
        REFERENCES unidade (id_unidade),
    CONSTRAINT ck_lancamento_valor CHECK (valor > 0),
    CONSTRAINT ck_lancamento_tipo CHECK (tipo IN ('RECEITA', 'DESPESA'))
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 3. INDICES
-- PK, FK e UNIQUE ja geram indice no InnoDB.
-- Abaixo, os campos mais filtrados em busca, agenda e relatorios.
-- ------------------------------------------------------------

CREATE INDEX idx_paciente_nome      ON paciente (nome_completo);
CREATE INDEX idx_paciente_ativo     ON paciente (ativo);
CREATE INDEX idx_paciente_cidade    ON paciente (cidade_paciente, bairro_paciente);
CREATE INDEX idx_atend_data_hora    ON atendimento (data_hora);
CREATE INDEX idx_atend_status       ON atendimento (status);
CREATE INDEX idx_atend_unidade_data ON atendimento (id_unidade, data_hora);
CREATE INDEX idx_compra_insumo_data ON compra (id_insumo, data_compra);
CREATE INDEX idx_compra_validade    ON compra (data_validade);
CREATE INDEX idx_consumo_data       ON consumo (data_consumo);
CREATE INDEX idx_lancamento_data    ON lancamento (data_lancamento);
CREATE INDEX idx_anamnese_data      ON anamnese (id_paciente, data_registro);

-- ------------------------------------------------------------
-- 4. REGRA DE ESTOQUE NO BANCO: o saldo nunca fica negativo.
-- Saldo de um insumo = soma das compras - soma dos consumos.
-- Os gatilhos recusam qualquer gravacao que deixaria o saldo < 0,
-- mesmo que venha de fora do aplicativo (ex.: futura versao web).
-- ------------------------------------------------------------

DELIMITER $$

CREATE TRIGGER trg_consumo_saldo_insert
BEFORE INSERT ON consumo FOR EACH ROW
BEGIN
    DECLARE v_saldo DECIMAL(12,2);
    SELECT COALESCE((SELECT SUM(quantidade) FROM compra  WHERE id_insumo = NEW.id_insumo), 0)
         - COALESCE((SELECT SUM(quantidade) FROM consumo WHERE id_insumo = NEW.id_insumo), 0)
      INTO v_saldo;
    IF NEW.quantidade > v_saldo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Saldo insuficiente do insumo para este consumo.';
    END IF;
END$$

CREATE TRIGGER trg_consumo_saldo_update
BEFORE UPDATE ON consumo FOR EACH ROW
BEGIN
    DECLARE v_saldo DECIMAL(12,2);
    SELECT COALESCE((SELECT SUM(quantidade) FROM compra  WHERE id_insumo = NEW.id_insumo), 0)
         - COALESCE((SELECT SUM(quantidade) FROM consumo
                     WHERE id_insumo = NEW.id_insumo AND id_consumo <> OLD.id_consumo), 0)
      INTO v_saldo;
    IF NEW.quantidade > v_saldo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Saldo insuficiente do insumo para este consumo.';
    END IF;
END$$

CREATE TRIGGER trg_compra_saldo_update
BEFORE UPDATE ON compra FOR EACH ROW
BEGIN
    DECLARE v_comprado DECIMAL(12,2);
    DECLARE v_consumido DECIMAL(12,2);
    -- recusa reduzir (ou trocar de insumo) uma compra ja consumida
    SELECT COALESCE(SUM(quantidade), 0) INTO v_comprado
      FROM compra WHERE id_insumo = OLD.id_insumo AND id_compra <> OLD.id_compra;
    SELECT COALESCE(SUM(quantidade), 0) INTO v_consumido
      FROM consumo WHERE id_insumo = OLD.id_insumo;
    IF v_comprado + IF(NEW.id_insumo = OLD.id_insumo, NEW.quantidade, 0) < v_consumido THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Alteracao deixaria o saldo do insumo negativo.';
    END IF;
END$$

DELIMITER ;

-- ------------------------------------------------------------
-- 5. VIEWS (usadas pelo aplicativo e pelo Power BI)
-- Valores de faturamento consideram SOMENTE atendimentos 'Realizado'.
-- 'Faltou' e 'Cancelado' nunca contam como receita.
-- ------------------------------------------------------------

-- 5.1 Estoque atual de cada insumo (compras - consumos)
CREATE VIEW vw_estoque_atual AS
SELECT i.id_insumo,
       i.nome_insumo,
       i.marca,
       i.apresentacao,
       i.unidade_medida,
       i.estoque_minimo,
       i.ativo,
       COALESCE(c.total_comprado, 0)                                AS total_comprado,
       COALESCE(s.total_consumido, 0)                               AS total_consumido,
       COALESCE(c.total_comprado, 0) - COALESCE(s.total_consumido, 0) AS saldo,
       (COALESCE(c.total_comprado, 0) - COALESCE(s.total_consumido, 0))
           < i.estoque_minimo                                       AS abaixo_minimo
FROM insumo i
LEFT JOIN (SELECT id_insumo, SUM(quantidade) AS total_comprado
             FROM compra GROUP BY id_insumo) c ON c.id_insumo = i.id_insumo
LEFT JOIN (SELECT id_insumo, SUM(quantidade) AS total_consumido
             FROM consumo GROUP BY id_insumo) s ON s.id_insumo = i.id_insumo;

-- 5.2 Compras vencidas ou que vencem em ate 60 dias, de insumos com saldo.
-- SUPOSICAO: nao ha controle FIFO por lote; o saldo mostrado e o do
-- insumo inteiro, nao o que resta daquele lote especifico.
CREATE VIEW vw_alerta_validade AS
SELECT co.id_compra,
       e.id_insumo,
       e.nome_insumo,
       e.marca,
       e.unidade_medida,
       co.lote,
       co.data_compra,
       co.data_validade,
       DATEDIFF(co.data_validade, CURDATE()) AS dias_para_vencer,
       co.data_validade < CURDATE()          AS vencido,
       co.quantidade                         AS quantidade_comprada,
       e.saldo                               AS saldo_insumo
FROM compra co
JOIN vw_estoque_atual e ON e.id_insumo = co.id_insumo
WHERE co.data_validade <= CURDATE() + INTERVAL 60 DAY
  AND e.saldo > 0
  AND e.ativo = TRUE;

-- 5.3 Valor de cada atendimento (itens - desconto). Substitui o antigo
-- campo valor_total. Nunca negativo.
CREATE VIEW vw_valor_atendimento AS
SELECT a.id_atendimento,
       a.id_paciente,
       a.id_unidade,
       a.id_profissional,
       a.data_hora,
       a.status,
       a.forma_pagamento,
       COALESCE(SUM(ap.valor_cobrado), 0)                              AS subtotal,
       a.desconto,
       GREATEST(COALESCE(SUM(ap.valor_cobrado), 0) - a.desconto, 0)    AS valor_total,
       COUNT(ap.id_atend_proc)                                         AS qtd_itens
FROM atendimento a
LEFT JOIN atendimento_procedimento ap ON ap.id_atendimento = a.id_atendimento
GROUP BY a.id_atendimento, a.id_paciente, a.id_unidade, a.id_profissional,
         a.data_hora, a.status, a.forma_pagamento, a.desconto;

-- 5.4 Faturamento: so atendimentos Realizado
CREATE VIEW vw_faturamento AS
SELECT v.id_atendimento,
       v.id_paciente,
       v.id_unidade,
       u.nome_clinica,
       DATE(v.data_hora)                 AS data_atendimento,
       DATE_FORMAT(v.data_hora, '%Y-%m') AS ano_mes,
       v.forma_pagamento,
       v.subtotal,
       v.desconto,
       v.valor_total
FROM vw_valor_atendimento v
JOIN unidade u ON u.id_unidade = v.id_unidade
WHERE v.status = 'Realizado';

-- 5.5 KPIs por mes e unidade (o Power BI e o app somam/filtram por cima)
CREATE VIEW vw_dash_kpis_mensal AS
SELECT DATE_FORMAT(v.data_hora, '%Y-%m')                                  AS ano_mes,
       v.id_unidade,
       u.nome_clinica,
       SUM(v.status = 'Realizado')                                        AS realizados,
       SUM(v.status = 'Faltou')                                           AS faltas,
       SUM(v.status = 'Cancelado')                                        AS cancelados,
       SUM(v.status = 'Agendado')                                         AS agendados,
       SUM(CASE WHEN v.status = 'Realizado' THEN v.valor_total ELSE 0 END) AS faturamento,
       ROUND(SUM(CASE WHEN v.status = 'Realizado' THEN v.valor_total ELSE 0 END)
             / NULLIF(SUM(v.status = 'Realizado'), 0), 2)                 AS ticket_medio,
       COUNT(DISTINCT CASE WHEN v.status = 'Realizado' THEN v.id_paciente END)
                                                                          AS pacientes_atendidos
FROM vw_valor_atendimento v
JOIN unidade u ON u.id_unidade = v.id_unidade
GROUP BY DATE_FORMAT(v.data_hora, '%Y-%m'), v.id_unidade, u.nome_clinica;

-- 5.6 Faturamento, custo de locacao, despesas e margem por unidade e mes.
-- SUPOSICAO (NAO confirmada pela cliente): custo de locacao =
--   unidade.valor_locacao x dias distintos com atendimento Realizado no mes.
-- Para trocar a regra, altere SO a coluna custo_locacao abaixo
-- (ex.: valor fixo mensal = u.valor_locacao).
-- Margem = faturamento - custo_locacao - despesas lancadas para a unidade.
CREATE VIEW vw_dash_unidade AS
SELECT m.ano_mes,
       u.id_unidade,
       u.nome_clinica,
       COALESCE(f.faturamento, 0)                           AS faturamento,
       COALESCE(f.dias_com_atendimento, 0)                  AS dias_com_atendimento,
       u.valor_locacao * COALESCE(f.dias_com_atendimento, 0) AS custo_locacao,
       COALESCE(d.despesas, 0)                              AS despesas,
       COALESCE(f.faturamento, 0)
         - u.valor_locacao * COALESCE(f.dias_com_atendimento, 0)
         - COALESCE(d.despesas, 0)                          AS margem
FROM (SELECT DISTINCT id_unidade, ano_mes FROM vw_faturamento
      UNION
      SELECT DISTINCT id_unidade, DATE_FORMAT(data_lancamento, '%Y-%m')
        FROM lancamento WHERE id_unidade IS NOT NULL) m
JOIN unidade u ON u.id_unidade = m.id_unidade
LEFT JOIN (SELECT id_unidade, ano_mes,
                  SUM(valor_total)                  AS faturamento,
                  COUNT(DISTINCT data_atendimento)  AS dias_com_atendimento
             FROM vw_faturamento GROUP BY id_unidade, ano_mes) f
       ON f.id_unidade = m.id_unidade AND f.ano_mes = m.ano_mes
LEFT JOIN (SELECT id_unidade, DATE_FORMAT(data_lancamento, '%Y-%m') AS ano_mes,
                  SUM(valor) AS despesas
             FROM lancamento WHERE tipo = 'DESPESA' AND id_unidade IS NOT NULL
             GROUP BY id_unidade, DATE_FORMAT(data_lancamento, '%Y-%m')) d
       ON d.id_unidade = m.id_unidade AND d.ano_mes = m.ano_mes;

-- 5.7 Faturamento por procedimento, mes e unidade. O desconto do
-- atendimento e repartido entre os itens na proporcao do valor cobrado,
-- para que a soma por procedimento feche com vw_faturamento.
CREATE VIEW vw_dash_procedimento AS
SELECT DATE_FORMAT(v.data_hora, '%Y-%m') AS ano_mes,
       v.id_unidade,
       p.id_procedimento,
       p.nome_procedimento,
       COUNT(*)                          AS quantidade_realizada,
       ROUND(SUM(ap.valor_cobrado
                 - v.desconto * ap.valor_cobrado / NULLIF(v.subtotal, 0)), 2)
                                         AS faturamento
FROM vw_valor_atendimento v
JOIN atendimento_procedimento ap ON ap.id_atendimento = v.id_atendimento
JOIN procedimento p ON p.id_procedimento = ap.id_procedimento
WHERE v.status = 'Realizado'
GROUP BY DATE_FORMAT(v.data_hora, '%Y-%m'), v.id_unidade,
         p.id_procedimento, p.nome_procedimento;

-- 5.8 Retornos (REGRA UNICA, igual no app, nas consultas e no Power BI):
-- por paciente ativo e procedimento com intervalo_retorno_dias definido,
--   data_retorno_prevista = data do ultimo procedimento Realizado + intervalo
--   retornou = existe atendimento Agendado ou Realizado do paciente
--              depois da data desse ultimo procedimento
--   vencido  = data_retorno_prevista < CURDATE()  (estritamente antes de hoje)
--   pendente = vencido AND NOT retornou  (retorno ainda nao vencido NAO e pendente)
--   taxa de retorno = vencidos que retornaram / vencidos
CREATE VIEW vw_dash_retorno AS
SELECT x.id_paciente,
       pa.nome_completo,
       pa.telefone_paciente,
       x.id_procedimento,
       pr.nome_procedimento,
       x.id_unidade,
       x.ultima_data,
       DATE_ADD(x.ultima_data, INTERVAL pr.intervalo_retorno_dias DAY) AS data_retorno_prevista,
       EXISTS (SELECT 1 FROM atendimento a2
                WHERE a2.id_paciente = x.id_paciente
                  AND a2.status IN ('Agendado', 'Realizado')
                  AND DATE(a2.data_hora) > x.ultima_data)              AS retornou,
       DATE_ADD(x.ultima_data, INTERVAL pr.intervalo_retorno_dias DAY) < CURDATE()
                                                                       AS vencido
FROM (SELECT a.id_paciente, ap.id_procedimento,
             MAX(DATE(a.data_hora)) AS ultima_data,
             SUBSTRING_INDEX(GROUP_CONCAT(a.id_unidade ORDER BY a.data_hora DESC), ',', 1)
                 + 0 AS id_unidade
        FROM atendimento a
        JOIN atendimento_procedimento ap ON ap.id_atendimento = a.id_atendimento
       WHERE a.status = 'Realizado'
       GROUP BY a.id_paciente, ap.id_procedimento) x
JOIN procedimento pr ON pr.id_procedimento = x.id_procedimento
JOIN paciente pa     ON pa.id_paciente = x.id_paciente
WHERE pr.intervalo_retorno_dias IS NOT NULL
  AND pa.ativo = TRUE;

-- 5.9 Pacientes por cidade e bairro
CREATE VIEW vw_dash_pacientes_cidade_bairro AS
SELECT cidade_paciente AS cidade,
       bairro_paciente AS bairro,
       SUM(ativo = TRUE) AS pacientes_ativos,
       COUNT(*)          AS pacientes_total
FROM paciente
GROUP BY cidade_paciente, bairro_paciente;

-- 5.10 Comparecimento = realizados / (realizados + faltas), por mes e unidade.
-- Cancelados nao entram na conta (foram desmarcados com antecedencia).
CREATE VIEW vw_dash_comparecimento AS
SELECT DATE_FORMAT(data_hora, '%Y-%m') AS ano_mes,
       id_unidade,
       SUM(status = 'Realizado') AS realizados,
       SUM(status = 'Faltou')    AS faltas,
       ROUND(SUM(status = 'Realizado')
             / NULLIF(SUM(status IN ('Realizado', 'Faltou')), 0), 4) AS taxa_comparecimento
FROM atendimento
GROUP BY DATE_FORMAT(data_hora, '%Y-%m'), id_unidade;

-- 5.11 Preco atual de cada insumo = preco unitario da compra mais recente
CREATE VIEW vw_preco_insumo_atual AS
SELECT id_insumo, preco_unitario, data_compra
FROM (SELECT id_insumo, preco_unitario, data_compra,
             ROW_NUMBER() OVER (PARTITION BY id_insumo
                                ORDER BY data_compra DESC, id_compra DESC) AS ordem
        FROM compra) t
WHERE ordem = 1;

-- 5.12 Custo estimado de insumos por procedimento
-- (quantidade padrao x preco da compra mais recente).
CREATE VIEW vw_custo_procedimento AS
SELECT p.id_procedimento,
       p.nome_procedimento,
       p.preco_tabela,
       ROUND(COALESCE(SUM(pi.quantidade_padrao * pa.preco_unitario), 0), 2) AS custo_insumos,
       ROUND(p.preco_tabela
             - COALESCE(SUM(pi.quantidade_padrao * pa.preco_unitario), 0), 2) AS margem_estimada,
       COUNT(pi.id_insumo)                                                   AS qtd_insumos,
       SUM(pi.id_insumo IS NOT NULL AND pa.preco_unitario IS NULL)           AS insumos_sem_preco
FROM procedimento p
LEFT JOIN procedimento_insumo pi ON pi.id_procedimento = p.id_procedimento
LEFT JOIN vw_preco_insumo_atual pa ON pa.id_insumo = pi.id_insumo
GROUP BY p.id_procedimento, p.nome_procedimento, p.preco_tabela;

-- ------------------------------------------------------------
-- 7. CONFERENCIA RAPIDA
-- ------------------------------------------------------------
-- SHOW FULL TABLES;
-- SELECT * FROM vw_estoque_atual;

-- ====================== 2. POPULACAO ======================
-- ============================================================
-- ZENITH - populacao do banco v2 (gerado por popular_gerar.py)
-- Semente 20261016; data de referencia 2026-10-16.
-- TODOS OS DADOS SAO FICTICIOS. CPF/CNPJ validos apenas pelo algoritmo.
-- SUPOSICAO: precos, locacao, retornos, quantidades padrao e valores
-- financeiros sao ficticios, a confirmar com a cliente.
-- Nao edite a mao: altere popular_gerar.py e gere de novo.
-- Execute DEPOIS de zenith_banco.sql, com o banco vazio.
-- ============================================================
SET NAMES utf8mb4;
USE zenith_teste;
START TRANSACTION;
INSERT INTO unidade (id_unidade, nome_clinica, bairro_unidade, cidade_unidade, uf_unidade, valor_locacao) VALUES (1, 'Unidade Mooca', 'Mooca', 'São Paulo', 'SP', 350.00);
INSERT INTO unidade (id_unidade, nome_clinica, bairro_unidade, cidade_unidade, uf_unidade, valor_locacao) VALUES (2, 'Unidade Tatuapé', 'Tatuapé', 'São Paulo', 'SP', 400.00);
INSERT INTO unidade (id_unidade, nome_clinica, bairro_unidade, cidade_unidade, uf_unidade, valor_locacao) VALUES (3, 'Unidade Mogi das Cruzes', 'Centro', 'Mogi das Cruzes', 'SP', 250.00);
INSERT INTO profissional (id_profissional, nome_completo) VALUES (1, 'Gabriela Saraiva');
INSERT INTO procedimento (id_procedimento, nome_procedimento, preco_tabela, intervalo_retorno_dias) VALUES (1, 'Toxina botulínica', 1200.00, 150);
INSERT INTO procedimento (id_procedimento, nome_procedimento, preco_tabela, intervalo_retorno_dias) VALUES (2, 'Preenchimento facial', 1500.00, 300);
INSERT INTO procedimento (id_procedimento, nome_procedimento, preco_tabela, intervalo_retorno_dias) VALUES (3, 'Preenchimento labial', 1300.00, 270);
INSERT INTO procedimento (id_procedimento, nome_procedimento, preco_tabela, intervalo_retorno_dias) VALUES (4, 'Bioestimulador', 2300.00, 180);
INSERT INTO procedimento (id_procedimento, nome_procedimento, preco_tabela, intervalo_retorno_dias) VALUES (5, 'Skinbooster', 950.00, 120);
INSERT INTO procedimento (id_procedimento, nome_procedimento, preco_tabela, intervalo_retorno_dias) VALUES (6, 'Avaliação facial', 100.00, NULL);
INSERT INTO procedimento (id_procedimento, nome_procedimento, preco_tabela, intervalo_retorno_dias) VALUES (7, 'Tratamento de olheiras', 1600.00, 270);
INSERT INTO fornecedor (id_fornecedor, razao_social, cnpj, telefone_fornecedor, cep_fornecedor, endereco_fornecedor, bairro_fornecedor, cidade_fornecedor) VALUES (1, 'Alfa Exemplo Distribuidora de Produtos Estéticos Ltda', '28868472000180', '1129838402', '04100975', 'Rua dos Cedros, 1688', 'Vila Mariana', 'São Paulo');
INSERT INTO fornecedor (id_fornecedor, razao_social, cnpj, telefone_fornecedor, cep_fornecedor, endereco_fornecedor, bairro_fornecedor, cidade_fornecedor) VALUES (2, 'Beta Exemplo Produtos Médicos Ltda', '59671665000170', '1128930738', '02085224', 'Rua das Magnólias, 2219', 'Santana', 'São Paulo');
INSERT INTO fornecedor (id_fornecedor, razao_social, cnpj, telefone_fornecedor, cep_fornecedor, endereco_fornecedor, bairro_fornecedor, cidade_fornecedor) VALUES (3, 'Gama Exemplo Dermocosméticos Ltda', '21677142000168', '1122451759', '08790151', 'Rua das Hortênsias, 267', 'Centro', 'Mogi das Cruzes');
INSERT INTO fornecedor (id_fornecedor, razao_social, cnpj, telefone_fornecedor, cep_fornecedor, endereco_fornecedor, bairro_fornecedor, cidade_fornecedor) VALUES (4, 'Delta Exemplo Materiais Hospitalares Ltda', '81612681000140', '1142493557', '03012897', 'Rua dos Cedros, 1354', 'Brás', 'São Paulo');
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (1, 'Botox', 'Allergan', 'Frasco 100U', 'U', 200.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (2, 'Letybo', 'Hugel', 'Frasco 50U', 'U', 100.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (3, 'Botulift', 'Biolab', 'Frasco 100U', 'U', 100.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (4, 'Yvoire Contour', 'LG Chem', 'Seringa 1,0 mL', 'mL', 4.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (5, 'Up Ilikia', 'Ilikia', 'Seringa 1,0 mL', 'mL', 4.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (6, 'Alur Medical', 'Alur Medical', 'Seringa 1,0 mL', 'mL', 4.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (7, 'Milimetric', 'Milimetric', 'Seringa 1,0 mL', 'mL', 3.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (8, 'Radiesse', 'Merz Aesthetics', 'Seringa 1,5 mL', 'seringa', 1.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (9, 'Sculptra', 'Galderma', 'Frasco 367,5 mg', 'frasco', 2.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (10, 'PLLA Cimed', 'Cimed', 'Frasco 150 mg', 'frasco', 1.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (11, 'Stim', 'Stim', 'Seringa 1,0 mL', 'seringa', 1.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (12, 'Agulha 30G 13 mm', 'Genérico', 'Caixa 100 un', 'un', 60.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (13, 'Cânula 25G 50 mm', 'Genérico', 'Caixa 20 un', 'un', 15.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (14, 'Seringa 1 mL', 'Genérico', 'Caixa 100 un', 'un', 60.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (15, 'Luva de procedimento', 'Genérico', 'Caixa 50 pares', 'par', 40.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (16, 'Gaze estéril', 'Genérico', 'Pacote 10 un', 'un', 60.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (17, 'Clorexidina alcoólica 0,5%', 'Genérico', 'Frasco 1000 mL', 'mL', 500.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (18, 'Soro fisiológico 0,9%', 'Genérico', 'Frasco 250 mL', 'mL', 250.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (19, 'Água para injeção', 'Genérico', 'Ampola 10 mL', 'mL', 50.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (20, 'Anestésico tópico', 'Genérico', 'Bisnaga 30 g', 'g', 72.50);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (21, 'Algodão', 'Genérico', 'Pacote 500 g', 'g', 200.00);
INSERT INTO insumo (id_insumo, nome_insumo, marca, apresentacao, unidade_medida, estoque_minimo) VALUES (22, 'Máscara descartável', 'Genérico', 'Caixa 50 un', 'un', 30.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (1, 1, 50.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (1, 12, 3.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (1, 14, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (1, 18, 2.50);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (1, 15, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (1, 17, 5.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (1, 16, 4.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (2, 4, 1.50);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (2, 13, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (2, 12, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (2, 20, 2.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (2, 15, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (2, 17, 5.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (2, 16, 4.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (3, 6, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (3, 12, 2.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (3, 20, 2.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (3, 15, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (3, 16, 3.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (4, 9, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (4, 19, 8.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (4, 13, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (4, 14, 2.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (4, 15, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (4, 17, 5.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (4, 16, 4.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (5, 5, 2.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (5, 12, 4.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (5, 20, 3.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (5, 15, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (5, 16, 3.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (7, 7, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (7, 13, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (7, 20, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (7, 15, 1.00);
INSERT INTO procedimento_insumo (id_procedimento, id_insumo, quantidade_padrao) VALUES (7, 16, 3.00);
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (1, 'Patrícia Sampaio Vasconcelos', '66046176611', '1993-08-03', '11988530335', NULL, '08750060', 'Avenida das Flores, 2168', 'Vila Oliveira', 'Mogi das Cruzes', 'Indicação', TRUE, '2025-12-31 09:28:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (2, 'Mateus Barros Duarte', '43713104271', '1976-07-22', '11988719025', 'mateus.duarte2@exemplo.invalid', '03653816', 'Rua das Magnólias, 804', 'Penha', 'São Paulo', 'Indicação', TRUE, '2026-07-21 10:31:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (3, 'Gabriela Guimarães Tavares', '02224658591', '1968-11-26', '11979583479', NULL, '08798462', 'Rua dos Jacarandás, 607', 'Centro', 'Mogi das Cruzes', 'Indicação', TRUE, '2026-06-22 17:33:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (4, 'Flávia Valente Brandão', '15876199460', '1981-08-23', '11971026109', NULL, '03101024', 'Rua das Hortênsias, 2856', 'Vila Prudente', 'São Paulo', 'Indicação', TRUE, '2025-12-23 17:54:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (5, 'Raquel Dias Lacerda', '55660451896', '1981-04-12', '11996960160', 'raquel.lacerda5@exemplo.invalid', '08767399', 'Rua das Acácias, 1586', 'Centro', 'Mogi das Cruzes', 'Instagram', TRUE, '2025-12-19 18:11:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (6, 'Marina Queiroz Cardoso', '72424129606', '1991-03-09', '11964423858', 'marina.cardoso6@exemplo.invalid', '08782898', 'Travessa das Orquídeas, 1015', 'Centro', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-01-25 17:25:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (7, 'Beatriz Cardoso Xavier', '84875465289', '2004-07-06', '11915204551', NULL, '03367208', 'Rua das Magnólias, 777', 'Tatuapé', 'São Paulo', 'Instagram', TRUE, '2025-11-08 18:05:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (8, 'Rafael Almeida Siqueira', '04482442330', '1989-08-04', '11953757307', 'rafael.siqueira8@exemplo.invalid', '03160628', 'Rua das Magnólias, 2931', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2026-03-06 11:10:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (9, 'Carlos Leal Xavier', '74336334480', '1968-07-11', '11972066384', 'carlos.xavier9@exemplo.invalid', '02090024', 'Travessa das Orquídeas, 1566', 'Santana', 'São Paulo', 'Instagram', TRUE, '2025-12-26 14:57:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (10, 'Patrícia Siqueira Vasconcelos', '25971953095', '2002-04-12', '11938911419', 'patricia.vasconcelos10@exemplo.invalid', '03637889', 'Rua dos Jacarandás, 1123', 'Penha', 'São Paulo', 'Indicação', TRUE, '2026-05-19 18:08:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (11, 'Débora Fontes Cardoso', '05913318293', '1991-09-01', '11994614334', 'debora.cardoso11@exemplo.invalid', '08752549', 'Travessa das Orquídeas, 2359', 'Mogilar', 'Mogi das Cruzes', 'Indicação', TRUE, '2026-02-18 09:20:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (12, 'Bruna Queiroz Nogueira', '01963942280', '2004-10-06', '11938109364', 'bruna.nogueira12@exemplo.invalid', '08669971', 'Rua das Palmeiras, 2530', 'Centro', 'Suzano', 'Instagram', TRUE, '2026-05-23 09:35:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (13, 'Carlos Barros Pacheco', '47051517805', '1991-09-01', '11981380219', 'carlos.pacheco13@exemplo.invalid', '03324129', 'Rua dos Cedros, 2980', 'Tatuapé', 'São Paulo', 'Google', TRUE, '2025-12-22 14:20:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (14, 'Bruna Brandão Almeida', '88639344019', '1973-05-06', '11978864827', 'bruna.almeida14@exemplo.invalid', '03574586', 'Avenida dos Pinheiros Exemplo, 2861', 'Vila Formosa', 'São Paulo', 'Indicação', TRUE, '2026-04-14 17:21:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (15, 'Juliana Ramos Sampaio', '15455385909', '1992-09-16', '11964694866', 'juliana.sampaio15@exemplo.invalid', '03105294', 'Rua dos Ipês, 612', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2026-01-19 15:49:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (16, 'Bruno Cardoso Moura', '88485393864', '1974-10-25', '11903984113', 'bruno.moura16@exemplo.invalid', '08659679', 'Rua dos Jacarandás, 1250', 'Centro', 'Suzano', 'Indicação', TRUE, '2025-10-11 12:19:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (17, 'Daniela Moura Duarte', '40864321880', '1973-03-02', '11903041923', 'daniela.duarte17@exemplo.invalid', '03138065', 'Avenida das Flores, 1690', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2026-08-25 14:25:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (18, 'Henrique Barros Peixoto', '10730228975', '2001-05-04', '11904203990', 'henrique.peixoto18@exemplo.invalid', '08797783', 'Rua dos Jacarandás, 1819', 'Braz Cubas', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-03-14 15:19:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (19, 'Lívia Rezende Xavier', '01745294490', '1992-08-16', '11914907124', 'livia.xavier19@exemplo.invalid', '08629590', 'Travessa das Orquídeas, 981', 'Centro', 'Suzano', 'Indicação', TRUE, '2026-06-06 10:08:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (20, 'Lucas Ramos Moura', '04184548415', '2004-10-04', '11997744752', 'lucas.moura20@exemplo.invalid', '08733792', 'Rua das Palmeiras, 1149', 'Mogilar', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-01-23 11:53:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (21, 'Henrique Vasconcelos Tavares', '23483151656', '1990-08-05', '11939760523', 'henrique.tavares21@exemplo.invalid', '03547792', 'Avenida das Flores, 2203', 'Vila Formosa', 'São Paulo', 'Google', TRUE, '2025-10-27 14:26:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (22, 'Vanessa Peixoto Cardoso', '96379922512', '2003-02-01', '11989639303', 'vanessa.cardoso22@exemplo.invalid', '03413014', 'Rua das Magnólias, 1122', 'Carrão', 'São Paulo', 'Instagram', TRUE, '2026-02-09 09:18:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (23, 'Beatriz Brandão Dias', '09645878586', '1973-07-08', '11904131092', 'beatriz.dias23@exemplo.invalid', '03111055', 'Rua das Palmeiras, 682', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2025-11-06 13:19:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (24, 'Flávia Antunes Sampaio', '72538303001', '1994-08-12', '11913821334', 'flavia.sampaio24@exemplo.invalid', '03100691', 'Rua dos Ipês, 2506', 'Mooca', 'São Paulo', 'Google', TRUE, '2026-06-05 13:59:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (25, 'Elisa Macedo Sampaio', '71969199555', '1969-08-20', '11983957614', 'elisa.sampaio25@exemplo.invalid', '03188431', 'Rua dos Girassóis, 2319', 'Mooca', 'São Paulo', 'Indicação', TRUE, '2026-01-19 16:05:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (26, 'Bruno Rezende Cardoso', '47496921319', '1997-11-06', '11981767983', NULL, '08795193', 'Rua das Magnólias, 1783', 'Vila Oliveira', 'Mogi das Cruzes', 'Instagram', TRUE, '2025-11-10 15:00:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (27, 'Felipe Sampaio Teixeira', '40899938493', '1995-08-18', '11921522096', 'felipe.teixeira27@exemplo.invalid', '03082962', 'Rua dos Cedros, 761', 'Brás', 'São Paulo', 'Facebook', TRUE, '2026-03-04 16:49:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (28, 'Felipe Cardoso Macedo', '52550379403', '1982-05-13', '11939440875', 'felipe.macedo28@exemplo.invalid', '08745602', 'Rua dos Cedros, 1536', 'Mogilar', 'Mogi das Cruzes', 'Instagram', FALSE, '2026-03-01 14:08:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (29, 'Lívia Almeida Guimarães', '58920394555', '1986-01-12', '11999047939', 'livia.guimaraes29@exemplo.invalid', '03143626', 'Rua das Magnólias, 720', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2026-01-31 10:24:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (30, 'Aline Vasconcelos Faria', '40831243007', '1965-12-26', '11905535561', 'aline.faria30@exemplo.invalid', '03444024', 'Rua das Acácias, 1887', 'Carrão', 'São Paulo', 'Instagram', TRUE, '2026-02-20 14:05:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (31, 'Fernanda Fontes Guimarães', '04705178327', '1984-05-26', '11941345016', 'fernanda.guimaraes31@exemplo.invalid', '03063968', 'Rua das Acácias, 1574', 'Belém', 'São Paulo', 'Instagram', TRUE, '2025-11-20 16:54:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (32, 'Mariana Vasconcelos Ramos', '31582800359', '2003-07-24', '11900335502', 'mariana.ramos32@exemplo.invalid', '08794064', 'Travessa das Orquídeas, 1206', 'Vila Oliveira', 'Mogi das Cruzes', 'Instagram', TRUE, '2025-12-26 09:12:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (33, 'Thiago Queiroz Almeida', '47206386270', '1967-03-21', '11954597851', 'thiago.almeida33@exemplo.invalid', '08777749', 'Rua das Acácias, 822', 'Centro', 'Mogi das Cruzes', 'Indicação', TRUE, '2026-04-20 16:58:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (34, 'Raquel Tavares Brandão', '09431944820', '1989-07-22', '11956349155', 'raquel.brandao34@exemplo.invalid', '03142090', 'Avenida das Flores, 2806', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2025-10-17 09:24:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (35, 'Marina Almeida Nogueira', '58168543483', '1972-05-17', '11902364820', NULL, '03393917', 'Rua dos Ipês, 1892', 'Tatuapé', 'São Paulo', 'Facebook', TRUE, '2026-08-18 17:04:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (36, 'Bruna Dias Guimarães', '82646137800', '1994-10-20', '11919383719', 'bruna.guimaraes36@exemplo.invalid', '03131554', 'Rua dos Cedros, 1813', 'Vila Prudente', 'São Paulo', 'WhatsApp', TRUE, '2026-02-27 16:44:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (37, 'Natália Guimarães Moura', '97411683817', '1997-01-27', '11971447855', 'natalia.moura37@exemplo.invalid', '03385903', 'Rua dos Cedros, 190', 'Tatuapé', 'São Paulo', 'Instagram', TRUE, '2025-12-01 17:04:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (38, 'Isabela Gomes Gomes', '82989931015', '1997-03-24', '11919540583', NULL, '08719098', 'Rua dos Ipês, 2224', 'Mogilar', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-02-16 12:48:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (39, 'Rafael Lacerda Almeida', '15244239473', '1967-07-19', '11991833665', 'rafael.almeida39@exemplo.invalid', '03241447', 'Avenida das Flores, 2757', 'Água Rasa', 'São Paulo', 'Google', TRUE, '2026-02-27 13:51:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (40, 'Marina Xavier Almeida', '72799300006', '1998-06-22', '11933180473', 'marina.almeida40@exemplo.invalid', '03191711', 'Rua das Acácias, 1683', 'Mooca', 'São Paulo', 'WhatsApp', TRUE, '2026-08-08 17:57:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (41, 'Fernanda Valente Esteves', '51612556680', '2000-12-23', '11905699431', 'fernanda.esteves41@exemplo.invalid', '03343975', 'Rua das Hortênsias, 1995', 'Tatuapé', 'São Paulo', 'Indicação', TRUE, '2026-09-14 09:40:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (42, 'Tatiana Esteves Macedo', '28721026122', '2002-06-05', '11965535681', 'tatiana.macedo42@exemplo.invalid', '03101274', 'Rua dos Cedros, 549', 'Vila Prudente', 'São Paulo', 'Instagram', TRUE, '2026-05-24 12:06:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (43, 'Larissa Valente Guimarães', '01539913139', '1992-08-26', '11912837220', 'larissa.guimaraes43@exemplo.invalid', '03600638', 'Rua dos Ipês, 1123', 'Penha', 'São Paulo', 'Instagram', TRUE, '2026-02-16 18:57:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (44, 'Beatriz Sampaio Ramos', '69588437202', '2002-04-01', '11909196953', 'beatriz.ramos44@exemplo.invalid', '03462365', 'Rua dos Girassóis, 2487', 'Carrão', 'São Paulo', 'WhatsApp', TRUE, '2026-03-07 17:58:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (45, 'Renata Brandão Lacerda', '83001041277', '1966-09-09', '11913357337', 'renata.lacerda45@exemplo.invalid', '04143467', 'Avenida das Flores, 1958', 'Vila Mariana', 'São Paulo', 'Google', FALSE, '2025-12-22 16:19:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (46, 'Giovana Siqueira Nogueira', '71161575812', '1981-04-20', '11975812921', 'giovana.nogueira46@exemplo.invalid', '03515001', 'Rua das Hortênsias, 715', 'Vila Formosa', 'São Paulo', 'Indicação', TRUE, '2025-09-28 17:22:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (47, 'Daniela Coutinho Cardoso', '42461589330', '1990-03-27', '11908755334', NULL, '08746925', 'Rua dos Cedros, 1195', 'Braz Cubas', 'Mogi das Cruzes', 'Instagram', TRUE, '2025-12-29 14:50:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (48, 'Lívia Cardoso Fontes', '83769733630', '1967-12-10', '11906037521', 'livia.fontes48@exemplo.invalid', '03345710', 'Travessa das Orquídeas, 419', 'Tatuapé', 'São Paulo', 'Instagram', TRUE, '2025-10-20 09:28:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (49, 'Elisa Barros Almeida', '53274355984', '1992-02-25', '11921078523', 'elisa.almeida49@exemplo.invalid', '03634854', 'Rua dos Ipês, 951', 'Penha', 'São Paulo', 'Instagram', TRUE, '2025-11-26 16:23:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (50, 'Helena Queiroz Nogueira', '11192930657', '1993-09-09', '11982190891', 'helena.nogueira50@exemplo.invalid', '03281753', 'Rua dos Jacarandás, 735', 'Água Rasa', 'São Paulo', 'Instagram', TRUE, '2026-01-12 18:19:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (51, 'Diego Duarte Antunes', '48109086071', '1973-03-28', '11905647629', NULL, '08291545', 'Rua das Magnólias, 1260', 'Itaquera', 'São Paulo', 'Indicação', TRUE, '2026-05-04 10:00:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (52, 'Patrícia Leal Faria', '57338754292', '1985-06-21', '11966753973', 'patricia.faria52@exemplo.invalid', '03309139', 'Rua dos Girassóis, 437', 'Tatuapé', 'São Paulo', 'Indicação', FALSE, '2025-10-08 16:44:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (53, 'Rafael Faria Ramos', '46523475026', '1968-01-01', '11945477918', NULL, '03430089', 'Rua dos Ipês, 1164', 'Carrão', 'São Paulo', 'Indicação', TRUE, '2025-10-10 11:09:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (54, 'Priscila Peixoto Moura', '55192037336', '2004-08-15', '11971596917', 'priscila.moura54@exemplo.invalid', '03164478', 'Rua das Palmeiras, 779', 'Vila Prudente', 'São Paulo', 'Instagram', TRUE, '2025-11-09 17:12:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (55, 'Juliana Nogueira Guimarães', '93548622097', '1974-12-21', '11961561046', 'juliana.guimaraes55@exemplo.invalid', '03033466', 'Rua das Magnólias, 838', 'Belém', 'São Paulo', 'Google', TRUE, '2025-12-28 13:01:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (56, 'Sofia Lacerda Coutinho', '42868581978', '1990-03-11', '11918205437', 'sofia.coutinho56@exemplo.invalid', '03110865', 'Travessa das Orquídeas, 2003', 'Mooca', 'São Paulo', 'WhatsApp', TRUE, '2026-04-20 09:02:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (57, 'Henrique Fontes Almeida', '66208687039', '2000-08-21', '11928474792', 'henrique.almeida57@exemplo.invalid', '08703739', 'Travessa das Orquídeas, 2331', 'Vila Oliveira', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-09-06 18:35:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (58, 'Lívia Esteves Esteves', '67390408006', '1987-02-28', '11948361361', NULL, '08709706', 'Avenida das Flores, 353', 'Vila Oliveira', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-01-01 16:01:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (59, 'Isabela Brandão Almeida', '40070687471', '1970-12-04', '11984555969', 'isabela.almeida59@exemplo.invalid', '03081553', 'Avenida das Flores, 533', 'Brás', 'São Paulo', 'Indicação', TRUE, '2026-07-23 16:25:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (60, 'Mateus Antunes Tavares', '68438083366', '1994-09-18', '11919867347', 'mateus.tavares60@exemplo.invalid', '08723546', 'Rua das Acácias, 2221', 'Centro', 'Mogi das Cruzes', 'Indicação', TRUE, '2026-03-15 11:03:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (61, 'Bruna Macedo Nogueira', '68469856707', '1973-08-18', '11918307688', NULL, '03162421', 'Travessa das Orquídeas, 908', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2026-02-24 17:22:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (62, 'Fernanda Ramos Guimarães', '50538788895', '1993-01-22', '11941050014', 'fernanda.guimaraes62@exemplo.invalid', '03653874', 'Rua das Acácias, 470', 'Penha', 'São Paulo', 'Indicação', TRUE, '2026-05-31 12:36:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (63, 'Helena Ramos Ramos', '53628956994', '1970-04-12', '11924022949', 'helena.ramos63@exemplo.invalid', '03185748', 'Rua dos Jacarandás, 878', 'Vila Prudente', 'São Paulo', 'Facebook', TRUE, '2025-11-15 16:33:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (64, 'Lucas Pacheco Gomes', '22075081450', '1988-11-22', '11917030084', 'lucas.gomes64@exemplo.invalid', '08763655', 'Rua das Acácias, 1689', 'Braz Cubas', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-07-11 14:54:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (65, 'Ana Antunes Nogueira', '99395768460', '2004-10-11', '11954378151', 'ana.nogueira65@exemplo.invalid', '03329430', 'Rua dos Ipês, 1985', 'Tatuapé', 'São Paulo', 'Instagram', TRUE, '2025-11-12 14:26:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (66, 'Aline Rezende Sampaio', '24386565906', '1971-11-23', '11918168503', NULL, '03598553', 'Rua dos Jacarandás, 1281', 'Vila Formosa', 'São Paulo', 'WhatsApp', TRUE, '2026-05-17 18:27:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (67, 'Fernanda Dias Peixoto', '58809229525', '2000-07-02', '11957042310', NULL, '03117842', 'Travessa das Orquídeas, 322', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2025-10-02 16:31:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (68, 'Marina Guimarães Guimarães', '81756887934', '1993-05-12', '11972921631', 'marina.guimaraes68@exemplo.invalid', '03195555', 'Avenida dos Pinheiros Exemplo, 1390', 'Mooca', 'São Paulo', 'Indicação', FALSE, '2026-03-07 16:30:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (69, 'Aline Moura Barros', '46592019298', '1969-02-24', '11974860772', 'aline.barros69@exemplo.invalid', '03249099', 'Rua dos Jacarandás, 1449', 'Água Rasa', 'São Paulo', 'Instagram', TRUE, '2026-08-08 11:32:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (70, 'Henrique Duarte Brandão', '68096979779', '1968-06-28', '11939051681', 'henrique.brandao70@exemplo.invalid', '03496817', 'Rua das Magnólias, 1885', 'Carrão', 'São Paulo', 'Instagram', TRUE, '2026-03-28 17:34:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (71, 'Tatiana Coutinho Valente', '02478993996', '1983-08-25', '11990491787', 'tatiana.valente71@exemplo.invalid', '03643383', 'Avenida das Flores, 123', 'Penha', 'São Paulo', 'Instagram', TRUE, '2025-11-10 17:00:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (72, 'Ana Moura Tavares', '02580250697', '1988-05-17', '11904058210', 'ana.tavares72@exemplo.invalid', '03523206', 'Rua das Magnólias, 745', 'Vila Formosa', 'São Paulo', 'Indicação', FALSE, '2025-11-05 17:18:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (73, 'Raquel Rezende Tavares', '89293669374', '2003-02-04', '11980173025', 'raquel.tavares73@exemplo.invalid', '08753859', 'Rua dos Ipês, 1417', 'Mogilar', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-02-14 10:01:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (74, 'Thiago Siqueira Nogueira', '54738415468', '1992-03-22', '11990742240', NULL, '03398290', 'Rua das Palmeiras, 444', 'Tatuapé', 'São Paulo', 'Instagram', TRUE, '2026-02-09 17:31:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (75, 'Yasmin Peixoto Coutinho', '40225937506', '1997-03-06', '11943535793', 'yasmin.coutinho75@exemplo.invalid', '03275940', 'Rua das Magnólias, 1105', 'Água Rasa', 'São Paulo', 'Instagram', TRUE, '2026-03-17 13:22:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (76, 'Débora Macedo Macedo', '61839039060', '1976-10-18', '11941174846', NULL, '03337488', 'Rua das Palmeiras, 1308', 'Tatuapé', 'São Paulo', 'Google', TRUE, '2026-02-27 14:51:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (77, 'Renata Gomes Moura', '92766809260', '1966-08-15', '11981442995', NULL, '03066185', 'Rua dos Girassóis, 1124', 'Belém', 'São Paulo', 'Instagram', TRUE, '2026-08-09 17:24:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (78, 'Raquel Teixeira Duarte', '30648809773', '1973-11-21', '11942614427', 'raquel.duarte78@exemplo.invalid', '03185770', 'Rua das Acácias, 640', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2026-07-19 15:46:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (79, 'Carlos Ramos Antunes', '68618021580', '1993-12-06', '11931048256', 'carlos.antunes79@exemplo.invalid', '03317740', 'Rua das Palmeiras, 1912', 'Tatuapé', 'São Paulo', 'Indicação', TRUE, '2025-11-30 14:54:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (80, 'Felipe Teixeira Gomes', '82434318614', '1972-05-05', '11938328199', 'felipe.gomes80@exemplo.invalid', '08717185', 'Rua dos Ipês, 2696', 'Mogilar', 'Mogi das Cruzes', 'Instagram', FALSE, '2026-05-16 11:56:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (81, 'Larissa Pacheco Pacheco', '37376853049', '2003-04-12', '11945907449', NULL, '08706151', 'Rua dos Cedros, 2646', 'Vila Oliveira', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-03-19 13:32:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (82, 'Rafael Gomes Lacerda', '08137734660', '2001-07-22', '11967985712', 'rafael.lacerda82@exemplo.invalid', '03597164', 'Rua dos Jacarandás, 1710', 'Vila Formosa', 'São Paulo', 'Google', TRUE, '2025-11-25 10:32:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (83, 'Tatiana Ramos Coutinho', '71362265039', '1976-05-17', '11954254239', 'tatiana.coutinho83@exemplo.invalid', '03341907', 'Travessa das Orquídeas, 246', 'Tatuapé', 'São Paulo', 'Indicação', TRUE, '2025-10-20 15:21:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (84, 'Eduarda Coutinho Lacerda', '65434454910', '1997-07-26', '11987988911', 'eduarda.lacerda84@exemplo.invalid', '03395496', 'Rua das Violetas, 52', 'Tatuapé', 'São Paulo', 'Instagram', TRUE, '2026-01-05 16:16:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (85, 'Larissa Rezende Esteves', '01477522131', '1974-02-21', '11990960738', 'larissa.esteves85@exemplo.invalid', '07158157', 'Rua dos Cedros, 1240', 'Macedo', 'Guarulhos', 'Indicação', TRUE, '2025-12-15 16:36:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (86, 'Diego Valente Lacerda', '47448525131', '1978-10-16', '11999993218', 'diego.lacerda86@exemplo.invalid', '03602925', 'Rua dos Jacarandás, 2874', 'Penha', 'São Paulo', 'Google', TRUE, '2025-12-15 18:34:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (87, 'Aline Xavier Fontes', '11243537981', '1997-03-10', '11935026404', NULL, '03192152', 'Rua das Violetas, 2761', 'Vila Prudente', 'São Paulo', 'Instagram', TRUE, '2026-01-29 15:59:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (88, 'Larissa Cardoso Valente', '73355894010', '1985-08-12', '11925916648', 'larissa.valente88@exemplo.invalid', '03674972', 'Rua dos Cedros, 853', 'Penha', 'São Paulo', 'Indicação', TRUE, '2025-12-24 15:38:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (89, 'Raquel Faria Xavier', '76540059035', '1976-03-16', '11960890501', 'raquel.xavier89@exemplo.invalid', '03367173', 'Avenida dos Pinheiros Exemplo, 279', 'Tatuapé', 'São Paulo', 'Instagram', TRUE, '2026-01-13 13:53:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (90, 'Bruna Leal Siqueira', '82808946597', '1981-03-26', '11931741869', 'bruna.siqueira90@exemplo.invalid', '07113583', 'Rua dos Girassóis, 2745', 'Macedo', 'Guarulhos', 'Indicação', TRUE, '2026-06-03 11:27:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (91, 'Yasmin Faria Brandão', '38746292608', '1984-08-15', '11902410060', 'yasmin.brandao91@exemplo.invalid', '03152103', 'Rua das Magnólias, 2483', 'Mooca', 'São Paulo', 'Google', TRUE, '2025-11-30 10:55:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (92, 'Mariana Xavier Siqueira', '07188532613', '1977-12-14', '11903729848', 'mariana.siqueira92@exemplo.invalid', '03356633', 'Rua das Palmeiras, 1418', 'Tatuapé', 'São Paulo', 'Indicação', TRUE, '2026-01-13 12:38:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (93, 'Juliana Vasconcelos Moura', '23949769773', '1981-08-04', '11928771808', 'juliana.moura93@exemplo.invalid', '08215198', 'Rua dos Cedros, 1878', 'Itaquera', 'São Paulo', 'Instagram', TRUE, '2026-01-10 16:41:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (94, 'Vanessa Barros Faria', '38198344861', '1999-05-16', '11986780443', 'vanessa.faria94@exemplo.invalid', '03100693', 'Rua dos Cedros, 1692', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2026-05-16 12:50:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (95, 'Flávia Antunes Sampaio', '71403236585', '1990-12-09', '11971510522', NULL, '03527722', 'Rua das Hortênsias, 852', 'Vila Formosa', 'São Paulo', 'Indicação', TRUE, '2026-02-28 15:45:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (96, 'Débora Teixeira Brandão', '87060188665', '1983-09-02', '11984247798', 'debora.brandao96@exemplo.invalid', '03093559', 'Avenida dos Pinheiros Exemplo, 141', 'Belém', 'São Paulo', 'Indicação', TRUE, '2026-01-25 13:58:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (97, 'Tatiana Esteves Vasconcelos', '94728049264', '1994-03-13', '11955289146', 'tatiana.vasconcelos97@exemplo.invalid', '03157677', 'Avenida das Flores, 1430', 'Mooca', 'São Paulo', 'Indicação', TRUE, '2025-11-18 15:26:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (98, 'Helena Ramos Pacheco', '77593318273', '2004-08-16', '11921712768', 'helena.pacheco98@exemplo.invalid', '03187156', 'Travessa das Orquídeas, 1792', 'Mooca', 'São Paulo', 'Indicação', TRUE, '2025-09-25 12:27:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (99, 'Lívia Tavares Antunes', '36877889541', '1995-10-16', '11915913789', 'livia.antunes99@exemplo.invalid', '03370840', 'Rua dos Ipês, 911', 'Tatuapé', 'São Paulo', 'Indicação', FALSE, '2025-11-21 17:20:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (100, 'Priscila Siqueira Queiroz', '20081615795', '1978-06-01', '11919187025', 'priscila.queiroz100@exemplo.invalid', '02075188', 'Rua dos Ipês, 2126', 'Santana', 'São Paulo', 'WhatsApp', TRUE, '2026-01-01 14:58:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (101, 'Helena Siqueira Duarte', '86269617669', '2001-07-10', '11935828643', NULL, '04136663', 'Rua das Acácias, 1840', 'Vila Mariana', 'São Paulo', 'Instagram', TRUE, '2026-08-11 10:29:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (102, 'Ana Esteves Peixoto', '58602214367', '1995-03-12', '11924590198', 'ana.peixoto102@exemplo.invalid', '03397080', 'Travessa das Orquídeas, 2436', 'Tatuapé', 'São Paulo', 'Instagram', TRUE, '2025-10-15 18:24:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (103, 'Beatriz Moura Moura', '09576386390', '1977-06-09', '11995522356', 'beatriz.moura103@exemplo.invalid', '08751291', 'Rua das Acácias, 1721', 'Mogilar', 'Mogi das Cruzes', 'Google', TRUE, '2026-04-20 16:05:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (104, 'Vanessa Macedo Leal', '77338312370', '2004-06-22', '11947948081', 'vanessa.leal104@exemplo.invalid', '08726429', 'Rua das Magnólias, 788', 'Vila Oliveira', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-01-16 16:40:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (105, 'Mateus Macedo Teixeira', '35988684130', '1970-01-16', '11982477704', 'mateus.teixeira105@exemplo.invalid', '03213604', 'Rua dos Cedros, 1563', 'Água Rasa', 'São Paulo', 'Facebook', TRUE, '2025-09-25 17:03:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (106, 'Bruno Queiroz Tavares', '79508811277', '2004-02-18', '11955845908', 'bruno.tavares106@exemplo.invalid', '03003093', 'Travessa das Orquídeas, 284', 'Belém', 'São Paulo', 'Indicação', TRUE, '2025-10-08 09:52:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (107, 'Isabela Faria Brandão', '06897749745', '1998-01-09', '11977247589', 'isabela.brandao107@exemplo.invalid', '08716461', 'Travessa das Orquídeas, 395', 'Vila Oliveira', 'Mogi das Cruzes', 'Indicação', TRUE, '2026-01-12 09:27:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (108, 'Natália Antunes Xavier', '27643277575', '1965-01-10', '11972888797', 'natalia.xavier108@exemplo.invalid', '08765203', 'Avenida das Flores, 1298', 'Centro', 'Mogi das Cruzes', 'Instagram', TRUE, '2025-11-09 14:33:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (109, 'Mariana Queiroz Lacerda', '46752594210', '1977-11-14', '11928656436', 'mariana.lacerda109@exemplo.invalid', '08738872', 'Rua dos Ipês, 1080', 'Mogilar', 'Mogi das Cruzes', 'Indicação', TRUE, '2026-03-05 09:13:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (110, 'Henrique Valente Esteves', '54373222592', '1996-03-14', '11929708206', 'henrique.esteves110@exemplo.invalid', '08793045', 'Avenida dos Pinheiros Exemplo, 1414', 'Braz Cubas', 'Mogi das Cruzes', 'Instagram', FALSE, '2025-11-02 15:53:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (111, 'Débora Dias Brandão', '83275323245', '1984-10-14', '11956543165', 'debora.brandao111@exemplo.invalid', '03394768', 'Rua das Acácias, 2560', 'Tatuapé', 'São Paulo', 'Indicação', TRUE, '2026-08-06 15:06:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (112, 'Raquel Macedo Esteves', '20443949522', '1990-09-06', '11995346981', 'raquel.esteves112@exemplo.invalid', '04180158', 'Rua das Hortênsias, 489', 'Vila Mariana', 'São Paulo', 'Instagram', TRUE, '2026-08-05 17:06:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (113, 'Fernanda Sampaio Nogueira', '15896819919', '1988-06-14', '11933349471', 'fernanda.nogueira113@exemplo.invalid', '08712516', 'Rua dos Ipês, 1391', 'Centro', 'Mogi das Cruzes', 'Instagram', FALSE, '2025-10-19 12:51:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (114, 'Mateus Macedo Pacheco', '18546503435', '1971-03-13', '11942554244', 'mateus.pacheco114@exemplo.invalid', '08710746', 'Rua das Palmeiras, 745', 'Centro', 'Mogi das Cruzes', 'Google', TRUE, '2025-10-06 14:29:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (115, 'Raquel Pacheco Sampaio', '68406486481', '1987-04-14', '11965153871', 'raquel.sampaio115@exemplo.invalid', '03123131', 'Rua dos Girassóis, 311', 'Mooca', 'São Paulo', 'Google', TRUE, '2026-03-14 11:35:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (116, 'Marina Guimarães Peixoto', '81464666130', '1970-10-17', '11967472013', NULL, '04102354', 'Rua das Acácias, 2790', 'Vila Mariana', 'São Paulo', 'Indicação', TRUE, '2026-05-04 14:28:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (117, 'Elisa Guimarães Almeida', '05258616886', '1990-05-25', '11915406575', 'elisa.almeida117@exemplo.invalid', '08783734', 'Rua das Acácias, 2684', 'Vila Oliveira', 'Mogi das Cruzes', 'Instagram', TRUE, '2025-10-27 13:30:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (118, 'Raquel Peixoto Tavares', '30200418300', '1994-04-14', '11999146446', 'raquel.tavares118@exemplo.invalid', '08783651', 'Travessa das Orquídeas, 1803', 'Vila Oliveira', 'Mogi das Cruzes', 'Instagram', TRUE, '2026-01-05 16:33:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (119, 'Thiago Xavier Queiroz', '16129683170', '1999-10-28', '11947733459', 'thiago.queiroz119@exemplo.invalid', '08718824', 'Rua das Violetas, 1634', 'Vila Oliveira', 'Mogi das Cruzes', 'Google', TRUE, '2026-01-08 16:40:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (120, 'Patrícia Almeida Tavares', '33972439555', '1973-01-25', '11968459158', 'patricia.tavares120@exemplo.invalid', '08782368', 'Travessa das Orquídeas, 2341', 'Centro', 'Mogi das Cruzes', 'Instagram', TRUE, '2025-09-24 09:53:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (121, 'Carla Macedo Brandão', '16090925977', '2002-08-06', '11917521105', 'carla.brandao121@exemplo.invalid', '03132729', 'Rua das Palmeiras, 1694', 'Vila Prudente', 'São Paulo', 'Instagram', TRUE, '2025-11-08 09:37:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (122, 'Flávia Antunes Guimarães', '66475057410', '1983-08-27', '11978493953', 'flavia.guimaraes122@exemplo.invalid', '03168259', 'Rua dos Ipês, 2279', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2025-11-05 14:26:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (123, 'Thiago Antunes Teixeira', '66052847980', '1969-07-26', '11993113625', 'thiago.teixeira123@exemplo.invalid', '03209803', 'Rua das Violetas, 2621', 'Água Rasa', 'São Paulo', 'Indicação', TRUE, '2025-10-11 18:34:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (124, 'Lucas Duarte Barros', '32202342087', '1998-11-17', '11900820670', 'lucas.barros124@exemplo.invalid', '03123998', 'Travessa das Orquídeas, 2110', 'Mooca', 'São Paulo', 'Instagram', TRUE, '2026-07-05 09:48:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (125, 'Mateus Cardoso Rezende', '16107847405', '2002-07-05', '11915901082', 'mateus.rezende125@exemplo.invalid', '03058440', 'Rua das Palmeiras, 395', 'Belém', 'São Paulo', 'WhatsApp', TRUE, '2026-04-10 12:57:00');
INSERT INTO paciente (id_paciente, nome_completo, cpf, data_nasc, telefone_paciente, email_paciente, cep_paciente, endereco_paciente, bairro_paciente, cidade_paciente, origem_captacao, ativo, criado_em) VALUES (126, 'Elisa Xavier Pacheco', '91060281953', '1966-07-12', '11976353255', NULL, '03143893', 'Rua dos Ipês, 957', 'Mooca', 'São Paulo', 'Indicação', TRUE, '2026-02-02 14:55:00');
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (1, 1, 98, 1, '2025-10-02 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (2, 1, 46, 2, '2025-10-02 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (3, 1, 120, 3, '2025-10-03 15:00:00', 'Realizado', 'Pix', 115.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (4, 1, 105, 3, '2025-10-06 16:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (5, 1, 67, 3, '2025-10-08 10:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (6, 1, 114, 3, '2025-10-13 13:00:00', 'Realizado', 'Cartão de crédito', 80.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (7, 1, 16, 1, '2025-10-14 15:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (8, 1, 53, 3, '2025-10-14 17:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (9, 1, 123, 1, '2025-10-15 10:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (10, 1, 106, 3, '2025-10-16 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (11, 1, 52, 2, '2025-10-17 14:00:00', 'Realizado', 'Pix', 80.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (12, 1, 34, 1, '2025-10-20 14:00:00', 'Realizado', 'Pix', 65.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (13, 1, 102, 2, '2025-10-20 15:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (14, 1, 113, 3, '2025-10-22 10:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (15, 1, 48, 2, '2025-10-27 10:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (16, 1, 53, 2, '2025-10-27 16:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (17, 1, 83, 3, '2025-10-27 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (18, 1, 117, 3, '2025-10-29 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (19, 1, 46, 1, '2025-11-03 14:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (20, 1, 21, 2, '2025-11-06 11:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (21, 1, 102, 2, '2025-11-10 13:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (22, 1, 110, 3, '2025-11-11 11:00:00', 'Realizado', 'Pix', 160.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (23, 1, 122, 2, '2025-11-13 10:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (24, 1, 72, 3, '2025-11-13 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (25, 1, 26, 3, '2025-11-13 14:30:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (26, 1, 7, 2, '2025-11-17 11:00:00', 'Realizado', 'Pix', 80.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (27, 1, 108, 3, '2025-11-17 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (28, 1, 23, 1, '2025-11-17 13:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (29, 1, 121, 1, '2025-11-17 14:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (30, 1, 71, 2, '2025-11-18 10:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (31, 1, 63, 1, '2025-11-19 10:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (32, 1, 54, 1, '2025-11-19 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (33, 1, 65, 2, '2025-11-21 13:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (34, 1, 97, 3, '2025-11-21 16:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (35, 1, 121, 1, '2025-11-24 09:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (36, 1, 99, 2, '2025-11-27 09:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (37, 1, 82, 1, '2025-11-27 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (38, 1, 31, 1, '2025-12-01 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (39, 1, 91, 1, '2025-12-04 13:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (40, 1, 49, 1, '2025-12-08 09:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (41, 1, 37, 2, '2025-12-08 10:00:00', 'Realizado', 'Dinheiro', 130.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (42, 1, 79, 2, '2025-12-08 10:30:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (43, 1, 85, 2, '2025-12-17 11:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (44, 1, 53, 2, '2025-12-19 16:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (45, 1, 120, 3, '2025-12-24 09:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (46, 1, 13, 2, '2025-12-24 13:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (47, 1, 86, 2, '2025-12-24 13:30:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (48, 1, 122, 1, '2025-12-25 09:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (49, 1, 16, 3, '2025-12-25 09:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (50, 1, 5, 3, '2025-12-25 09:30:00', 'Realizado', 'Pix', 60.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (51, 1, 110, 3, '2025-12-26 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (52, 1, 32, 3, '2025-12-29 09:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (53, 1, 45, 2, '2025-12-30 09:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (54, 1, 88, 2, '2025-12-31 13:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (55, 1, 9, 2, '2025-12-31 14:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (56, 1, 105, 1, '2026-01-01 14:00:00', 'Realizado', 'Dinheiro', 120.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (57, 1, 4, 1, '2026-01-01 15:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (58, 1, 1, 3, '2026-01-05 10:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (59, 1, 55, 1, '2026-01-05 13:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (60, 1, 47, 3, '2026-01-06 16:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (61, 1, 79, 2, '2026-01-07 15:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (62, 1, 16, 3, '2026-01-08 13:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (63, 1, 100, 2, '2026-01-08 17:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (64, 1, 118, 3, '2026-01-09 09:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (65, 1, 58, 3, '2026-01-13 10:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (66, 1, 119, 3, '2026-01-13 15:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (67, 1, 118, 3, '2026-01-15 13:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (68, 1, 9, 1, '2026-01-19 11:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (69, 1, 92, 1, '2026-01-19 13:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (70, 1, 67, 1, '2026-01-19 14:00:00', 'Realizado', 'Cartão de crédito', 240.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (71, 1, 50, 3, '2026-01-19 15:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (72, 1, 26, 3, '2026-01-19 16:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (73, 1, 93, 3, '2026-01-19 17:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (74, 1, 107, 3, '2026-01-19 17:30:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (75, 1, 104, 3, '2026-01-20 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (76, 1, 89, 1, '2026-01-21 13:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (77, 1, 100, 2, '2026-01-22 15:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (78, 1, 25, 1, '2026-01-26 10:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (79, 1, 15, 1, '2026-01-27 10:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (80, 1, 49, 2, '2026-01-27 13:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (81, 1, 119, 3, '2026-01-28 15:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (82, 1, 9, 2, '2026-01-29 15:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (83, 1, 58, 3, '2026-02-02 09:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (84, 1, 20, 3, '2026-02-02 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (85, 1, 119, 3, '2026-02-02 11:30:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (86, 1, 29, 1, '2026-02-02 13:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (87, 1, 6, 3, '2026-02-02 15:00:00', 'Realizado', 'Cartão de crédito', 170.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (88, 1, 98, 1, '2026-02-02 16:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (89, 1, 126, 1, '2026-02-04 17:00:00', 'Realizado', 'Cartão de débito', 95.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (90, 1, 96, 1, '2026-02-05 09:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (91, 1, 87, 3, '2026-02-06 16:00:00', 'Realizado', 'Cartão de crédito', 130.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (92, 1, 106, 1, '2026-02-09 09:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (93, 1, 98, 1, '2026-02-09 13:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (94, 1, 97, 3, '2026-02-13 11:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (95, 1, 22, 2, '2026-02-16 13:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (96, 1, 43, 2, '2026-02-17 17:00:00', 'Realizado', 'Pix', 115.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (97, 1, 38, 3, '2026-02-18 16:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (98, 1, 74, 2, '2026-02-19 17:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (99, 1, 30, 2, '2026-02-23 15:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (100, 1, 73, 1, '2026-02-25 11:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (101, 1, 32, 3, '2026-03-02 10:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (102, 1, 36, 1, '2026-03-02 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (103, 1, 11, 3, '2026-03-02 11:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (104, 1, 93, 2, '2026-03-02 13:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (105, 1, 67, 1, '2026-03-02 14:00:00', 'Realizado', 'Cartão de crédito', 65.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (106, 1, 61, 1, '2026-03-03 10:00:00', 'Realizado', 'Pix', 65.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (107, 1, 95, 2, '2026-03-04 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (108, 1, 21, 3, '2026-03-06 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (109, 1, 28, 3, '2026-03-09 09:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (110, 1, 39, 1, '2026-03-09 10:00:00', 'Realizado', 'Pix', 95.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (111, 1, 8, 2, '2026-03-09 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (112, 1, 27, 1, '2026-03-09 14:00:00', 'Realizado', 'Pix', 80.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (113, 1, 44, 2, '2026-03-09 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (114, 1, 38, 3, '2026-03-09 17:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (115, 1, 109, 3, '2026-03-09 17:30:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (116, 1, 76, 2, '2026-03-11 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (117, 1, 34, 2, '2026-03-13 16:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (118, 1, 115, 1, '2026-03-16 09:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (119, 1, 60, 3, '2026-03-16 10:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (120, 1, 68, 1, '2026-03-17 17:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (121, 1, 118, 3, '2026-03-18 10:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (122, 1, 117, 3, '2026-03-20 14:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (123, 1, 81, 3, '2026-03-23 13:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (124, 1, 75, 3, '2026-03-23 14:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (125, 1, 39, 2, '2026-03-23 15:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (126, 1, 95, 1, '2026-03-24 17:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (127, 1, 53, 2, '2026-03-26 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (128, 1, 63, 1, '2026-03-30 15:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (129, 1, 106, 1, '2026-03-31 10:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (130, 1, 91, 1, '2026-04-03 14:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (131, 1, 70, 2, '2026-04-03 14:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (132, 1, 72, 3, '2026-04-03 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (133, 1, 61, 2, '2026-04-10 13:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (134, 1, 91, 1, '2026-04-13 13:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (135, 1, 115, 1, '2026-04-13 16:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (136, 1, 107, 3, '2026-04-14 11:00:00', 'Realizado', 'Pix', 160.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (137, 1, 70, 1, '2026-04-15 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (138, 1, 114, 1, '2026-04-17 13:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (139, 1, 54, 1, '2026-04-20 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (140, 1, 125, 1, '2026-04-22 16:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (141, 1, 71, 2, '2026-04-24 09:00:00', 'Realizado', 'Pix', 80.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (142, 1, 44, 2, '2026-04-27 10:00:00', 'Realizado', 'Cartão de crédito', 160.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (143, 1, 103, 3, '2026-04-27 10:00:00', 'Realizado', 'Cartão de crédito', 65.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (144, 1, 26, 3, '2026-04-27 16:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (145, 1, 56, 1, '2026-04-30 16:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (146, 1, 33, 3, '2026-04-30 16:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (147, 1, 5, 3, '2026-05-01 16:00:00', 'Realizado', 'Cartão de crédito', 160.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (148, 1, 93, 2, '2026-05-07 15:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (149, 1, 68, 2, '2026-05-11 10:00:00', 'Realizado', 'Pix', 120.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (150, 1, 116, 2, '2026-05-11 13:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (151, 1, 43, 2, '2026-05-11 13:30:00', 'Realizado', 'Pix', 130.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (152, 1, 125, 1, '2026-05-12 15:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (153, 1, 51, 1, '2026-05-15 11:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (154, 1, 80, 3, '2026-05-18 09:00:00', 'Realizado', 'Cartão de crédito', 155.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (155, 1, 81, 3, '2026-05-19 15:00:00', 'Realizado', 'Pix', 80.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (156, 1, 44, 2, '2026-05-19 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (157, 1, 110, 3, '2026-05-20 11:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (158, 1, 107, 3, '2026-05-21 17:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (159, 1, 97, 1, '2026-05-25 09:00:00', 'Realizado', 'Cartão de crédito', 115.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (160, 1, 94, 1, '2026-05-25 10:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (161, 1, 49, 2, '2026-05-25 11:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (162, 1, 66, 2, '2026-05-25 17:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (163, 1, 42, 1, '2026-05-26 11:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (164, 1, 12, 3, '2026-05-26 17:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (165, 1, 86, 2, '2026-06-02 11:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (166, 1, 1, 3, '2026-06-04 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (167, 1, 52, 2, '2026-06-04 15:00:00', 'Realizado', 'Pix', 120.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (168, 1, 94, 1, '2026-06-05 11:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (169, 1, 79, 2, '2026-06-08 13:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (170, 1, 24, 1, '2026-06-08 14:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (171, 1, 62, 2, '2026-06-08 14:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (172, 1, 90, 2, '2026-06-10 09:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (173, 1, 96, 1, '2026-06-12 11:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (174, 1, 19, 3, '2026-06-12 11:00:00', 'Realizado', 'Pix', 230.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (175, 1, 94, 3, '2026-06-16 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (176, 1, 81, 3, '2026-06-22 10:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (177, 1, 123, 3, '2026-06-22 11:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (178, 1, 4, 1, '2026-06-22 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (179, 1, 55, 1, '2026-06-23 10:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (180, 1, 24, 2, '2026-06-26 16:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (181, 1, 48, 2, '2026-06-30 14:00:00', 'Realizado', 'Cartão de crédito', 65.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (182, 1, 3, 3, '2026-07-01 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (183, 1, 96, 1, '2026-07-02 16:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (184, 1, 23, 1, '2026-07-06 11:00:00', 'Realizado', 'Pix', 75.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (185, 1, 29, 1, '2026-07-09 15:00:00', 'Realizado', 'Dinheiro', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (186, 1, 99, 2, '2026-07-09 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (187, 1, 3, 3, '2026-07-13 11:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (188, 1, 64, 3, '2026-07-13 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (189, 1, 46, 1, '2026-07-14 10:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (190, 1, 64, 3, '2026-07-14 14:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (191, 1, 9, 1, '2026-07-15 17:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (192, 1, 124, 1, '2026-07-16 17:00:00', 'Realizado', 'Pix', 80.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (193, 1, 24, 1, '2026-07-17 09:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (194, 1, 52, 2, '2026-07-20 11:00:00', 'Realizado', 'Cartão de crédito', 75.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (195, 1, 20, 1, '2026-07-20 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (196, 1, 73, 3, '2026-07-21 10:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (197, 1, 2, 2, '2026-07-24 10:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (198, 1, 61, 3, '2026-07-27 14:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (199, 1, 59, 1, '2026-07-28 09:00:00', 'Realizado', 'Cartão de crédito', 65.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (200, 1, 36, 1, '2026-07-29 10:00:00', 'Realizado', 'Cartão de crédito', 120.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (201, 1, 65, 2, '2026-07-30 14:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (202, 1, 88, 1, '2026-07-30 15:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (203, 1, 24, 1, '2026-07-30 17:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (204, 1, 102, 2, '2026-07-30 17:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (205, 1, 63, 1, '2026-07-30 17:30:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (206, 1, 119, 3, '2026-08-03 09:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (207, 1, 34, 1, '2026-08-03 15:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (208, 1, 9, 2, '2026-08-03 16:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (209, 1, 39, 2, '2026-08-10 09:00:00', 'Realizado', 'Cartão de crédito', 60.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (210, 1, 65, 2, '2026-08-12 10:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (211, 1, 112, 2, '2026-08-12 14:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (212, 1, 83, 2, '2026-08-12 16:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (213, 1, 109, 3, '2026-08-14 09:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (214, 1, 113, 3, '2026-08-17 09:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (215, 1, 77, 2, '2026-08-17 10:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (216, 1, 111, 2, '2026-08-17 14:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (217, 1, 40, 1, '2026-08-17 15:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (218, 1, 31, 1, '2026-08-18 11:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (219, 1, 85, 2, '2026-08-18 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (220, 1, 69, 1, '2026-08-18 16:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (221, 1, 7, 2, '2026-08-19 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (222, 1, 35, 2, '2026-08-20 14:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (223, 1, 101, 2, '2026-08-21 10:00:00', 'Realizado', 'Pix', 215.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (224, 1, 120, 3, '2026-08-24 11:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (225, 1, 126, 3, '2026-08-26 14:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (226, 1, 65, 2, '2026-08-27 16:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (227, 1, 28, 3, '2026-08-28 10:00:00', 'Realizado', 'Pix', 60.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (228, 1, 106, 1, '2026-08-31 10:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (229, 1, 17, 1, '2026-08-31 14:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (230, 1, 43, 2, '2026-09-02 10:00:00', 'Cancelado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (231, 1, 40, 2, '2026-09-07 10:00:00', 'Realizado', 'Pix', 230.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (232, 1, 47, 3, '2026-09-07 15:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (233, 1, 117, 3, '2026-09-07 16:00:00', 'Realizado', 'Dinheiro', 245.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (234, 1, 61, 1, '2026-09-08 10:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (235, 1, 13, 2, '2026-09-09 14:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (236, 1, 126, 1, '2026-09-14 11:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (237, 1, 41, 2, '2026-09-15 17:00:00', 'Realizado', 'Pix', 120.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (238, 1, 43, 2, '2026-09-18 13:00:00', 'Realizado', 'Pix', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (239, 1, 120, 3, '2026-09-18 13:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (240, 1, 57, 3, '2026-09-18 14:00:00', 'Realizado', 'Pix', 350.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (241, 1, 115, 1, '2026-09-21 09:00:00', 'Realizado', 'Pix', 105.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (242, 1, 125, 1, '2026-09-21 10:00:00', 'Realizado', 'Dinheiro', 60.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (243, 1, 13, 2, '2026-09-21 17:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (244, 1, 16, 3, '2026-10-05 11:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (245, 1, 125, 1, '2026-10-06 11:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (246, 1, 79, 2, '2026-10-12 10:00:00', 'Realizado', 'Cartão de crédito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (247, 1, 120, 3, '2026-10-12 10:00:00', 'Realizado', 'Dinheiro', 160.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (248, 1, 55, 1, '2026-10-13 13:00:00', 'Faltou', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (249, 1, 110, 3, '2026-10-14 15:00:00', 'Realizado', 'Cartão de débito', 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (250, 1, 103, 3, '2026-10-15 13:00:00', 'Realizado', 'Dinheiro', 120.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (251, 1, 125, 1, '2026-10-19 09:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (252, 1, 98, 1, '2026-10-19 09:30:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (253, 1, 42, 1, '2026-10-19 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (254, 1, 93, 2, '2026-10-19 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (255, 1, 102, 2, '2026-10-19 15:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (256, 1, 3, 3, '2026-10-19 15:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (257, 1, 95, 2, '2026-10-19 16:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (258, 1, 106, 1, '2026-10-23 10:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (259, 1, 9, 1, '2026-10-23 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (260, 1, 55, 1, '2026-10-26 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (261, 1, 45, 2, '2026-11-03 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (262, 1, 123, 1, '2026-10-20 11:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (263, 1, 117, 3, '2026-10-20 15:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (264, 1, 119, 3, '2026-10-20 10:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (265, 1, 86, 1, '2026-10-20 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (266, 1, 79, 3, '2026-10-21 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (267, 1, 6, 2, '2026-10-21 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (268, 1, 81, 3, '2026-10-21 09:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (269, 1, 70, 2, '2026-10-21 10:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (270, 1, 91, 1, '2026-10-21 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (271, 1, 20, 3, '2026-10-22 15:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (272, 1, 103, 3, '2026-10-22 09:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (273, 1, 62, 1, '2026-10-22 09:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (274, 1, 11, 1, '2026-10-22 09:30:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (275, 1, 51, 2, '2026-10-23 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (276, 1, 111, 2, '2026-10-23 13:30:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (277, 1, 33, 3, '2026-10-26 17:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (278, 1, 32, 3, '2026-10-26 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (279, 1, 126, 2, '2026-10-26 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (280, 1, 8, 1, '2026-10-26 10:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (281, 1, 2, 3, '2026-10-27 11:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (282, 1, 54, 1, '2026-10-27 17:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (283, 1, 107, 3, '2026-10-27 11:30:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (284, 1, 122, 1, '2026-10-28 17:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (285, 1, 5, 3, '2026-10-28 11:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (286, 1, 97, 2, '2026-10-28 15:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (287, 1, 109, 3, '2026-10-28 10:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (288, 1, 76, 3, '2026-10-28 16:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (289, 1, 124, 1, '2026-10-29 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (290, 1, 13, 2, '2026-10-29 11:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (291, 1, 69, 1, '2026-10-29 16:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (292, 1, 56, 1, '2026-10-29 17:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (293, 1, 104, 3, '2026-10-29 10:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (294, 1, 96, 1, '2026-10-30 09:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (295, 1, 41, 2, '2026-10-30 17:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (296, 1, 30, 1, '2026-10-30 11:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (297, 1, 57, 3, '2026-11-03 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (298, 1, 47, 3, '2026-11-03 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (299, 1, 24, 2, '2026-11-04 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (300, 1, 87, 3, '2026-11-04 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (301, 1, 35, 2, '2026-11-05 17:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (302, 1, 121, 1, '2026-11-05 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (303, 1, 65, 2, '2026-11-05 10:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (304, 1, 40, 2, '2026-11-05 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (305, 1, 118, 3, '2026-11-05 13:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (306, 1, 49, 2, '2026-11-06 16:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (307, 1, 101, 2, '2026-11-06 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (308, 1, 66, 2, '2026-11-06 15:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (309, 1, 19, 3, '2026-11-06 17:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (310, 1, 29, 2, '2026-11-06 16:30:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (311, 1, 12, 3, '2026-11-09 09:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (312, 1, 36, 1, '2026-11-09 16:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (313, 1, 64, 1, '2026-11-09 14:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento (id_atendimento, id_profissional, id_paciente, id_unidade, data_hora, status, forma_pagamento, desconto) VALUES (314, 1, 7, 2, '2026-11-09 09:00:00', 'Agendado', NULL, 0.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (1, 1, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (2, 1, 5, 2.00, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (3, 2, 1, 20.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (4, 2, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (5, 3, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (6, 4, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (7, 4, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (8, 5, 5, 1.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (9, 6, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (10, 6, 2, 2.00, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (11, 7, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (12, 7, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (13, 9, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (14, 9, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (15, 10, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (16, 10, 1, 30.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (17, 11, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (18, 11, 2, 1.50, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (19, 12, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (20, 12, 1, 60.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (21, 14, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (22, 14, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (23, 15, 2, 1.00, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (24, 15, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (25, 16, 1, 60.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (26, 17, 1, 40.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (27, 18, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (28, 18, 1, 40.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (29, 19, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (30, 19, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (31, 20, 2, 2.00, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (32, 21, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (33, 22, 2, 1.00, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (34, 22, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (35, 23, 5, 1.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (36, 24, 1, 30.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (37, 25, 1, 40.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (38, 26, 2, 1.50, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (39, 26, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (40, 27, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (41, 27, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (42, 28, 2, 1.50, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (43, 30, 1, 20.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (44, 31, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (45, 32, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (46, 33, 1, 30.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (47, 34, 1, 40.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (48, 35, 2, 2.00, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (49, 36, 1, 30.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (50, 37, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (51, 37, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (52, 38, 5, 1.50, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (53, 39, 5, 1.00, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (54, 40, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (55, 41, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (56, 42, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (57, 43, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (58, 43, 1, 40.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (59, 44, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (60, 45, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (61, 45, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (62, 47, 2, 1.00, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (63, 48, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (64, 49, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (65, 50, 1, 50.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (66, 51, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (67, 51, 1, 50.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (68, 52, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (69, 53, 2, 1.00, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (70, 54, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (71, 54, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (72, 56, 1, 40.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (73, 57, 1, 20.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (74, 58, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (75, 58, 1, 60.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (76, 59, 1, 60.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (77, 59, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (78, 60, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (79, 61, 5, 1.50, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (80, 61, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (81, 62, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (82, 62, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (83, 64, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (84, 64, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (85, 69, 1, 20.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (86, 70, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (87, 70, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (88, 71, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (89, 72, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (90, 72, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (91, 73, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (92, 73, 2, 2.00, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (93, 74, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (94, 74, 5, 2.00, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (95, 75, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (96, 76, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (97, 76, 5, 2.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (98, 78, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (99, 78, 5, 2.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (100, 79, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (101, 79, 1, 60.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (102, 80, 1, 50.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (103, 80, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (104, 81, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (105, 81, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (106, 82, 1, 30.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (107, 83, 2, 1.00, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (108, 84, 1, 50.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (109, 85, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (110, 86, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (111, 86, 2, 1.50, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (112, 87, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (113, 87, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (114, 88, 1, 50.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (115, 88, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (116, 89, 5, 1.50, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (117, 90, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (118, 90, 5, 1.50, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (119, 91, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (120, 91, 1, 30.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (121, 92, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (122, 93, 5, 1.50, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (123, 94, 1, 30.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (124, 94, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (125, 95, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (126, 96, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (127, 98, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (128, 99, 1, 20.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (129, 100, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (130, 100, 1, 60.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (131, 101, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (132, 101, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (133, 102, 1, 30.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (134, 102, 5, 1.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (135, 104, 2, 1.00, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (136, 104, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (137, 105, 1, 40.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (138, 105, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (139, 106, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (140, 106, 1, 50.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (141, 107, 2, 1.50, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (142, 107, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (143, 108, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (144, 108, 2, 2.00, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (145, 109, 1, 30.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (146, 110, 5, 2.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (147, 111, 5, 1.50, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (148, 112, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (149, 112, 2, 2.00, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (150, 113, 1, 50.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (151, 113, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (152, 114, 2, 2.00, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (153, 115, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (154, 115, 1, 60.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (155, 116, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (156, 116, 5, 2.00, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (157, 117, 1, 50.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (158, 117, 5, 1.50, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (159, 118, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (160, 118, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (161, 119, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (162, 119, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (163, 120, 1, 20.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (164, 120, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (165, 122, 1, 60.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (166, 123, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (167, 123, 1, 40.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (168, 124, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (169, 124, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (170, 125, 1, 40.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (171, 126, 2, 1.00, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (172, 127, 2, 2.00, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (173, 128, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (174, 129, 1, 30.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (175, 132, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (176, 133, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (177, 134, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (178, 135, 2, 2.00, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (179, 136, 2, 1.00, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (180, 136, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (181, 137, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (182, 139, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (183, 141, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (184, 142, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (185, 143, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (186, 143, 1, 50.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (187, 144, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (188, 144, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (189, 145, 5, 1.50, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (190, 146, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (191, 147, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (192, 148, 1, 50.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (193, 149, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (194, 149, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (195, 151, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (196, 152, 1, 50.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (197, 153, 2, 1.50, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (198, 154, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (199, 154, 2, 1.00, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (200, 155, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (201, 156, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (202, 157, 1, 50.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (203, 157, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (204, 158, 1, 50.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (205, 158, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (206, 159, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (207, 161, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (208, 162, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (209, 162, 2, 1.00, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (210, 164, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (211, 165, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (212, 165, 2, 1.50, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (213, 166, 1, 20.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (214, 166, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (215, 167, 1, 60.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (216, 168, 5, 2.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (217, 169, 1, 30.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (218, 169, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (219, 171, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (220, 171, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (221, 172, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (222, 172, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (223, 173, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (224, 174, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (225, 175, 2, 2.00, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (226, 176, 5, 1.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (227, 176, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (228, 177, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (229, 178, 1, 30.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (230, 179, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (231, 179, 5, 1.50, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (232, 181, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (233, 181, 1, 50.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (234, 182, 1, 30.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (235, 183, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (236, 183, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (237, 184, 2, 2.00, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (238, 185, 1, 60.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (239, 186, 2, 2.00, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (240, 187, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (241, 187, 5, 2.00, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (242, 188, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (243, 189, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (244, 192, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (245, 194, 2, 1.50, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (246, 195, 1, 20.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (247, 196, 2, 2.00, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (248, 196, 5, 2.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (249, 197, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (250, 198, 1, 30.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (251, 198, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (252, 199, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (253, 199, 1, 40.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (254, 200, 1, 50.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (255, 202, 5, 1.50, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (256, 203, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (257, 205, 5, 1.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (258, 206, 1, 40.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (259, 206, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (260, 207, 1, 60.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (261, 207, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (262, 208, 1, 40.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (263, 209, 1, 60.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (264, 211, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (265, 211, 5, 1.00, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (266, 212, 1, 30.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (267, 212, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (268, 213, 1, 40.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (269, 214, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (270, 215, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (271, 215, 5, 1.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (272, 216, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (273, 216, 1, 20.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (274, 218, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (275, 218, 1, 20.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (276, 219, 5, 1.00, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (277, 220, 1, 20.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (278, 221, 1, 60.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (279, 222, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (280, 222, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (281, 223, 1, 50.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (282, 223, 5, 1.50, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (283, 224, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (284, 224, 1, 60.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (285, 226, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (286, 227, 1, 40.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (287, 228, 1, 20.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (288, 229, 5, 1.00, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (289, 231, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (290, 232, 1, 40.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (291, 233, 2, 2.00, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (292, 233, 5, 2.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (293, 234, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (294, 234, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (295, 235, 2, 2.00, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (296, 237, 1, 30.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (297, 238, 4, 1.00, 'Face (terço inferior)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (298, 239, 5, 1.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (299, 240, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (300, 240, 1, 20.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (301, 241, 5, 2.00, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (302, 241, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (303, 242, 1, 50.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (304, 243, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (305, 244, 1, 60.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (306, 244, 6, 1.00, 'Face', 100.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (307, 246, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (308, 247, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (309, 249, 1, 60.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (310, 250, 1, 50.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (311, 251, 1, 50.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (312, 252, 1, 40.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (313, 253, 2, 2.00, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (314, 254, 2, 2.00, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (315, 255, 1, 40.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (316, 256, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (317, 257, 1, 20.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (318, 258, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (319, 259, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (320, 260, 2, 1.50, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (321, 261, 2, 1.00, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (322, 262, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (323, 263, 5, 2.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (324, 264, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (325, 264, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (326, 265, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (327, 266, 1, 50.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (328, 267, 1, 30.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (329, 268, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (330, 269, 1, 60.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (331, 270, 2, 2.00, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (332, 271, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (333, 272, 1, 60.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (334, 273, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (335, 274, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (336, 275, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (337, 275, 4, 1.00, 'Pescoço', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (338, 276, 1, 30.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (339, 277, 1, 40.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (340, 278, 1, 50.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (341, 279, 1, 50.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (342, 280, 2, 1.00, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (343, 281, 1, 20.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (344, 282, 1, 20.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (345, 282, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (346, 283, 1, 50.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (347, 284, 2, 1.00, 'Mandíbula', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (348, 285, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (349, 286, 1, 40.00, 'Testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (350, 287, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (351, 288, 1, 60.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (352, 289, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (353, 290, 1, 60.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (354, 291, 1, 20.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (355, 291, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (356, 292, 3, 1.00, 'Contorno labial', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (357, 292, 2, 1.50, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (358, 293, 1, 20.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (359, 294, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (360, 295, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (361, 295, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (362, 296, 3, 1.00, 'Lábios', 1300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (363, 297, 1, 20.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (364, 298, 5, 1.50, 'Face e pescoço', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (365, 299, 2, 1.50, 'Mento', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (366, 300, 2, 2.00, 'Sulco nasogeniano', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (367, 301, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (368, 302, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (369, 303, 1, 60.00, 'Pés de galinha', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (370, 304, 1, 50.00, 'Glabela', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (371, 305, 1, 30.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (372, 306, 1, 40.00, 'Glabela e testa', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (373, 307, 2, 1.00, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (374, 308, 1, 60.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (375, 308, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (376, 309, 5, 1.00, 'Face', 950.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (377, 309, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (378, 310, 2, 2.00, 'Malar', 1500.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (379, 310, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (380, 311, 1, 50.00, 'Terço superior', 1200.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (381, 312, 4, 1.00, 'Face (terço médio)', 2300.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (382, 313, 7, 1.00, 'Região periorbital', 1600.00);
INSERT INTO atendimento_procedimento (id_atend_proc, id_atendimento, id_procedimento, quantidade_aplicada, regiao_aplicada, valor_cobrado) VALUES (383, 314, 2, 2.00, 'Mandíbula', 1500.00);
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (1, 2, 7, '2025-09-22', 3.00, 600.42, 'MIL250947', '2027-09-01');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (2, 4, 14, '2025-09-22', 100.00, 0.61, 'SER250941', '2029-10-02');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (3, 3, 1, '2025-09-23', 200.00, 14.28, 'BOT250942', '2027-03-26');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (4, 1, 9, '2025-09-23', 2.00, 2031.32, 'SCU250997', '2028-03-13');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (5, 4, 21, '2025-09-23', 500.00, 0.04, 'ALG250989', '2030-09-17');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (6, 3, 3, '2025-09-24', 100.00, 7.24, 'BOT250920', '2027-03-12');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (7, 2, 11, '2025-09-24', 1.00, 716.57, 'STI250968', '2027-09-21');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (8, 4, 13, '2025-09-24', 20.00, 10.01, 'CAN250973', '2029-09-18');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (9, 4, 15, '2025-09-24', 50.00, 0.93, 'LUV250983', '2028-09-15');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (10, 4, 17, '2025-09-24', 1000.00, 0.03, 'CLO250922', '2027-09-22');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (11, 1, 4, '2025-09-25', 4.00, 1013.14, 'YVO250919', '2027-09-12');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (12, 2, 20, '2025-09-25', 30.00, 2.53, 'ANE250993', '2027-03-24');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (13, 3, 10, '2025-09-26', 1.00, 887.88, 'PLL250935', '2026-09-30');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (14, 2, 6, '2025-09-27', 4.00, 569.77, 'ALU250993', '2027-10-10');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (15, 4, 12, '2025-09-27', 100.00, 0.47, 'AGU250937', '2029-10-02');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (16, 2, 16, '2025-09-27', 100.00, 0.36, 'GAZ250997', '2028-09-30');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (17, 2, 18, '2025-09-27', 250.00, 0.02, 'SOR250971', '2027-09-09');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (18, 4, 19, '2025-09-27', 100.00, 0.20, 'AGU250938', '2027-09-24');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (19, 3, 20, '2025-09-27', 30.00, 2.50, 'ANE250948', '2027-03-14');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (20, 4, 22, '2025-09-27', 50.00, 0.30, 'MAS250958', '2030-09-13');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (21, 1, 2, '2025-09-28', 100.00, 17.49, 'LET250977', '2027-04-10');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (22, 1, 5, '2025-09-28', 4.00, 598.43, 'UP 250995', '2027-09-21');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (23, 1, 5, '2025-09-28', 4.00, 594.48, 'UP 250980', '2027-10-14');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (24, 1, 8, '2025-09-28', 1.00, 1941.21, 'RAD250970', '2027-10-08');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (25, 2, 18, '2025-09-28', 250.00, 0.02, 'SOR250910', '2026-11-19');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (26, 1, 1, '2025-09-29', 200.00, 14.11, 'BOT250930', '2027-04-01');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (27, 3, 9, '2025-10-02', 2.00, 2176.95, 'SCU251053', '2028-04-06');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (28, 3, 6, '2025-10-04', 4.00, 550.96, 'ALU251068', '2027-10-05');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (29, 2, 4, '2025-10-12', 4.00, 953.88, 'YVO251028', '2027-09-26');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (30, 4, 15, '2025-10-17', 50.00, 0.90, 'LUV251069', '2028-10-20');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (31, 1, 2, '2025-10-19', 100.00, 17.13, 'LET251016', '2027-04-14');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (32, 2, 16, '2025-10-19', 100.00, 0.35, 'GAZ251098', '2028-10-14');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (33, 1, 7, '2025-10-20', 3.00, 571.32, 'MIL251039', '2027-10-07');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (34, 3, 3, '2025-10-24', 100.00, 7.82, 'BOT251097', '2027-05-02');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (35, 1, 4, '2025-10-25', 4.00, 1006.89, 'YVO251051', '2027-11-12');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (36, 4, 13, '2025-11-05', 20.00, 9.67, 'CAN251186', '2029-11-12');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (37, 1, 5, '2025-11-08', 4.00, 607.08, 'UP 251114', '2027-10-31');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (38, 2, 6, '2025-11-08', 4.00, 528.44, 'ALU251161', '2027-10-23');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (39, 4, 12, '2025-11-10', 100.00, 0.45, 'AGU251119', '2029-10-30');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (40, 3, 1, '2025-11-11', 200.00, 14.08, 'BOT251151', '2027-05-11');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (41, 3, 20, '2025-11-12', 30.00, 2.48, 'ANE251111', '2027-04-25');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (42, 2, 4, '2025-11-14', 4.00, 984.88, 'YVO251165', '2027-11-18');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (43, 3, 9, '2025-11-26', 2.00, 2174.57, 'SCU251193', '2028-05-30');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (44, 1, 5, '2025-12-03', 4.00, 590.86, 'UP 251279', '2027-11-18');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (45, 2, 16, '2025-12-05', 100.00, 0.35, 'GAZ251238', '2028-12-06');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (46, 3, 6, '2025-12-06', 4.00, 521.51, 'ALU251276', '2027-12-08');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (47, 1, 4, '2025-12-21', 4.00, 941.52, 'YVO251276', '2027-12-19');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (48, 1, 1, '2025-12-22', 200.00, 14.66, 'BOT251238', '2027-06-19');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (49, 3, 10, '2025-12-23', 1.00, 856.70, 'PLL251253', '2027-12-29');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (50, 1, 8, '2025-12-27', 1.00, 1854.94, 'RAD251290', '2027-12-30');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (51, 4, 19, '2025-12-27', 100.00, 0.20, 'AGU251262', '2027-12-17');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (52, 1, 8, '2025-12-28', 1.00, 1879.33, 'RAD251273', '2028-01-12');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (53, 4, 14, '2025-12-29', 100.00, 0.60, 'SER251281', '2030-01-04');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (54, 4, 15, '2025-12-30', 50.00, 0.89, 'LUV251220', '2028-12-18');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (55, 3, 1, '2026-01-02', 200.00, 14.34, 'BOT260164', '2027-07-22');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (56, 3, 9, '2026-01-02', 2.00, 2029.97, 'SCU260122', '2028-06-27');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (57, 2, 20, '2026-01-04', 30.00, 2.52, 'ANE260184', '2027-07-17');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (58, 1, 4, '2026-01-14', 4.00, 945.90, 'YVO260182', '2028-01-26');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (59, 3, 6, '2026-01-16', 4.00, 552.33, 'ALU260154', '2028-02-03');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (60, 2, 11, '2026-01-16', 1.00, 727.25, 'STI260140', '2028-01-07');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (61, 1, 5, '2026-01-17', 4.00, 651.15, 'UP 260153', '2028-01-06');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (62, 1, 5, '2026-01-17', 4.00, 595.72, 'UP 260141', '2028-01-22');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (63, 3, 9, '2026-01-18', 2.00, 2156.49, 'SCU260145', '2028-07-18');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (64, 4, 16, '2026-01-23', 100.00, 0.33, 'GAZ260185', '2029-01-08');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (65, 4, 12, '2026-01-25', 100.00, 0.45, 'AGU260153', '2030-01-31');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (66, 3, 1, '2026-01-27', 200.00, 15.18, 'BOT260111', '2027-07-08');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (67, 1, 7, '2026-01-27', 3.00, 586.62, 'MIL260156', '2028-01-09');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (68, 4, 13, '2026-01-27', 20.00, 9.82, 'CAN260135', '2030-02-04');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (69, 1, 5, '2026-02-03', 4.00, 594.90, 'UP 260236', '2028-02-22');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (70, 3, 20, '2026-02-03', 30.00, 2.52, 'ANE260250', '2027-08-23');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (71, 1, 5, '2026-02-08', 4.00, 652.72, 'UP 260220', '2028-02-07');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (72, 2, 6, '2026-02-14', 4.00, 561.35, 'ALU260213', '2028-02-13');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (73, 1, 2, '2026-02-20', 100.00, 17.25, 'LET260226', '2027-08-31');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (74, 3, 3, '2026-02-25', 100.00, 8.05, 'BOT260265', '2027-08-18');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (75, 2, 4, '2026-02-25', 4.00, 945.74, 'YVO260254', '2028-03-02');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (76, 4, 16, '2026-03-01', 100.00, 0.36, 'GAZ260358', '2029-02-27');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (77, 1, 1, '2026-03-05', 200.00, 14.99, 'BOT260378', '2027-09-11');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (78, 1, 4, '2026-03-06', 4.00, 935.66, 'YVO260353', '2028-02-18');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (79, 1, 5, '2026-03-06', 4.00, 655.66, 'UP 260320', '2028-03-02');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (80, 3, 3, '2026-03-08', 100.00, 7.94, 'BOT260393', '2027-09-02');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (81, 1, 5, '2026-03-08', 4.00, 606.71, 'UP 260322', '2028-03-25');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (82, 4, 15, '2026-03-08', 50.00, 0.87, 'LUV260383', '2029-03-15');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (83, 3, 20, '2026-03-10', 30.00, 2.53, 'ANE260325', '2027-08-22');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (84, 3, 9, '2026-03-11', 2.00, 2109.54, 'SCU260362', '2028-09-06');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (85, 4, 12, '2026-03-12', 100.00, 0.47, 'AGU260359', '2030-03-26');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (86, 1, 4, '2026-03-20', 4.00, 984.42, 'YVO260386', '2028-03-22');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (87, 3, 1, '2026-03-21', 200.00, 14.69, 'BOT260360', '2027-09-25');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (88, 2, 11, '2026-03-21', 1.00, 741.12, 'STI260334', '2028-04-01');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (89, 3, 9, '2026-03-29', 2.00, 2116.93, 'SCU260346', '2028-09-21');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (90, 2, 4, '2026-04-09', 4.00, 967.77, 'YVO260415', '2028-03-31');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (91, 1, 7, '2026-04-09', 3.00, 557.87, 'MIL260428', '2028-03-21');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (92, 4, 13, '2026-04-11', 20.00, 9.99, 'CAN260459', '2030-04-06');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (93, 4, 16, '2026-04-11', 100.00, 0.36, 'GAZ260486', '2029-03-21');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (94, 3, 10, '2026-04-22', 1.00, 894.29, 'PLL260485', '2028-04-27');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (95, 1, 5, '2026-04-25', 4.00, 594.84, 'UP 260418', '2028-04-27');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (96, 2, 7, '2026-04-29', 3.00, 612.23, 'MIL260422', '2028-05-01');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (97, 4, 17, '2026-04-30', 1000.00, 0.03, 'CLO260459', '2028-04-15');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (98, 3, 20, '2026-05-06', 30.00, 2.41, 'ANE260548', '2027-10-26');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (99, 3, 3, '2026-05-07', 100.00, 7.67, 'BOT260517', '2027-11-04');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (100, 4, 19, '2026-05-07', 100.00, 0.20, 'AGU260560', '2028-04-24');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (101, 1, 9, '2026-05-08', 2.00, 2166.75, 'SCU260550', '2028-10-17');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (102, 3, 6, '2026-05-09', 4.00, 564.91, 'ALU260578', '2028-05-17');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (103, 1, 7, '2026-05-16', 3.00, 578.11, 'MIL260582', '2028-05-21');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (104, 3, 1, '2026-05-17', 200.00, 14.32, 'BOT260555', '2027-11-26');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (105, 1, 2, '2026-05-20', 100.00, 18.01, 'LET260511', '2026-12-07');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (106, 1, 4, '2026-05-21', 4.00, 935.94, 'YVO260578', '2028-05-27');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (107, 1, 9, '2026-05-23', 2.00, 2016.24, 'SCU260580', '2028-11-09');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (108, 4, 15, '2026-05-23', 50.00, 0.93, 'LUV260562', '2029-05-21');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (109, 4, 16, '2026-06-01', 100.00, 0.34, 'GAZ260642', '2029-05-14');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (110, 3, 9, '2026-06-07', 2.00, 2016.21, 'SCU260682', '2028-11-30');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (111, 2, 6, '2026-06-08', 4.00, 558.87, 'ALU260683', '2028-06-15');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (112, 3, 10, '2026-06-11', 1.00, 874.62, 'PLL260668', '2028-05-28');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (113, 2, 4, '2026-06-14', 4.00, 1033.53, 'YVO260659', '2028-06-19');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (114, 1, 5, '2026-06-17', 4.00, 630.27, 'UP 260660', '2028-06-20');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (115, 3, 20, '2026-06-21', 30.00, 2.55, 'ANE260618', '2028-01-09');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (116, 3, 1, '2026-06-30', 200.00, 15.19, 'BOT260623', '2028-01-02');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (117, 4, 13, '2026-07-04', 20.00, 9.51, 'CAN260768', '2030-07-16');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (118, 3, 3, '2026-07-08', 100.00, 7.62, 'BOT260774', '2027-12-30');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (119, 1, 5, '2026-07-12', 4.00, 649.96, 'UP 260729', '2028-06-27');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (120, 2, 12, '2026-07-12', 100.00, 0.44, 'AGU260796', '2030-07-10');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (121, 1, 4, '2026-07-19', 4.00, 966.79, 'YVO260790', '2028-07-20');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (122, 3, 6, '2026-07-20', 4.00, 571.57, 'ALU260769', '2028-07-08');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (123, 2, 20, '2026-07-25', 30.00, 2.45, 'ANE260789', '2028-02-10');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (124, 4, 16, '2026-07-26', 100.00, 0.37, 'GAZ260792', '2029-07-10');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (125, 1, 5, '2026-07-27', 4.00, 656.78, 'UP 260733', '2028-07-10');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (126, 3, 1, '2026-07-31', 200.00, 14.66, 'BOT260765', '2028-02-16');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (127, 3, 1, '2026-08-10', 200.00, 14.01, 'BOT260819', '2028-02-23');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (128, 1, 5, '2026-08-10', 4.00, 615.41, 'UP 260866', '2028-07-20');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (129, 3, 6, '2026-08-11', 4.00, 523.05, 'ALU260825', '2026-11-03');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (130, 1, 1, '2026-08-16', 200.00, 13.87, 'BOT260847', '2028-02-11');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (131, 4, 15, '2026-08-16', 50.00, 0.86, 'LUV260889', '2029-08-18');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (132, 2, 16, '2026-08-24', 100.00, 0.36, 'GAZ260896', '2029-08-12');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (133, 2, 12, '2026-08-26', 100.00, 0.47, 'AGU260885', '2030-08-04');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (134, 1, 5, '2026-08-27', 2.00, 615.09, 'UP 260856', '2028-08-09');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (135, 2, 14, '2026-08-28', 100.00, 0.60, 'SER260831', '2030-09-15');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (136, 3, 9, '2026-09-03', 2.00, 2155.69, 'SCU260918', '2029-02-15');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (137, 1, 4, '2026-09-05', 4.00, 1006.90, 'YVO260999', '2028-08-24');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (138, 1, 5, '2026-09-05', 2.00, 632.60, 'UP 260953', '2028-08-28');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (139, 1, 5, '2026-09-14', 1.00, 634.09, 'UP 260980', '2028-09-24');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (140, 1, 9, '2026-09-15', 2.00, 2070.04, 'SCU260967', '2029-03-05');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (141, 1, 5, '2026-09-18', 2.00, 636.22, 'UP 260945', '2028-10-04');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (142, 3, 1, '2026-09-20', 200.00, 14.64, 'BOT260991', '2028-03-04');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (143, 3, 3, '2026-09-30', 100.00, 7.31, 'BOT260937', '2028-04-01');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (144, 2, 7, '2026-10-10', 1.00, 614.33, 'MIL261059', '2028-10-24');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (145, 1, 7, '2026-10-10', 1.00, 591.28, 'MIL261098', '2028-10-21');
INSERT INTO compra (id_compra, id_fornecedor, id_insumo, data_compra, quantidade, preco_unitario, lote, data_validade) VALUES (146, 3, 3, '2026-10-11', 100.00, 7.59, 'BOT261093', '2028-04-28');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1, 5, 1, 2.00, '2025-10-02 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (2, 1, 2, 22.00, '2025-10-02 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (3, 12, 1, 4.00, '2025-10-02 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (4, 12, 2, 3.00, '2025-10-02 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (5, 20, 1, 3.00, '2025-10-02 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (6, 14, 2, 1.00, '2025-10-02 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (7, 15, 1, 1.00, '2025-10-02 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (8, 18, 2, 2.50, '2025-10-02 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (9, 16, 1, 3.00, '2025-10-02 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (10, 15, 2, 1.00, '2025-10-02 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (11, 17, 2, 5.00, '2025-10-02 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (12, 16, 2, 4.00, '2025-10-02 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (13, 9, 3, 1.00, '2025-10-03 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (14, 19, 3, 9.00, '2025-10-03 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (15, 13, 3, 1.00, '2025-10-03 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (16, 14, 3, 2.00, '2025-10-03 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (17, 15, 3, 1.00, '2025-10-03 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (18, 17, 3, 5.00, '2025-10-03 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (19, 16, 3, 4.00, '2025-10-03 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (20, 6, 4, 1.00, '2025-10-06 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (21, 12, 4, 2.00, '2025-10-06 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (22, 20, 4, 1.50, '2025-10-06 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (23, 15, 4, 1.00, '2025-10-06 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (24, 16, 4, 3.00, '2025-10-06 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (25, 5, 5, 2.00, '2025-10-08 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (26, 12, 5, 4.00, '2025-10-08 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (27, 20, 5, 3.00, '2025-10-08 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (28, 15, 5, 1.00, '2025-10-08 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (29, 16, 5, 3.00, '2025-10-08 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (30, 4, 6, 1.50, '2025-10-13 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (31, 13, 6, 1.00, '2025-10-13 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (32, 12, 6, 1.00, '2025-10-13 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (33, 20, 6, 2.00, '2025-10-13 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (34, 15, 6, 1.00, '2025-10-13 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (35, 17, 6, 5.00, '2025-10-13 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (36, 16, 6, 4.00, '2025-10-13 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (37, 6, 7, 1.00, '2025-10-14 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (38, 12, 7, 2.00, '2025-10-14 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (39, 20, 7, 2.50, '2025-10-14 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (40, 15, 7, 1.00, '2025-10-14 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (41, 16, 7, 3.00, '2025-10-14 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (42, 6, 9, 1.00, '2025-10-15 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (43, 12, 9, 2.00, '2025-10-15 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (44, 20, 9, 2.00, '2025-10-15 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (45, 15, 9, 1.00, '2025-10-15 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (46, 16, 9, 3.00, '2025-10-15 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (47, 1, 10, 35.00, '2025-10-16 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (48, 12, 10, 3.00, '2025-10-16 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (49, 14, 10, 1.00, '2025-10-16 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (50, 18, 10, 2.50, '2025-10-16 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (51, 15, 10, 1.00, '2025-10-16 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (52, 17, 10, 5.50, '2025-10-16 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (53, 16, 10, 4.00, '2025-10-16 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (54, 4, 11, 1.50, '2025-10-17 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (55, 13, 11, 1.00, '2025-10-17 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (56, 12, 11, 1.00, '2025-10-17 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (57, 20, 11, 2.00, '2025-10-17 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (58, 15, 11, 1.00, '2025-10-17 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (59, 17, 11, 5.50, '2025-10-17 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (60, 16, 11, 4.00, '2025-10-17 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (61, 2, 12, 65.00, '2025-10-20 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (62, 12, 12, 3.00, '2025-10-20 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (63, 14, 12, 1.00, '2025-10-20 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (64, 18, 12, 2.50, '2025-10-20 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (65, 15, 12, 1.00, '2025-10-20 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (66, 17, 12, 5.50, '2025-10-20 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (67, 16, 12, 4.00, '2025-10-20 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (68, 7, 14, 1.00, '2025-10-22 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (69, 13, 14, 1.00, '2025-10-22 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (70, 20, 14, 1.00, '2025-10-22 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (71, 15, 14, 1.00, '2025-10-22 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (72, 16, 14, 3.00, '2025-10-22 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (73, 4, 15, 1.50, '2025-10-27 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (74, 13, 15, 1.00, '2025-10-27 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (75, 12, 15, 1.00, '2025-10-27 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (76, 20, 15, 2.00, '2025-10-27 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (77, 15, 15, 1.00, '2025-10-27 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (78, 17, 15, 5.50, '2025-10-27 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (79, 16, 15, 4.00, '2025-10-27 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (80, 1, 16, 60.00, '2025-10-27 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (81, 12, 16, 3.00, '2025-10-27 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (82, 14, 16, 1.00, '2025-10-27 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (83, 18, 16, 2.50, '2025-10-27 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (84, 15, 16, 1.00, '2025-10-27 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (85, 17, 16, 5.00, '2025-10-27 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (86, 16, 16, 3.00, '2025-10-27 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (87, 1, 17, 40.00, '2025-10-27 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (88, 12, 17, 3.00, '2025-10-27 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (89, 14, 17, 1.00, '2025-10-27 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (90, 18, 17, 2.50, '2025-10-27 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (91, 15, 17, 1.00, '2025-10-27 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (92, 17, 17, 5.50, '2025-10-27 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (93, 16, 17, 4.00, '2025-10-27 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (94, 3, 18, 40.00, '2025-10-29 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (95, 12, 18, 3.00, '2025-10-29 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (96, 14, 18, 1.00, '2025-10-29 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (97, 18, 18, 2.00, '2025-10-29 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (98, 15, 18, 1.00, '2025-10-29 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (99, 17, 18, 5.50, '2025-10-29 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (100, 16, 18, 4.00, '2025-10-29 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (101, 6, 19, 1.00, '2025-11-03 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (102, 12, 19, 2.00, '2025-11-03 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (103, 20, 19, 2.00, '2025-11-03 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (104, 15, 19, 1.00, '2025-11-03 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (105, 16, 19, 3.00, '2025-11-03 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (106, 4, 20, 1.50, '2025-11-06 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (107, 13, 20, 1.00, '2025-11-06 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (108, 12, 20, 1.00, '2025-11-06 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (109, 20, 20, 2.00, '2025-11-06 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (110, 15, 20, 1.00, '2025-11-06 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (111, 17, 20, 4.50, '2025-11-06 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (112, 16, 20, 5.00, '2025-11-06 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (113, 6, 21, 1.00, '2025-11-10 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (114, 12, 21, 2.00, '2025-11-10 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (115, 20, 21, 1.50, '2025-11-10 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (116, 15, 21, 1.00, '2025-11-10 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (117, 16, 21, 3.00, '2025-11-10 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (118, 4, 22, 1.50, '2025-11-11 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (119, 13, 22, 1.00, '2025-11-11 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (120, 12, 22, 1.00, '2025-11-11 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (121, 20, 22, 2.00, '2025-11-11 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (122, 15, 22, 1.00, '2025-11-11 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (123, 17, 22, 5.00, '2025-11-11 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (124, 16, 22, 4.00, '2025-11-11 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (125, 5, 23, 2.00, '2025-11-13 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (126, 12, 23, 4.00, '2025-11-13 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (127, 20, 23, 2.50, '2025-11-13 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (128, 15, 23, 1.00, '2025-11-13 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (129, 16, 23, 3.00, '2025-11-13 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (130, 1, 24, 35.00, '2025-11-13 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (131, 12, 24, 3.00, '2025-11-13 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (132, 14, 24, 1.00, '2025-11-13 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (133, 18, 24, 2.50, '2025-11-13 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (134, 15, 24, 1.00, '2025-11-13 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (135, 17, 24, 4.50, '2025-11-13 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (136, 16, 24, 4.00, '2025-11-13 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (137, 1, 25, 45.00, '2025-11-13 14:30:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (138, 12, 25, 3.00, '2025-11-13 14:31:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (139, 14, 25, 1.00, '2025-11-13 14:32:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (140, 18, 25, 2.50, '2025-11-13 14:33:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (141, 15, 25, 1.00, '2025-11-13 14:34:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (142, 17, 25, 5.00, '2025-11-13 14:35:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (143, 16, 25, 4.00, '2025-11-13 14:36:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (144, 14, NULL, 10.00, '2025-11-14 18:18:00', 'Perda: seringa danificada no transporte');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (145, 4, 26, 1.50, '2025-11-17 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (146, 9, 27, 1.00, '2025-11-17 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (147, 13, 26, 1.00, '2025-11-17 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (148, 19, 27, 7.00, '2025-11-17 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (149, 12, 26, 1.00, '2025-11-17 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (150, 13, 27, 1.00, '2025-11-17 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (151, 20, 26, 2.00, '2025-11-17 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (152, 14, 27, 2.00, '2025-11-17 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (153, 15, 26, 1.00, '2025-11-17 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (154, 15, 27, 1.00, '2025-11-17 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (155, 17, 26, 4.50, '2025-11-17 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (156, 17, 27, 5.50, '2025-11-17 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (157, 16, 26, 4.00, '2025-11-17 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (158, 16, 27, 5.00, '2025-11-17 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (159, 4, 28, 1.50, '2025-11-17 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (160, 13, 28, 1.00, '2025-11-17 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (161, 12, 28, 1.00, '2025-11-17 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (162, 20, 28, 2.00, '2025-11-17 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (163, 15, 28, 1.00, '2025-11-17 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (164, 17, 28, 4.50, '2025-11-17 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (165, 16, 28, 4.00, '2025-11-17 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (166, 1, 30, 20.00, '2025-11-18 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (167, 12, 30, 3.00, '2025-11-18 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (168, 14, 30, 1.00, '2025-11-18 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (169, 18, 30, 2.50, '2025-11-18 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (170, 15, 30, 1.00, '2025-11-18 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (171, 17, 30, 5.50, '2025-11-18 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (172, 16, 30, 4.00, '2025-11-18 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (173, 6, 31, 1.00, '2025-11-19 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (174, 12, 31, 2.00, '2025-11-19 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (175, 20, 31, 2.00, '2025-11-19 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (176, 15, 31, 1.00, '2025-11-19 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (177, 16, 31, 3.00, '2025-11-19 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (178, 6, 32, 1.00, '2025-11-19 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (179, 12, 32, 2.00, '2025-11-19 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (180, 20, 32, 2.00, '2025-11-19 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (181, 15, 32, 1.00, '2025-11-19 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (182, 16, 32, 3.00, '2025-11-19 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (183, 2, 33, 30.00, '2025-11-21 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (184, 12, 33, 3.00, '2025-11-21 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (185, 14, 33, 1.00, '2025-11-21 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (186, 18, 33, 2.50, '2025-11-21 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (187, 15, 33, 1.00, '2025-11-21 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (188, 17, 33, 5.00, '2025-11-21 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (189, 16, 33, 4.00, '2025-11-21 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (190, 1, 34, 42.00, '2025-11-21 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (191, 12, 34, 3.00, '2025-11-21 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (192, 14, 34, 1.00, '2025-11-21 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (193, 18, 34, 2.50, '2025-11-21 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (194, 15, 34, 1.00, '2025-11-21 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (195, 17, 34, 5.00, '2025-11-21 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (196, 16, 34, 4.00, '2025-11-21 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (197, 4, 35, 1.50, '2025-11-24 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (198, 13, 35, 1.00, '2025-11-24 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (199, 12, 35, 1.00, '2025-11-24 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (200, 20, 35, 2.00, '2025-11-24 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (201, 15, 35, 1.00, '2025-11-24 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (202, 17, 35, 5.00, '2025-11-24 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (203, 16, 35, 4.00, '2025-11-24 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (204, 1, 36, 32.00, '2025-11-27 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (205, 12, 36, 3.00, '2025-11-27 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (206, 14, 36, 1.00, '2025-11-27 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (207, 18, 36, 2.00, '2025-11-27 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (208, 15, 36, 1.00, '2025-11-27 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (209, 17, 36, 5.50, '2025-11-27 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (210, 16, 36, 4.00, '2025-11-27 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (211, 9, 37, 1.00, '2025-11-27 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (212, 19, 37, 7.00, '2025-11-27 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (213, 13, 37, 1.00, '2025-11-27 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (214, 14, 37, 2.00, '2025-11-27 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (215, 15, 37, 1.00, '2025-11-27 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (216, 17, 37, 4.50, '2025-11-27 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (217, 16, 37, 4.00, '2025-11-27 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (218, 5, 38, 2.00, '2025-12-01 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (219, 12, 38, 4.00, '2025-12-01 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (220, 20, 38, 3.50, '2025-12-01 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (221, 15, 38, 1.00, '2025-12-01 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (222, 16, 38, 3.00, '2025-12-01 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (223, 5, 39, 2.00, '2025-12-04 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (224, 12, 39, 4.00, '2025-12-04 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (225, 20, 39, 3.50, '2025-12-04 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (226, 15, 39, 1.00, '2025-12-04 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (227, 16, 39, 3.00, '2025-12-04 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (228, 21, NULL, 50.00, '2025-12-04 18:00:00', 'Perda: seringa danificada no transporte');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (229, 9, 40, 1.00, '2025-12-08 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (230, 19, 40, 9.00, '2025-12-08 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (231, 13, 40, 1.00, '2025-12-08 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (232, 14, 40, 2.00, '2025-12-08 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (233, 15, 40, 1.00, '2025-12-08 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (234, 17, 40, 5.00, '2025-12-08 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (235, 16, 40, 4.00, '2025-12-08 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (236, 6, 41, 1.00, '2025-12-08 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (237, 12, 41, 2.00, '2025-12-08 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (238, 20, 41, 2.00, '2025-12-08 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (239, 15, 41, 1.00, '2025-12-08 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (240, 16, 41, 3.00, '2025-12-08 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (241, 6, 42, 1.00, '2025-12-08 10:30:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (242, 12, 42, 2.00, '2025-12-08 10:31:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (243, 20, 42, 2.00, '2025-12-08 10:32:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (244, 15, 42, 1.00, '2025-12-08 10:33:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (245, 16, 42, 3.00, '2025-12-08 10:34:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (246, 1, 43, 40.00, '2025-12-17 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (247, 12, 43, 3.00, '2025-12-17 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (248, 14, 43, 1.00, '2025-12-17 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (249, 18, 43, 3.00, '2025-12-17 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (250, 15, 43, 1.00, '2025-12-17 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (251, 17, 43, 4.50, '2025-12-17 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (252, 16, 43, 4.00, '2025-12-17 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (253, 15, NULL, 5.00, '2025-12-17 18:34:00', 'Descarte: material vencido');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (254, 12, NULL, 10.00, '2025-12-18 18:39:00', 'Descarte: embalagem violada');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (255, 6, 44, 1.00, '2025-12-19 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (256, 12, 44, 2.00, '2025-12-19 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (257, 20, 44, 2.00, '2025-12-19 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (258, 15, 44, 1.00, '2025-12-19 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (259, 16, 44, 3.00, '2025-12-19 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (260, 6, 45, 1.00, '2025-12-24 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (261, 12, 45, 2.00, '2025-12-24 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (262, 20, 45, 2.00, '2025-12-24 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (263, 15, 45, 1.00, '2025-12-24 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (264, 16, 45, 3.00, '2025-12-24 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (265, 4, 47, 1.50, '2025-12-24 13:30:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (266, 13, 47, 1.00, '2025-12-24 13:31:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (267, 12, 47, 1.00, '2025-12-24 13:32:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (268, 20, 47, 2.00, '2025-12-24 13:33:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (269, 15, 47, 1.00, '2025-12-24 13:34:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (270, 17, 47, 4.50, '2025-12-24 13:35:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (271, 16, 47, 4.00, '2025-12-24 13:36:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (272, 10, 48, 1.00, '2025-12-25 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (273, 7, 49, 1.00, '2025-12-25 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (274, 19, 48, 8.00, '2025-12-25 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (275, 13, 49, 1.00, '2025-12-25 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (276, 13, 48, 1.00, '2025-12-25 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (277, 20, 49, 1.00, '2025-12-25 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (278, 14, 48, 2.00, '2025-12-25 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (279, 15, 49, 1.00, '2025-12-25 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (280, 15, 48, 1.00, '2025-12-25 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (281, 16, 49, 3.00, '2025-12-25 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (282, 17, 48, 5.50, '2025-12-25 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (283, 16, 48, 4.00, '2025-12-25 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (284, 1, 50, 50.00, '2025-12-25 09:30:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (285, 12, 50, 3.00, '2025-12-25 09:31:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (286, 14, 50, 1.00, '2025-12-25 09:32:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (287, 18, 50, 2.00, '2025-12-25 09:33:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (288, 15, 50, 1.00, '2025-12-25 09:34:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (289, 17, 50, 4.50, '2025-12-25 09:35:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (290, 16, 50, 5.00, '2025-12-25 09:36:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (291, 15, NULL, 5.00, '2025-12-25 18:39:00', 'Uso em demonstração interna');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (292, 1, 51, 55.00, '2025-12-26 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (293, 12, 51, 3.00, '2025-12-26 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (294, 14, 51, 1.00, '2025-12-26 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (295, 18, 51, 3.00, '2025-12-26 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (296, 15, 51, 1.00, '2025-12-26 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (297, 17, 51, 5.00, '2025-12-26 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (298, 16, 51, 4.00, '2025-12-26 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (299, 8, 52, 1.00, '2025-12-29 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (300, 19, 52, 7.50, '2025-12-29 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (301, 13, 52, 1.00, '2025-12-29 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (302, 14, 52, 2.00, '2025-12-29 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (303, 15, 52, 1.00, '2025-12-29 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (304, 17, 52, 5.50, '2025-12-29 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (305, 16, 52, 4.00, '2025-12-29 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (306, 4, 53, 1.50, '2025-12-30 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (307, 13, 53, 1.00, '2025-12-30 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (308, 12, 53, 1.00, '2025-12-30 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (309, 20, 53, 2.50, '2025-12-30 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (310, 15, 53, 1.00, '2025-12-30 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (311, 17, 53, 4.50, '2025-12-30 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (312, 16, 53, 4.00, '2025-12-30 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (313, 8, 54, 1.00, '2025-12-31 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (314, 19, 54, 8.50, '2025-12-31 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (315, 13, 54, 1.00, '2025-12-31 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (316, 14, 54, 2.00, '2025-12-31 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (317, 15, 54, 1.00, '2025-12-31 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (318, 17, 54, 5.00, '2025-12-31 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (319, 16, 54, 4.00, '2025-12-31 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (320, 1, 56, 42.00, '2026-01-01 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (321, 12, 56, 3.00, '2026-01-01 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (322, 14, 56, 1.00, '2026-01-01 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (323, 18, 56, 2.50, '2026-01-01 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (324, 15, 56, 1.00, '2026-01-01 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (325, 17, 56, 5.50, '2026-01-01 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (326, 16, 56, 3.00, '2026-01-01 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (327, 1, 57, 20.00, '2026-01-01 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (328, 12, 57, 3.00, '2026-01-01 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (329, 14, 57, 1.00, '2026-01-01 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (330, 18, 57, 2.00, '2026-01-01 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (331, 15, 57, 1.00, '2026-01-01 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (332, 17, 57, 5.50, '2026-01-01 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (333, 16, 57, 4.00, '2026-01-01 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (334, 1, 58, 60.00, '2026-01-05 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (335, 12, 58, 3.00, '2026-01-05 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (336, 14, 58, 1.00, '2026-01-05 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (337, 18, 58, 2.50, '2026-01-05 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (338, 15, 58, 1.00, '2026-01-05 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (339, 17, 58, 5.50, '2026-01-05 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (340, 16, 58, 4.00, '2026-01-05 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (341, 1, 59, 62.00, '2026-01-05 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (342, 12, 59, 3.00, '2026-01-05 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (343, 14, 59, 1.00, '2026-01-05 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (344, 18, 59, 2.00, '2026-01-05 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (345, 15, 59, 1.00, '2026-01-05 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (346, 17, 59, 5.00, '2026-01-05 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (347, 16, 59, 4.00, '2026-01-05 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (348, 9, 60, 1.00, '2026-01-06 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (349, 19, 60, 7.00, '2026-01-06 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (350, 13, 60, 1.00, '2026-01-06 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (351, 14, 60, 2.00, '2026-01-06 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (352, 15, 60, 1.00, '2026-01-06 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (353, 17, 60, 4.50, '2026-01-06 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (354, 16, 60, 5.00, '2026-01-06 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (355, 5, 61, 2.00, '2026-01-07 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (356, 12, 61, 5.00, '2026-01-07 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (357, 20, 61, 3.00, '2026-01-07 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (358, 15, 61, 1.00, '2026-01-07 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (359, 16, 61, 3.00, '2026-01-07 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (360, 9, 62, 1.00, '2026-01-08 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (361, 19, 62, 9.00, '2026-01-08 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (362, 13, 62, 1.00, '2026-01-08 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (363, 14, 62, 2.00, '2026-01-08 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (364, 15, 62, 1.00, '2026-01-08 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (365, 17, 62, 5.50, '2026-01-08 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (366, 16, 62, 4.00, '2026-01-08 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (367, 7, 64, 1.00, '2026-01-09 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (368, 13, 64, 1.00, '2026-01-09 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (369, 20, 64, 1.00, '2026-01-09 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (370, 15, 64, 1.00, '2026-01-09 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (371, 16, 64, 3.00, '2026-01-09 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (372, 14, NULL, 10.00, '2026-01-13 18:59:00', 'Perda no preparo: frasco contaminado');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (373, 1, 69, 20.00, '2026-01-19 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (374, 12, 69, 3.00, '2026-01-19 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (375, 14, 69, 1.00, '2026-01-19 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (376, 18, 69, 2.50, '2026-01-19 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (377, 15, 69, 1.00, '2026-01-19 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (378, 17, 69, 5.00, '2026-01-19 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (379, 16, 69, 3.00, '2026-01-19 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (380, 11, 70, 1.00, '2026-01-19 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (381, 19, 70, 8.00, '2026-01-19 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (382, 13, 70, 1.00, '2026-01-19 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (383, 14, 70, 2.00, '2026-01-19 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (384, 15, 70, 1.00, '2026-01-19 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (385, 17, 70, 5.50, '2026-01-19 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (386, 16, 70, 4.00, '2026-01-19 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (387, 6, 71, 1.00, '2026-01-19 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (388, 12, 71, 2.00, '2026-01-19 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (389, 20, 71, 2.00, '2026-01-19 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (390, 15, 71, 1.00, '2026-01-19 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (391, 16, 71, 3.00, '2026-01-19 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (392, 6, 72, 1.00, '2026-01-19 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (393, 12, 72, 2.00, '2026-01-19 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (394, 20, 72, 2.00, '2026-01-19 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (395, 15, 72, 1.00, '2026-01-19 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (396, 16, 72, 3.00, '2026-01-19 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (397, 4, 73, 1.50, '2026-01-19 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (398, 13, 73, 1.00, '2026-01-19 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (399, 12, 73, 1.00, '2026-01-19 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (400, 20, 73, 2.00, '2026-01-19 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (401, 15, 73, 1.00, '2026-01-19 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (402, 17, 73, 5.50, '2026-01-19 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (403, 16, 73, 4.00, '2026-01-19 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (404, 5, 74, 2.00, '2026-01-19 17:30:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (405, 12, 74, 4.00, '2026-01-19 17:31:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (406, 20, 74, 2.50, '2026-01-19 17:32:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (407, 15, 74, 1.00, '2026-01-19 17:33:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (408, 16, 74, 3.00, '2026-01-19 17:34:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (409, 9, 75, 1.00, '2026-01-20 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (410, 19, 75, 8.00, '2026-01-20 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (411, 13, 75, 1.00, '2026-01-20 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (412, 14, 75, 2.00, '2026-01-20 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (413, 15, 75, 1.00, '2026-01-20 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (414, 17, 75, 4.50, '2026-01-20 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (415, 16, 75, 3.00, '2026-01-20 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (416, 5, 76, 2.50, '2026-01-21 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (417, 12, 76, 4.00, '2026-01-21 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (418, 20, 76, 3.00, '2026-01-21 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (419, 15, 76, 1.00, '2026-01-21 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (420, 16, 76, 3.00, '2026-01-21 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (421, 5, 78, 2.00, '2026-01-26 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (422, 12, 78, 5.00, '2026-01-26 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (423, 20, 78, 3.00, '2026-01-26 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (424, 15, 78, 1.00, '2026-01-26 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (425, 16, 78, 3.00, '2026-01-26 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (426, 1, 79, 60.00, '2026-01-27 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (427, 12, 79, 3.00, '2026-01-27 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (428, 14, 79, 1.00, '2026-01-27 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (429, 18, 79, 3.00, '2026-01-27 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (430, 15, 79, 1.00, '2026-01-27 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (431, 17, 79, 5.50, '2026-01-27 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (432, 16, 79, 4.00, '2026-01-27 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (433, 1, 80, 52.00, '2026-01-27 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (434, 12, 80, 3.00, '2026-01-27 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (435, 14, 80, 1.00, '2026-01-27 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (436, 18, 80, 2.50, '2026-01-27 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (437, 15, 80, 1.00, '2026-01-27 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (438, 17, 80, 5.00, '2026-01-27 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (439, 16, 80, 4.00, '2026-01-27 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (440, 7, 81, 1.00, '2026-01-28 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (441, 13, 81, 1.00, '2026-01-28 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (442, 20, 81, 1.00, '2026-01-28 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (443, 15, 81, 1.00, '2026-01-28 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (444, 16, 81, 3.00, '2026-01-28 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (445, 1, 82, 32.00, '2026-01-29 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (446, 12, 82, 3.00, '2026-01-29 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (447, 14, 82, 1.00, '2026-01-29 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (448, 18, 82, 2.50, '2026-01-29 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (449, 15, 82, 1.00, '2026-01-29 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (450, 17, 82, 5.00, '2026-01-29 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (451, 16, 82, 4.00, '2026-01-29 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (452, 4, 83, 1.50, '2026-02-02 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (453, 13, 83, 1.00, '2026-02-02 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (454, 12, 83, 1.00, '2026-02-02 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (455, 20, 83, 2.00, '2026-02-02 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (456, 15, 83, 1.00, '2026-02-02 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (457, 17, 83, 5.00, '2026-02-02 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (458, 16, 83, 4.00, '2026-02-02 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (459, 3, 84, 50.00, '2026-02-02 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (460, 12, 84, 3.00, '2026-02-02 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (461, 14, 84, 1.00, '2026-02-02 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (462, 18, 84, 2.00, '2026-02-02 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (463, 15, 84, 1.00, '2026-02-02 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (464, 17, 84, 5.50, '2026-02-02 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (465, 16, 84, 4.00, '2026-02-02 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (466, 6, 85, 1.00, '2026-02-02 11:30:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (467, 12, 85, 2.00, '2026-02-02 11:31:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (468, 20, 85, 1.50, '2026-02-02 11:32:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (469, 15, 85, 1.00, '2026-02-02 11:33:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (470, 16, 85, 3.00, '2026-02-02 11:34:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (471, 4, 86, 1.50, '2026-02-02 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (472, 13, 86, 1.00, '2026-02-02 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (473, 12, 86, 1.00, '2026-02-02 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (474, 20, 86, 2.00, '2026-02-02 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (475, 15, 86, 1.00, '2026-02-02 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (476, 17, 86, 5.00, '2026-02-02 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (477, 16, 86, 4.00, '2026-02-02 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (478, 7, 87, 1.00, '2026-02-02 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (479, 13, 87, 1.00, '2026-02-02 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (480, 20, 87, 1.00, '2026-02-02 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (481, 15, 87, 1.00, '2026-02-02 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (482, 16, 87, 3.00, '2026-02-02 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (483, 1, 88, 50.00, '2026-02-02 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (484, 12, 88, 3.00, '2026-02-02 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (485, 14, 88, 1.00, '2026-02-02 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (486, 18, 88, 2.50, '2026-02-02 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (487, 15, 88, 1.00, '2026-02-02 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (488, 17, 88, 5.50, '2026-02-02 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (489, 16, 88, 4.00, '2026-02-02 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (490, 5, 89, 2.00, '2026-02-04 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (491, 12, 89, 4.00, '2026-02-04 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (492, 20, 89, 2.50, '2026-02-04 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (493, 15, 89, 1.00, '2026-02-04 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (494, 16, 89, 3.00, '2026-02-04 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (495, 5, 90, 2.00, '2026-02-05 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (496, 12, 90, 4.00, '2026-02-05 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (497, 20, 90, 3.00, '2026-02-05 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (498, 15, 90, 1.00, '2026-02-05 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (499, 16, 90, 3.00, '2026-02-05 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (500, 1, 91, 32.00, '2026-02-06 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (501, 12, 91, 3.00, '2026-02-06 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (502, 14, 91, 1.00, '2026-02-06 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (503, 18, 91, 3.00, '2026-02-06 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (504, 15, 91, 1.00, '2026-02-06 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (505, 17, 91, 5.00, '2026-02-06 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (506, 16, 91, 4.00, '2026-02-06 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (507, 6, 92, 1.00, '2026-02-09 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (508, 12, 92, 2.00, '2026-02-09 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (509, 20, 92, 2.00, '2026-02-09 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (510, 15, 92, 1.00, '2026-02-09 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (511, 16, 92, 3.00, '2026-02-09 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (512, 5, 93, 2.00, '2026-02-09 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (513, 12, 93, 4.00, '2026-02-09 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (514, 20, 93, 2.50, '2026-02-09 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (515, 15, 93, 1.00, '2026-02-09 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (516, 16, 93, 3.00, '2026-02-09 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (517, 1, 94, 30.00, '2026-02-13 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (518, 12, 94, 3.00, '2026-02-13 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (519, 14, 94, 1.00, '2026-02-13 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (520, 18, 94, 2.50, '2026-02-13 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (521, 15, 94, 1.00, '2026-02-13 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (522, 17, 94, 5.50, '2026-02-13 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (523, 16, 94, 4.00, '2026-02-13 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (524, 6, 95, 1.00, '2026-02-16 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (525, 12, 95, 2.00, '2026-02-16 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (526, 20, 95, 2.50, '2026-02-16 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (527, 15, 95, 1.00, '2026-02-16 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (528, 16, 95, 3.00, '2026-02-16 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (529, 9, 96, 1.00, '2026-02-17 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (530, 19, 96, 7.50, '2026-02-17 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (531, 13, 96, 1.00, '2026-02-17 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (532, 14, 96, 2.00, '2026-02-17 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (533, 15, 96, 1.00, '2026-02-17 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (534, 17, 96, 4.50, '2026-02-17 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (535, 16, 96, 4.00, '2026-02-17 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (536, 6, 98, 1.00, '2026-02-19 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (537, 12, 98, 2.00, '2026-02-19 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (538, 20, 98, 2.00, '2026-02-19 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (539, 15, 98, 1.00, '2026-02-19 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (540, 16, 98, 3.00, '2026-02-19 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (541, 21, NULL, 50.00, '2026-02-19 18:47:00', 'Descarte: material vencido');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (542, 2, 99, 22.00, '2026-02-23 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (543, 12, 99, 3.00, '2026-02-23 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (544, 14, 99, 1.00, '2026-02-23 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (545, 18, 99, 2.50, '2026-02-23 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (546, 15, 99, 1.00, '2026-02-23 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (547, 17, 99, 4.50, '2026-02-23 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (548, 16, 99, 4.00, '2026-02-23 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (549, 2, 100, 60.00, '2026-02-25 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (550, 12, 100, 3.00, '2026-02-25 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (551, 14, 100, 1.00, '2026-02-25 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (552, 18, 100, 2.00, '2026-02-25 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (553, 15, 100, 1.00, '2026-02-25 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (554, 17, 100, 5.50, '2026-02-25 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (555, 16, 100, 5.00, '2026-02-25 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (556, 6, 101, 1.00, '2026-03-02 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (557, 12, 101, 2.00, '2026-03-02 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (558, 20, 101, 1.50, '2026-03-02 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (559, 15, 101, 1.00, '2026-03-02 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (560, 16, 101, 3.00, '2026-03-02 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (561, 1, 102, 30.00, '2026-03-02 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (562, 12, 102, 3.00, '2026-03-02 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (563, 14, 102, 1.00, '2026-03-02 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (564, 18, 102, 2.50, '2026-03-02 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (565, 15, 102, 1.00, '2026-03-02 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (566, 17, 102, 5.50, '2026-03-02 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (567, 16, 102, 4.00, '2026-03-02 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (568, 5, 102, 2.00, '2026-03-02 11:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (569, 12, 102, 3.00, '2026-03-02 11:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (570, 20, 102, 3.00, '2026-03-02 11:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (571, 15, 102, 1.00, '2026-03-02 11:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (572, 16, 102, 3.00, '2026-03-02 11:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (573, 4, 104, 1.50, '2026-03-02 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (574, 13, 104, 1.00, '2026-03-02 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (575, 12, 104, 1.00, '2026-03-02 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (576, 20, 104, 1.50, '2026-03-02 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (577, 15, 104, 1.00, '2026-03-02 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (578, 17, 104, 5.00, '2026-03-02 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (579, 16, 104, 4.00, '2026-03-02 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (580, 3, 105, 40.00, '2026-03-02 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (581, 12, 105, 3.00, '2026-03-02 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (582, 14, 105, 1.00, '2026-03-02 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (583, 18, 105, 2.50, '2026-03-02 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (584, 15, 105, 1.00, '2026-03-02 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (585, 17, 105, 5.00, '2026-03-02 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (586, 16, 105, 4.00, '2026-03-02 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (587, 3, 106, 50.00, '2026-03-03 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (588, 12, 106, 3.00, '2026-03-03 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (589, 14, 106, 1.00, '2026-03-03 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (590, 18, 106, 2.50, '2026-03-03 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (591, 15, 106, 1.00, '2026-03-03 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (592, 17, 106, 5.50, '2026-03-03 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (593, 16, 106, 4.00, '2026-03-03 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (594, 4, 107, 1.50, '2026-03-04 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (595, 13, 107, 1.00, '2026-03-04 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (596, 12, 107, 1.00, '2026-03-04 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (597, 20, 107, 2.00, '2026-03-04 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (598, 15, 107, 1.00, '2026-03-04 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (599, 17, 107, 5.50, '2026-03-04 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (600, 16, 107, 4.00, '2026-03-04 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (601, 4, 108, 1.50, '2026-03-06 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (602, 13, 108, 1.00, '2026-03-06 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (603, 12, 108, 1.00, '2026-03-06 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (604, 20, 108, 2.00, '2026-03-06 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (605, 15, 108, 1.00, '2026-03-06 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (606, 17, 108, 4.50, '2026-03-06 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (607, 16, 108, 4.00, '2026-03-06 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (608, 1, 109, 32.00, '2026-03-09 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (609, 12, 109, 3.00, '2026-03-09 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (610, 14, 109, 1.00, '2026-03-09 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (611, 18, 109, 2.50, '2026-03-09 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (612, 15, 109, 1.00, '2026-03-09 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (613, 17, 109, 5.50, '2026-03-09 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (614, 16, 109, 4.00, '2026-03-09 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (615, 5, 110, 2.00, '2026-03-09 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (616, 12, 110, 4.00, '2026-03-09 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (617, 20, 110, 3.00, '2026-03-09 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (618, 15, 110, 1.00, '2026-03-09 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (619, 16, 110, 3.00, '2026-03-09 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (620, 5, 111, 2.00, '2026-03-09 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (621, 12, 111, 4.00, '2026-03-09 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (622, 20, 111, 3.50, '2026-03-09 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (623, 15, 111, 1.00, '2026-03-09 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (624, 16, 111, 3.00, '2026-03-09 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (625, 4, 112, 1.50, '2026-03-09 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (626, 1, 113, 55.00, '2026-03-09 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (627, 13, 112, 1.00, '2026-03-09 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (628, 12, 113, 3.00, '2026-03-09 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (629, 12, 112, 1.00, '2026-03-09 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (630, 14, 113, 1.00, '2026-03-09 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (631, 20, 112, 1.50, '2026-03-09 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (632, 18, 113, 2.50, '2026-03-09 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (633, 15, 112, 1.00, '2026-03-09 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (634, 15, 113, 1.00, '2026-03-09 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (635, 17, 112, 5.50, '2026-03-09 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (636, 17, 113, 5.50, '2026-03-09 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (637, 16, 112, 4.00, '2026-03-09 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (638, 16, 113, 4.00, '2026-03-09 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (639, 4, 114, 1.50, '2026-03-09 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (640, 13, 114, 1.00, '2026-03-09 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (641, 12, 114, 1.00, '2026-03-09 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (642, 20, 114, 2.00, '2026-03-09 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (643, 15, 114, 1.00, '2026-03-09 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (644, 17, 114, 4.50, '2026-03-09 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (645, 16, 114, 4.00, '2026-03-09 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (646, 3, 115, 60.00, '2026-03-09 17:30:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (647, 12, 115, 3.00, '2026-03-09 17:31:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (648, 14, 115, 1.00, '2026-03-09 17:32:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (649, 18, 115, 2.50, '2026-03-09 17:33:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (650, 15, 115, 1.00, '2026-03-09 17:34:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (651, 17, 115, 4.50, '2026-03-09 17:35:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (652, 16, 115, 4.00, '2026-03-09 17:36:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (653, 5, 116, 2.50, '2026-03-11 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (654, 12, 116, 4.00, '2026-03-11 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (655, 20, 116, 3.00, '2026-03-11 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (656, 15, 116, 1.00, '2026-03-11 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (657, 16, 116, 3.00, '2026-03-11 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (658, 1, 117, 52.00, '2026-03-13 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (659, 12, 117, 3.00, '2026-03-13 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (660, 14, 117, 1.00, '2026-03-13 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (661, 18, 117, 2.50, '2026-03-13 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (662, 15, 117, 1.00, '2026-03-13 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (663, 17, 117, 4.50, '2026-03-13 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (664, 16, 117, 4.00, '2026-03-13 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (665, 5, 117, 2.00, '2026-03-13 16:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (666, 12, 117, 4.00, '2026-03-13 16:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (667, 20, 117, 3.50, '2026-03-13 16:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (668, 15, 117, 1.00, '2026-03-13 16:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (669, 16, 117, 3.00, '2026-03-13 16:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (670, 9, 118, 1.00, '2026-03-16 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (671, 19, 118, 9.00, '2026-03-16 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (672, 13, 118, 1.00, '2026-03-16 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (673, 14, 118, 2.00, '2026-03-16 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (674, 15, 118, 1.00, '2026-03-16 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (675, 17, 118, 5.00, '2026-03-16 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (676, 16, 118, 3.00, '2026-03-16 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (677, 9, 119, 1.00, '2026-03-16 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (678, 19, 119, 8.00, '2026-03-16 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (679, 13, 119, 1.00, '2026-03-16 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (680, 14, 119, 2.00, '2026-03-16 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (681, 15, 119, 1.00, '2026-03-16 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (682, 17, 119, 5.00, '2026-03-16 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (683, 16, 119, 4.00, '2026-03-16 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (684, 1, 120, 22.00, '2026-03-17 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (685, 12, 120, 3.00, '2026-03-17 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (686, 14, 120, 1.00, '2026-03-17 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (687, 18, 120, 2.50, '2026-03-17 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (688, 15, 120, 1.00, '2026-03-17 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (689, 17, 120, 5.50, '2026-03-17 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (690, 16, 120, 4.00, '2026-03-17 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (691, 1, 122, 62.00, '2026-03-20 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (692, 12, 122, 3.00, '2026-03-20 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (693, 14, 122, 1.00, '2026-03-20 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (694, 18, 122, 2.50, '2026-03-20 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (695, 15, 122, 1.00, '2026-03-20 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (696, 17, 122, 4.50, '2026-03-20 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (697, 16, 122, 4.00, '2026-03-20 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (698, 1, 123, 40.00, '2026-03-23 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (699, 12, 123, 3.00, '2026-03-23 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (700, 14, 123, 1.00, '2026-03-23 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (701, 18, 123, 3.00, '2026-03-23 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (702, 15, 123, 1.00, '2026-03-23 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (703, 17, 123, 4.50, '2026-03-23 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (704, 16, 123, 4.00, '2026-03-23 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (705, 11, 124, 1.00, '2026-03-23 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (706, 19, 124, 8.50, '2026-03-23 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (707, 13, 124, 1.00, '2026-03-23 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (708, 14, 124, 2.00, '2026-03-23 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (709, 15, 124, 1.00, '2026-03-23 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (710, 17, 124, 4.50, '2026-03-23 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (711, 16, 124, 4.00, '2026-03-23 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (712, 3, 125, 40.00, '2026-03-23 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (713, 12, 125, 3.00, '2026-03-23 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (714, 14, 125, 1.00, '2026-03-23 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (715, 18, 125, 2.50, '2026-03-23 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (716, 15, 125, 1.00, '2026-03-23 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (717, 17, 125, 5.00, '2026-03-23 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (718, 16, 125, 4.00, '2026-03-23 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (719, 4, 126, 1.50, '2026-03-24 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (720, 13, 126, 1.00, '2026-03-24 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (721, 12, 126, 1.00, '2026-03-24 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (722, 20, 126, 2.00, '2026-03-24 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (723, 15, 126, 1.00, '2026-03-24 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (724, 17, 126, 5.00, '2026-03-24 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (725, 16, 126, 4.00, '2026-03-24 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (726, 4, 127, 1.50, '2026-03-26 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (727, 13, 127, 1.00, '2026-03-26 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (728, 12, 127, 1.00, '2026-03-26 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (729, 20, 127, 2.00, '2026-03-26 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (730, 15, 127, 1.00, '2026-03-26 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (731, 17, 127, 5.00, '2026-03-26 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (732, 16, 127, 3.00, '2026-03-26 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (733, 7, 128, 1.00, '2026-03-30 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (734, 13, 128, 1.00, '2026-03-30 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (735, 20, 128, 1.00, '2026-03-30 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (736, 15, 128, 1.00, '2026-03-30 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (737, 16, 128, 3.00, '2026-03-30 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (738, 1, 129, 32.00, '2026-03-31 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (739, 12, 129, 3.00, '2026-03-31 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (740, 14, 129, 1.00, '2026-03-31 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (741, 18, 129, 2.50, '2026-03-31 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (742, 15, 129, 1.00, '2026-03-31 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (743, 17, 129, 5.50, '2026-03-31 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (744, 16, 129, 3.00, '2026-03-31 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (745, 9, 132, 1.00, '2026-04-03 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (746, 19, 132, 8.50, '2026-04-03 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (747, 13, 132, 1.00, '2026-04-03 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (748, 14, 132, 2.00, '2026-04-03 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (749, 15, 132, 1.00, '2026-04-03 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (750, 17, 132, 5.50, '2026-04-03 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (751, 16, 132, 4.00, '2026-04-03 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (752, 6, 133, 1.00, '2026-04-10 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (753, 12, 133, 2.00, '2026-04-10 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (754, 20, 133, 2.00, '2026-04-10 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (755, 15, 133, 1.00, '2026-04-10 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (756, 16, 133, 3.00, '2026-04-10 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (757, 7, 134, 1.00, '2026-04-13 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (758, 13, 134, 1.00, '2026-04-13 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (759, 20, 134, 1.00, '2026-04-13 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (760, 15, 134, 1.00, '2026-04-13 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (761, 16, 134, 3.00, '2026-04-13 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (762, 4, 135, 1.50, '2026-04-13 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (763, 13, 135, 1.00, '2026-04-13 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (764, 12, 135, 1.00, '2026-04-13 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (765, 20, 135, 2.00, '2026-04-13 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (766, 15, 135, 1.00, '2026-04-13 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (767, 17, 135, 5.00, '2026-04-13 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (768, 16, 135, 4.00, '2026-04-13 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (769, 4, 136, 1.50, '2026-04-14 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (770, 13, 136, 1.00, '2026-04-14 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (771, 12, 136, 1.00, '2026-04-14 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (772, 20, 136, 2.50, '2026-04-14 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (773, 15, 136, 1.00, '2026-04-14 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (774, 17, 136, 5.50, '2026-04-14 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (775, 16, 136, 4.00, '2026-04-14 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (776, 9, 137, 1.00, '2026-04-15 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (777, 19, 137, 9.00, '2026-04-15 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (778, 13, 137, 1.00, '2026-04-15 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (779, 14, 137, 2.00, '2026-04-15 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (780, 15, 137, 1.00, '2026-04-15 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (781, 17, 137, 5.00, '2026-04-15 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (782, 16, 137, 4.00, '2026-04-15 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (783, 6, 139, 1.00, '2026-04-20 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (784, 12, 139, 2.00, '2026-04-20 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (785, 20, 139, 2.50, '2026-04-20 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (786, 15, 139, 1.00, '2026-04-20 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (787, 16, 139, 3.00, '2026-04-20 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (788, 7, 141, 1.00, '2026-04-24 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (789, 13, 141, 1.00, '2026-04-24 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (790, 20, 141, 1.00, '2026-04-24 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (791, 15, 141, 1.00, '2026-04-24 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (792, 16, 141, 3.00, '2026-04-24 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (793, 7, 142, 1.00, '2026-04-27 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (794, 1, 143, 50.00, '2026-04-27 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (795, 13, 142, 1.00, '2026-04-27 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (796, 12, 143, 3.00, '2026-04-27 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (797, 20, 142, 1.00, '2026-04-27 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (798, 14, 143, 1.00, '2026-04-27 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (799, 15, 142, 1.00, '2026-04-27 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (800, 18, 143, 2.50, '2026-04-27 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (801, 16, 142, 3.00, '2026-04-27 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (802, 15, 143, 1.00, '2026-04-27 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (803, 17, 143, 4.50, '2026-04-27 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (804, 16, 143, 4.00, '2026-04-27 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (805, 10, 144, 1.00, '2026-04-27 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (806, 19, 144, 7.50, '2026-04-27 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (807, 13, 144, 1.00, '2026-04-27 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (808, 14, 144, 2.00, '2026-04-27 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (809, 15, 144, 1.00, '2026-04-27 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (810, 17, 144, 5.50, '2026-04-27 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (811, 16, 144, 4.00, '2026-04-27 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (812, 5, 145, 2.00, '2026-04-30 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (813, 7, 146, 1.00, '2026-04-30 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (814, 12, 145, 4.00, '2026-04-30 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (815, 13, 146, 1.00, '2026-04-30 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (816, 20, 145, 3.50, '2026-04-30 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (817, 20, 146, 1.00, '2026-04-30 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (818, 15, 145, 1.00, '2026-04-30 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (819, 15, 146, 1.00, '2026-04-30 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (820, 16, 145, 3.00, '2026-04-30 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (821, 16, 146, 3.00, '2026-04-30 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (822, 7, 147, 1.00, '2026-05-01 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (823, 13, 147, 1.00, '2026-05-01 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (824, 20, 147, 1.00, '2026-05-01 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (825, 15, 147, 1.00, '2026-05-01 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (826, 16, 147, 3.00, '2026-05-01 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (827, 17, NULL, 100.00, '2026-05-04 18:20:00', 'Descarte: material vencido');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (828, 1, 148, 52.00, '2026-05-07 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (829, 12, 148, 3.00, '2026-05-07 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (830, 14, 148, 1.00, '2026-05-07 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (831, 18, 148, 2.50, '2026-05-07 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (832, 15, 148, 1.00, '2026-05-07 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (833, 17, 148, 4.50, '2026-05-07 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (834, 16, 148, 4.00, '2026-05-07 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (835, 9, 149, 1.00, '2026-05-11 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (836, 19, 149, 9.00, '2026-05-11 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (837, 13, 149, 1.00, '2026-05-11 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (838, 14, 149, 2.00, '2026-05-11 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (839, 15, 149, 1.00, '2026-05-11 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (840, 17, 149, 5.50, '2026-05-11 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (841, 16, 149, 4.00, '2026-05-11 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (842, 6, 151, 1.00, '2026-05-11 13:30:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (843, 12, 151, 2.00, '2026-05-11 13:31:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (844, 20, 151, 2.00, '2026-05-11 13:32:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (845, 15, 151, 1.00, '2026-05-11 13:33:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (846, 16, 151, 3.00, '2026-05-11 13:34:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (847, 17, NULL, 100.00, '2026-05-11 18:15:00', 'Descarte: material vencido');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (848, 3, 152, 52.00, '2026-05-12 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (849, 12, 152, 3.00, '2026-05-12 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (850, 14, 152, 1.00, '2026-05-12 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (851, 18, 152, 2.50, '2026-05-12 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (852, 15, 152, 1.00, '2026-05-12 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (853, 17, 152, 5.00, '2026-05-12 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (854, 16, 152, 4.00, '2026-05-12 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (855, 15, NULL, 5.00, '2026-05-12 18:33:00', 'Perda: seringa danificada no transporte');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (856, 4, 153, 1.50, '2026-05-15 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (857, 13, 153, 1.00, '2026-05-15 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (858, 12, 153, 1.00, '2026-05-15 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (859, 20, 153, 2.00, '2026-05-15 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (860, 15, 153, 1.00, '2026-05-15 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (861, 17, 153, 5.00, '2026-05-15 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (862, 16, 153, 4.00, '2026-05-15 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (863, 7, 154, 1.00, '2026-05-18 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (864, 13, 154, 1.00, '2026-05-18 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (865, 20, 154, 1.00, '2026-05-18 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (866, 15, 154, 1.00, '2026-05-18 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (867, 16, 154, 3.00, '2026-05-18 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (868, 4, 154, 1.50, '2026-05-18 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (869, 13, 154, 1.00, '2026-05-18 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (870, 12, 154, 1.00, '2026-05-18 09:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (871, 20, 154, 2.00, '2026-05-18 09:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (872, 15, 154, 1.00, '2026-05-18 09:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (873, 17, 154, 4.50, '2026-05-18 09:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (874, 16, 154, 4.00, '2026-05-18 09:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (875, 7, 155, 1.00, '2026-05-19 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (876, 13, 155, 1.00, '2026-05-19 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (877, 20, 155, 1.00, '2026-05-19 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (878, 15, 155, 1.00, '2026-05-19 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (879, 16, 155, 3.00, '2026-05-19 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (880, 6, 156, 1.00, '2026-05-19 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (881, 12, 156, 2.00, '2026-05-19 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (882, 20, 156, 2.00, '2026-05-19 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (883, 15, 156, 1.00, '2026-05-19 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (884, 16, 156, 3.00, '2026-05-19 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (885, 1, 157, 50.00, '2026-05-20 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (886, 12, 157, 3.00, '2026-05-20 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (887, 14, 157, 1.00, '2026-05-20 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (888, 18, 157, 2.50, '2026-05-20 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (889, 15, 157, 1.00, '2026-05-20 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (890, 17, 157, 5.00, '2026-05-20 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (891, 16, 157, 4.00, '2026-05-20 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (892, 6, 157, 1.00, '2026-05-20 11:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (893, 12, 157, 2.00, '2026-05-20 11:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (894, 20, 157, 2.00, '2026-05-20 11:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (895, 15, 157, 1.00, '2026-05-20 11:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (896, 16, 157, 3.00, '2026-05-20 11:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (897, 2, 158, 50.00, '2026-05-21 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (898, 12, 158, 3.00, '2026-05-21 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (899, 14, 158, 1.00, '2026-05-21 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (900, 18, 158, 2.00, '2026-05-21 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (901, 15, 158, 1.00, '2026-05-21 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (902, 17, 158, 5.50, '2026-05-21 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (903, 16, 158, 4.00, '2026-05-21 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (904, 9, 159, 1.00, '2026-05-25 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (905, 19, 159, 7.50, '2026-05-25 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (906, 13, 159, 1.00, '2026-05-25 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (907, 14, 159, 2.00, '2026-05-25 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (908, 15, 159, 1.00, '2026-05-25 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (909, 17, 159, 5.50, '2026-05-25 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (910, 16, 159, 4.00, '2026-05-25 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (911, 9, 161, 1.00, '2026-05-25 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (912, 19, 161, 8.50, '2026-05-25 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (913, 13, 161, 1.00, '2026-05-25 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (914, 14, 161, 2.00, '2026-05-25 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (915, 15, 161, 1.00, '2026-05-25 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (916, 17, 161, 5.50, '2026-05-25 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (917, 16, 161, 4.00, '2026-05-25 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (918, 4, 162, 1.50, '2026-05-25 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (919, 13, 162, 1.00, '2026-05-25 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (920, 12, 162, 1.00, '2026-05-25 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (921, 20, 162, 2.00, '2026-05-25 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (922, 15, 162, 1.00, '2026-05-25 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (923, 17, 162, 4.50, '2026-05-25 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (924, 16, 162, 4.00, '2026-05-25 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (925, 9, 164, 1.00, '2026-05-26 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (926, 19, 164, 8.50, '2026-05-26 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (927, 13, 164, 1.00, '2026-05-26 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (928, 14, 164, 2.00, '2026-05-26 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (929, 15, 164, 1.00, '2026-05-26 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (930, 17, 164, 4.50, '2026-05-26 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (931, 16, 164, 4.00, '2026-05-26 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (932, 4, 165, 1.50, '2026-06-02 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (933, 13, 165, 1.00, '2026-06-02 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (934, 12, 165, 1.00, '2026-06-02 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (935, 20, 165, 2.50, '2026-06-02 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (936, 15, 165, 1.00, '2026-06-02 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (937, 17, 165, 5.50, '2026-06-02 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (938, 16, 165, 3.00, '2026-06-02 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (939, 1, 166, 22.00, '2026-06-04 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (940, 12, 166, 3.00, '2026-06-04 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (941, 14, 166, 1.00, '2026-06-04 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (942, 18, 166, 3.00, '2026-06-04 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (943, 15, 166, 1.00, '2026-06-04 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (944, 17, 166, 5.50, '2026-06-04 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (945, 16, 166, 4.00, '2026-06-04 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (946, 6, 166, 1.00, '2026-06-04 14:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (947, 12, 166, 2.00, '2026-06-04 14:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (948, 20, 166, 2.00, '2026-06-04 14:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (949, 15, 166, 1.00, '2026-06-04 14:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (950, 16, 166, 3.00, '2026-06-04 14:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (951, 1, 167, 60.00, '2026-06-04 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (952, 12, 167, 3.00, '2026-06-04 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (953, 14, 167, 1.00, '2026-06-04 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (954, 18, 167, 3.00, '2026-06-04 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (955, 15, 167, 1.00, '2026-06-04 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (956, 17, 167, 4.50, '2026-06-04 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (957, 16, 167, 4.00, '2026-06-04 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (958, 5, 168, 2.00, '2026-06-05 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (959, 12, 168, 4.00, '2026-06-05 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (960, 20, 168, 3.00, '2026-06-05 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (961, 15, 168, 1.00, '2026-06-05 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (962, 16, 168, 3.00, '2026-06-05 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (963, 3, 169, 32.00, '2026-06-08 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (964, 12, 169, 3.00, '2026-06-08 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (965, 14, 169, 1.00, '2026-06-08 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (966, 18, 169, 2.50, '2026-06-08 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (967, 15, 169, 1.00, '2026-06-08 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (968, 17, 169, 5.00, '2026-06-08 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (969, 16, 169, 4.00, '2026-06-08 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (970, 9, 171, 1.00, '2026-06-08 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (971, 19, 171, 7.00, '2026-06-08 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (972, 13, 171, 1.00, '2026-06-08 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (973, 14, 171, 2.00, '2026-06-08 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (974, 15, 171, 1.00, '2026-06-08 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (975, 17, 171, 4.50, '2026-06-08 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (976, 16, 171, 5.00, '2026-06-08 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (977, 6, 172, 1.00, '2026-06-10 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (978, 12, 172, 2.00, '2026-06-10 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (979, 20, 172, 1.50, '2026-06-10 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (980, 15, 172, 1.00, '2026-06-10 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (981, 16, 172, 3.00, '2026-06-10 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (982, 10, 173, 1.00, '2026-06-12 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (983, 9, 174, 1.00, '2026-06-12 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (984, 19, 173, 7.00, '2026-06-12 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (985, 19, 174, 7.00, '2026-06-12 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (986, 13, 173, 1.00, '2026-06-12 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (987, 13, 174, 1.00, '2026-06-12 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (988, 14, 173, 2.00, '2026-06-12 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (989, 14, 174, 2.00, '2026-06-12 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (990, 15, 173, 1.00, '2026-06-12 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (991, 15, 174, 1.00, '2026-06-12 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (992, 17, 173, 5.00, '2026-06-12 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (993, 17, 174, 5.50, '2026-06-12 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (994, 16, 173, 4.00, '2026-06-12 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (995, 16, 174, 5.00, '2026-06-12 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (996, 4, 175, 1.50, '2026-06-16 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (997, 13, 175, 1.00, '2026-06-16 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (998, 12, 175, 1.00, '2026-06-16 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (999, 20, 175, 2.00, '2026-06-16 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1000, 15, 175, 1.00, '2026-06-16 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1001, 17, 175, 5.00, '2026-06-16 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1002, 16, 175, 4.00, '2026-06-16 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1003, 5, 176, 2.00, '2026-06-22 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1004, 12, 176, 4.00, '2026-06-22 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1005, 20, 176, 3.00, '2026-06-22 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1006, 15, 176, 1.00, '2026-06-22 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1007, 16, 176, 3.00, '2026-06-22 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1008, 6, 177, 1.00, '2026-06-22 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1009, 12, 177, 2.00, '2026-06-22 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1010, 20, 177, 2.00, '2026-06-22 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1011, 15, 177, 1.00, '2026-06-22 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1012, 16, 177, 3.00, '2026-06-22 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1013, 1, 178, 35.00, '2026-06-22 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1014, 12, 178, 3.00, '2026-06-22 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1015, 14, 178, 1.00, '2026-06-22 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1016, 18, 178, 2.50, '2026-06-22 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1017, 15, 178, 1.00, '2026-06-22 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1018, 17, 178, 5.00, '2026-06-22 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1019, 16, 178, 4.00, '2026-06-22 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1020, 5, 179, 2.00, '2026-06-23 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1021, 12, 179, 4.00, '2026-06-23 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1022, 20, 179, 3.00, '2026-06-23 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1023, 15, 179, 1.00, '2026-06-23 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1024, 16, 179, 3.00, '2026-06-23 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1025, 1, 181, 52.00, '2026-06-30 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1026, 12, 181, 3.00, '2026-06-30 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1027, 14, 181, 1.00, '2026-06-30 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1028, 18, 181, 2.50, '2026-06-30 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1029, 15, 181, 1.00, '2026-06-30 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1030, 17, 181, 5.00, '2026-06-30 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1031, 16, 181, 4.00, '2026-06-30 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1032, 1, 182, 32.00, '2026-07-01 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1033, 12, 182, 3.00, '2026-07-01 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1034, 14, 182, 1.00, '2026-07-01 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1035, 18, 182, 2.50, '2026-07-01 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1036, 15, 182, 1.00, '2026-07-01 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1037, 17, 182, 4.50, '2026-07-01 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1038, 16, 182, 5.00, '2026-07-01 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1039, 6, 183, 1.00, '2026-07-02 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1040, 12, 183, 2.00, '2026-07-02 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1041, 20, 183, 2.00, '2026-07-02 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1042, 15, 183, 1.00, '2026-07-02 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1043, 16, 183, 3.00, '2026-07-02 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1044, 4, 184, 1.50, '2026-07-06 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1045, 13, 184, 1.00, '2026-07-06 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1046, 12, 184, 1.00, '2026-07-06 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1047, 20, 184, 2.00, '2026-07-06 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1048, 15, 184, 1.00, '2026-07-06 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1049, 17, 184, 5.00, '2026-07-06 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1050, 16, 184, 4.00, '2026-07-06 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1051, 3, 185, 65.00, '2026-07-09 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1052, 12, 185, 3.00, '2026-07-09 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1053, 14, 185, 1.00, '2026-07-09 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1054, 18, 185, 2.50, '2026-07-09 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1055, 15, 185, 1.00, '2026-07-09 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1056, 17, 185, 5.50, '2026-07-09 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1057, 16, 185, 3.00, '2026-07-09 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1058, 4, 186, 1.50, '2026-07-09 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1059, 13, 186, 1.00, '2026-07-09 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1060, 12, 186, 1.00, '2026-07-09 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1061, 20, 186, 2.00, '2026-07-09 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1062, 15, 186, 1.00, '2026-07-09 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1063, 17, 186, 4.50, '2026-07-09 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1064, 16, 186, 4.00, '2026-07-09 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1065, 5, 187, 2.00, '2026-07-13 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1066, 12, 187, 5.00, '2026-07-13 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1067, 20, 187, 3.00, '2026-07-13 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1068, 15, 187, 1.00, '2026-07-13 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1069, 16, 187, 3.00, '2026-07-13 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1070, 7, 188, 1.00, '2026-07-13 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1071, 13, 188, 1.00, '2026-07-13 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1072, 20, 188, 1.00, '2026-07-13 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1073, 15, 188, 1.00, '2026-07-13 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1074, 16, 188, 3.00, '2026-07-13 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1075, 6, 189, 1.00, '2026-07-14 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1076, 12, 189, 2.00, '2026-07-14 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1077, 20, 189, 2.00, '2026-07-14 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1078, 15, 189, 1.00, '2026-07-14 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1079, 16, 189, 3.00, '2026-07-14 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1080, 7, 192, 1.00, '2026-07-16 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1081, 13, 192, 1.00, '2026-07-16 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1082, 20, 192, 1.00, '2026-07-16 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1083, 15, 192, 1.00, '2026-07-16 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1084, 16, 192, 3.00, '2026-07-16 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1085, 4, 194, 1.50, '2026-07-20 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1086, 13, 194, 1.00, '2026-07-20 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1087, 12, 194, 1.00, '2026-07-20 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1088, 20, 194, 2.00, '2026-07-20 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1089, 15, 194, 1.00, '2026-07-20 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1090, 17, 194, 5.50, '2026-07-20 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1091, 16, 194, 4.00, '2026-07-20 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1092, 1, 195, 20.00, '2026-07-20 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1093, 12, 195, 3.00, '2026-07-20 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1094, 14, 195, 1.00, '2026-07-20 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1095, 18, 195, 3.00, '2026-07-20 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1096, 15, 195, 1.00, '2026-07-20 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1097, 17, 195, 5.50, '2026-07-20 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1098, 16, 195, 3.00, '2026-07-20 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1099, 4, 196, 1.50, '2026-07-21 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1100, 13, 196, 1.00, '2026-07-21 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1101, 12, 196, 1.00, '2026-07-21 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1102, 20, 196, 2.00, '2026-07-21 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1103, 15, 196, 1.00, '2026-07-21 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1104, 17, 196, 5.50, '2026-07-21 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1105, 16, 196, 5.00, '2026-07-21 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1106, 5, 196, 2.50, '2026-07-21 10:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1107, 12, 196, 4.00, '2026-07-21 10:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1108, 20, 196, 2.50, '2026-07-21 10:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1109, 15, 196, 1.00, '2026-07-21 10:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1110, 16, 196, 3.00, '2026-07-21 10:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1111, 6, 197, 1.00, '2026-07-24 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1112, 12, 197, 2.00, '2026-07-24 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1113, 20, 197, 2.00, '2026-07-24 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1114, 15, 197, 1.00, '2026-07-24 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1115, 16, 197, 3.00, '2026-07-24 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1116, 1, 198, 35.00, '2026-07-27 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1117, 12, 198, 3.00, '2026-07-27 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1118, 14, 198, 1.00, '2026-07-27 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1119, 18, 198, 2.50, '2026-07-27 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1120, 15, 198, 1.00, '2026-07-27 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1121, 17, 198, 5.50, '2026-07-27 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1122, 16, 198, 3.00, '2026-07-27 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1123, 6, 198, 1.00, '2026-07-27 14:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1124, 12, 198, 2.00, '2026-07-27 14:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1125, 20, 198, 2.00, '2026-07-27 14:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1126, 15, 198, 1.00, '2026-07-27 14:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1127, 16, 198, 3.00, '2026-07-27 14:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1128, 1, 199, 45.00, '2026-07-28 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1129, 12, 199, 3.00, '2026-07-28 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1130, 14, 199, 1.00, '2026-07-28 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1131, 18, 199, 2.50, '2026-07-28 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1132, 15, 199, 1.00, '2026-07-28 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1133, 17, 199, 4.50, '2026-07-28 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1134, 16, 199, 5.00, '2026-07-28 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1135, 1, 200, 50.00, '2026-07-29 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1136, 12, 200, 3.00, '2026-07-29 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1137, 14, 200, 1.00, '2026-07-29 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1138, 18, 200, 2.50, '2026-07-29 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1139, 15, 200, 1.00, '2026-07-29 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1140, 17, 200, 4.50, '2026-07-29 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1141, 16, 200, 4.00, '2026-07-29 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1142, 5, 202, 2.00, '2026-07-30 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1143, 12, 202, 4.00, '2026-07-30 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1144, 20, 202, 3.00, '2026-07-30 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1145, 15, 202, 1.00, '2026-07-30 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1146, 16, 202, 3.00, '2026-07-30 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1147, 6, 203, 1.00, '2026-07-30 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1148, 12, 203, 2.00, '2026-07-30 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1149, 20, 203, 2.50, '2026-07-30 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1150, 15, 203, 1.00, '2026-07-30 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1151, 16, 203, 3.00, '2026-07-30 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1152, 5, 205, 2.00, '2026-07-30 17:30:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1153, 12, 205, 4.00, '2026-07-30 17:31:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1154, 20, 205, 3.00, '2026-07-30 17:32:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1155, 15, 205, 1.00, '2026-07-30 17:33:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1156, 16, 205, 3.00, '2026-07-30 17:34:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1157, 1, 206, 40.00, '2026-08-03 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1158, 12, 206, 3.00, '2026-08-03 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1159, 14, 206, 1.00, '2026-08-03 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1160, 18, 206, 2.50, '2026-08-03 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1161, 15, 206, 1.00, '2026-08-03 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1162, 17, 206, 4.50, '2026-08-03 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1163, 16, 206, 4.00, '2026-08-03 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1164, 1, 207, 62.00, '2026-08-03 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1165, 12, 207, 3.00, '2026-08-03 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1166, 14, 207, 1.00, '2026-08-03 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1167, 18, 207, 2.50, '2026-08-03 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1168, 15, 207, 1.00, '2026-08-03 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1169, 17, 207, 5.50, '2026-08-03 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1170, 16, 207, 4.00, '2026-08-03 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1171, 6, 207, 1.00, '2026-08-03 15:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1172, 12, 207, 2.00, '2026-08-03 15:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1173, 20, 207, 2.00, '2026-08-03 15:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1174, 15, 207, 1.00, '2026-08-03 15:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1175, 16, 207, 3.00, '2026-08-03 15:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1176, 1, 208, 45.00, '2026-08-03 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1177, 12, 208, 3.00, '2026-08-03 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1178, 14, 208, 1.00, '2026-08-03 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1179, 18, 208, 2.50, '2026-08-03 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1180, 15, 208, 1.00, '2026-08-03 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1181, 17, 208, 5.00, '2026-08-03 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1182, 16, 208, 4.00, '2026-08-03 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1183, 1, 209, 65.00, '2026-08-10 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1184, 12, 209, 3.00, '2026-08-10 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1185, 14, 209, 1.00, '2026-08-10 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1186, 18, 209, 3.00, '2026-08-10 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1187, 15, 209, 1.00, '2026-08-10 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1188, 17, 209, 4.50, '2026-08-10 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1189, 16, 209, 4.00, '2026-08-10 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1190, 6, 211, 1.00, '2026-08-12 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1191, 12, 211, 2.00, '2026-08-12 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1192, 20, 211, 2.50, '2026-08-12 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1193, 15, 211, 1.00, '2026-08-12 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1194, 16, 211, 3.00, '2026-08-12 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1195, 5, 211, 2.00, '2026-08-12 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1196, 12, 211, 4.00, '2026-08-12 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1197, 20, 211, 3.00, '2026-08-12 14:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1198, 15, 211, 1.00, '2026-08-12 14:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1199, 16, 211, 3.00, '2026-08-12 14:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1200, 1, 212, 32.00, '2026-08-12 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1201, 12, 212, 3.00, '2026-08-12 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1202, 14, 212, 1.00, '2026-08-12 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1203, 18, 212, 3.00, '2026-08-12 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1204, 15, 212, 1.00, '2026-08-12 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1205, 17, 212, 4.50, '2026-08-12 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1206, 16, 212, 4.00, '2026-08-12 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1207, 6, 212, 1.00, '2026-08-12 16:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1208, 12, 212, 2.00, '2026-08-12 16:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1209, 20, 212, 2.00, '2026-08-12 16:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1210, 15, 212, 1.00, '2026-08-12 16:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1211, 16, 212, 3.00, '2026-08-12 16:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1212, 1, 213, 42.00, '2026-08-14 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1213, 12, 213, 3.00, '2026-08-14 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1214, 14, 213, 1.00, '2026-08-14 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1215, 18, 213, 2.00, '2026-08-14 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1216, 15, 213, 1.00, '2026-08-14 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1217, 17, 213, 4.50, '2026-08-14 09:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1218, 16, 213, 4.00, '2026-08-14 09:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1219, 7, 214, 1.00, '2026-08-17 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1220, 13, 214, 1.00, '2026-08-17 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1221, 20, 214, 1.00, '2026-08-17 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1222, 15, 214, 1.00, '2026-08-17 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1223, 16, 214, 3.00, '2026-08-17 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1224, 5, 215, 2.00, '2026-08-17 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1225, 12, 215, 3.00, '2026-08-17 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1226, 20, 215, 2.50, '2026-08-17 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1227, 15, 215, 1.00, '2026-08-17 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1228, 16, 215, 3.00, '2026-08-17 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1229, 1, 216, 25.00, '2026-08-17 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1230, 12, 216, 3.00, '2026-08-17 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1231, 14, 216, 1.00, '2026-08-17 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1232, 18, 216, 3.00, '2026-08-17 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1233, 15, 216, 1.00, '2026-08-17 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1234, 17, 216, 5.50, '2026-08-17 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1235, 16, 216, 4.00, '2026-08-17 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1236, 1, 218, 22.00, '2026-08-18 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1237, 5, 219, 2.00, '2026-08-18 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1238, 12, 218, 3.00, '2026-08-18 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1239, 12, 219, 4.00, '2026-08-18 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1240, 14, 218, 1.00, '2026-08-18 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1241, 20, 219, 3.50, '2026-08-18 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1242, 18, 218, 2.00, '2026-08-18 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1243, 15, 219, 1.00, '2026-08-18 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1244, 15, 218, 1.00, '2026-08-18 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1245, 16, 219, 3.00, '2026-08-18 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1246, 17, 218, 4.50, '2026-08-18 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1247, 16, 218, 4.00, '2026-08-18 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1248, 2, 220, 25.00, '2026-08-18 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1249, 12, 220, 3.00, '2026-08-18 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1250, 14, 220, 1.00, '2026-08-18 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1251, 18, 220, 2.50, '2026-08-18 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1252, 15, 220, 1.00, '2026-08-18 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1253, 17, 220, 4.50, '2026-08-18 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1254, 16, 220, 4.00, '2026-08-18 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1255, 1, 221, 60.00, '2026-08-19 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1256, 12, 221, 3.00, '2026-08-19 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1257, 14, 221, 1.00, '2026-08-19 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1258, 18, 221, 2.00, '2026-08-19 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1259, 15, 221, 1.00, '2026-08-19 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1260, 17, 221, 5.50, '2026-08-19 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1261, 16, 221, 4.00, '2026-08-19 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1262, 6, 222, 1.00, '2026-08-20 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1263, 12, 222, 2.00, '2026-08-20 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1264, 20, 222, 1.50, '2026-08-20 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1265, 15, 222, 1.00, '2026-08-20 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1266, 16, 222, 3.00, '2026-08-20 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1267, 1, 223, 55.00, '2026-08-21 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1268, 12, 223, 3.00, '2026-08-21 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1269, 14, 223, 1.00, '2026-08-21 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1270, 18, 223, 2.50, '2026-08-21 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1271, 15, 223, 1.00, '2026-08-21 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1272, 17, 223, 5.00, '2026-08-21 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1273, 16, 223, 4.00, '2026-08-21 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1274, 5, 223, 2.00, '2026-08-21 10:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1275, 12, 223, 4.00, '2026-08-21 10:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1276, 20, 223, 3.00, '2026-08-21 10:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1277, 15, 223, 1.00, '2026-08-21 10:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1278, 16, 223, 3.00, '2026-08-21 10:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1279, 1, 224, 62.00, '2026-08-24 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1280, 12, 224, 3.00, '2026-08-24 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1281, 14, 224, 1.00, '2026-08-24 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1282, 18, 224, 2.50, '2026-08-24 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1283, 15, 224, 1.00, '2026-08-24 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1284, 17, 224, 5.00, '2026-08-24 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1285, 16, 224, 3.00, '2026-08-24 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1286, 7, 226, 1.00, '2026-08-27 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1287, 13, 226, 1.00, '2026-08-27 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1288, 20, 226, 1.00, '2026-08-27 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1289, 15, 226, 1.00, '2026-08-27 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1290, 16, 226, 3.00, '2026-08-27 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1291, 1, 227, 40.00, '2026-08-28 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1292, 12, 227, 3.00, '2026-08-28 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1293, 14, 227, 1.00, '2026-08-28 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1294, 18, 227, 2.50, '2026-08-28 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1295, 15, 227, 1.00, '2026-08-28 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1296, 17, 227, 4.50, '2026-08-28 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1297, 16, 227, 4.00, '2026-08-28 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1298, 3, 228, 22.00, '2026-08-31 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1299, 12, 228, 3.00, '2026-08-31 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1300, 14, 228, 1.00, '2026-08-31 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1301, 18, 228, 2.50, '2026-08-31 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1302, 15, 228, 1.00, '2026-08-31 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1303, 17, 228, 5.50, '2026-08-31 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1304, 16, 228, 3.00, '2026-08-31 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1305, 5, 229, 2.00, '2026-08-31 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1306, 12, 229, 4.00, '2026-08-31 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1307, 20, 229, 3.50, '2026-08-31 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1308, 15, 229, 1.00, '2026-08-31 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1309, 16, 229, 3.00, '2026-08-31 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1310, 9, 231, 1.00, '2026-09-07 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1311, 19, 231, 9.00, '2026-09-07 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1312, 13, 231, 1.00, '2026-09-07 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1313, 14, 231, 2.00, '2026-09-07 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1314, 15, 231, 1.00, '2026-09-07 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1315, 17, 231, 5.00, '2026-09-07 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1316, 16, 231, 4.00, '2026-09-07 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1317, 1, 232, 40.00, '2026-09-07 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1318, 12, 232, 3.00, '2026-09-07 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1319, 14, 232, 1.00, '2026-09-07 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1320, 18, 232, 3.00, '2026-09-07 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1321, 15, 232, 1.00, '2026-09-07 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1322, 17, 232, 4.50, '2026-09-07 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1323, 16, 232, 4.00, '2026-09-07 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1324, 4, 233, 1.50, '2026-09-07 16:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1325, 13, 233, 1.00, '2026-09-07 16:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1326, 12, 233, 1.00, '2026-09-07 16:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1327, 20, 233, 2.00, '2026-09-07 16:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1328, 15, 233, 1.00, '2026-09-07 16:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1329, 17, 233, 5.50, '2026-09-07 16:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1330, 16, 233, 4.00, '2026-09-07 16:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1331, 5, 233, 2.00, '2026-09-07 16:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1332, 12, 233, 4.00, '2026-09-07 16:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1333, 20, 233, 3.50, '2026-09-07 16:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1334, 15, 233, 1.00, '2026-09-07 16:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1335, 16, 233, 3.00, '2026-09-07 16:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1336, 12, NULL, 10.00, '2026-09-07 18:50:00', 'Descarte: embalagem violada');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1337, 7, 234, 1.00, '2026-09-08 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1338, 13, 234, 1.00, '2026-09-08 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1339, 20, 234, 1.00, '2026-09-08 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1340, 15, 234, 1.00, '2026-09-08 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1341, 16, 234, 3.00, '2026-09-08 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1342, 4, 235, 1.50, '2026-09-09 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1343, 13, 235, 1.00, '2026-09-09 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1344, 12, 235, 1.00, '2026-09-09 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1345, 20, 235, 2.00, '2026-09-09 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1346, 15, 235, 1.00, '2026-09-09 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1347, 17, 235, 4.50, '2026-09-09 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1348, 16, 235, 4.00, '2026-09-09 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1349, 16, NULL, 10.00, '2026-09-14 18:17:00', 'Perda: seringa danificada no transporte');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1350, 1, 237, 30.00, '2026-09-15 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1351, 12, 237, 3.00, '2026-09-15 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1352, 14, 237, 1.00, '2026-09-15 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1353, 18, 237, 3.00, '2026-09-15 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1354, 15, 237, 1.00, '2026-09-15 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1355, 17, 237, 5.00, '2026-09-15 17:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1356, 16, 237, 4.00, '2026-09-15 17:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1357, 22, NULL, 5.00, '2026-09-16 18:04:00', 'Uso em demonstração interna');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1358, 9, 238, 1.00, '2026-09-18 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1359, 5, 239, 1.50, '2026-09-18 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1360, 19, 238, 8.50, '2026-09-18 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1361, 12, 239, 4.00, '2026-09-18 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1362, 13, 238, 1.00, '2026-09-18 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1363, 20, 239, 3.00, '2026-09-18 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1364, 14, 238, 2.00, '2026-09-18 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1365, 15, 239, 1.00, '2026-09-18 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1366, 15, 238, 1.00, '2026-09-18 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1367, 16, 239, 3.00, '2026-09-18 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1368, 17, 238, 5.00, '2026-09-18 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1369, 16, 238, 4.00, '2026-09-18 13:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1370, 9, 240, 1.00, '2026-09-18 14:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1371, 19, 240, 8.00, '2026-09-18 14:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1372, 13, 240, 1.00, '2026-09-18 14:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1373, 14, 240, 2.00, '2026-09-18 14:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1374, 15, 240, 1.00, '2026-09-18 14:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1375, 17, 240, 5.00, '2026-09-18 14:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1376, 16, 240, 4.00, '2026-09-18 14:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1377, 2, 240, 20.00, '2026-09-18 14:07:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1378, 12, 240, 3.00, '2026-09-18 14:08:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1379, 14, 240, 1.00, '2026-09-18 14:09:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1380, 18, 240, 3.00, '2026-09-18 14:10:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1381, 15, 240, 1.00, '2026-09-18 14:11:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1382, 17, 240, 5.50, '2026-09-18 14:12:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1383, 16, 240, 5.00, '2026-09-18 14:13:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1384, 5, 241, 2.00, '2026-09-21 09:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1385, 12, 241, 4.00, '2026-09-21 09:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1386, 20, 241, 2.50, '2026-09-21 09:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1387, 15, 241, 1.00, '2026-09-21 09:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1388, 16, 241, 3.00, '2026-09-21 09:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1389, 1, 242, 50.00, '2026-09-21 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1390, 12, 242, 3.00, '2026-09-21 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1391, 14, 242, 1.00, '2026-09-21 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1392, 18, 242, 3.00, '2026-09-21 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1393, 15, 242, 1.00, '2026-09-21 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1394, 17, 242, 4.50, '2026-09-21 10:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1395, 16, 242, 4.00, '2026-09-21 10:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1396, 6, 243, 1.00, '2026-09-21 17:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1397, 12, 243, 2.00, '2026-09-21 17:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1398, 20, 243, 2.00, '2026-09-21 17:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1399, 15, 243, 1.00, '2026-09-21 17:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1400, 16, 243, 3.00, '2026-09-21 17:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1401, 14, NULL, 10.00, '2026-10-01 18:58:00', 'Perda: seringa danificada no transporte');
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1402, 3, 244, 62.00, '2026-10-05 11:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1403, 12, 244, 3.00, '2026-10-05 11:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1404, 14, 244, 1.00, '2026-10-05 11:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1405, 18, 244, 2.50, '2026-10-05 11:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1406, 15, 244, 1.00, '2026-10-05 11:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1407, 17, 244, 4.50, '2026-10-05 11:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1408, 16, 244, 3.00, '2026-10-05 11:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1409, 7, 246, 1.00, '2026-10-12 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1410, 7, 247, 1.00, '2026-10-12 10:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1411, 13, 246, 1.00, '2026-10-12 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1412, 13, 247, 1.00, '2026-10-12 10:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1413, 20, 246, 1.00, '2026-10-12 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1414, 20, 247, 1.00, '2026-10-12 10:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1415, 15, 246, 1.00, '2026-10-12 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1416, 15, 247, 1.00, '2026-10-12 10:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1417, 16, 246, 3.00, '2026-10-12 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1418, 16, 247, 3.00, '2026-10-12 10:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1419, 3, 249, 62.00, '2026-10-14 15:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1420, 12, 249, 3.00, '2026-10-14 15:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1421, 14, 249, 1.00, '2026-10-14 15:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1422, 18, 249, 2.50, '2026-10-14 15:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1423, 15, 249, 1.00, '2026-10-14 15:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1424, 17, 249, 5.50, '2026-10-14 15:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1425, 16, 249, 4.00, '2026-10-14 15:06:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1426, 3, 250, 52.00, '2026-10-15 13:00:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1427, 12, 250, 3.00, '2026-10-15 13:01:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1428, 14, 250, 1.00, '2026-10-15 13:02:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1429, 18, 250, 2.00, '2026-10-15 13:03:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1430, 15, 250, 1.00, '2026-10-15 13:04:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1431, 17, 250, 5.00, '2026-10-15 13:05:00', NULL);
INSERT INTO consumo (id_consumo, id_insumo, id_atendimento, quantidade, data_consumo, observacao) VALUES (1432, 16, 250, 4.00, '2026-10-15 13:06:00', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (1, 98, 1, '2025-10-02 10:50:00', 'Contorno mandibular pouco definido', 'Rinite alérgica.', 'Penicilina', 'Losartana', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (2, 46, 1, '2025-10-02 10:50:00', 'Lábios finos e assimétricos', 'Hipotireoidismo controlado.', 'Nenhuma conhecida', 'Nenhum', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (3, 120, 1, '2025-10-03 14:50:00', 'Perda de volume no rosto', 'Rinite alérgica.', 'Dipirona', 'Nenhum', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (4, 105, 1, '2025-10-06 15:50:00', 'Contorno mandibular pouco definido', 'Hipotireoidismo controlado.', 'Dipirona', 'Nenhum', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (5, 67, 1, '2025-10-08 09:50:00', 'Contorno mandibular pouco definido', 'Nenhum procedimento estético anterior.', 'Dipirona', 'Nenhum', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (6, 114, 1, '2025-10-13 12:50:00', 'Rugas ao redor dos olhos', 'Hipotireoidismo controlado.', 'Nenhuma conhecida', 'Anticoncepcional oral', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (7, 16, 1, '2025-10-14 14:50:00', 'Flacidez facial', 'Hipertensão controlada com medicação.', 'Látex', 'Nenhum', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (8, 123, 1, '2025-10-15 09:50:00', 'Linhas de expressão na testa', 'Sem doenças crônicas relatadas.', 'Látex', 'Losartana', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (9, 106, 1, '2025-10-16 10:50:00', 'Lábios finos e assimétricos', 'Nenhum procedimento estético anterior.', 'Penicilina', 'Anticoncepcional oral', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (10, 52, 1, '2025-10-17 13:50:00', 'Olheiras profundas', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Levotiroxina', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (11, 34, 1, '2025-10-20 13:50:00', 'Lábios finos e assimétricos', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Anticoncepcional oral', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (12, 113, 1, '2025-10-22 09:50:00', 'Flacidez facial', 'Sem doenças crônicas relatadas.', 'Nenhuma conhecida', 'Anticoncepcional oral', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (13, 48, 1, '2025-10-27 09:50:00', 'Lábios finos e assimétricos', 'Hipotireoidismo controlado.', 'Nenhuma conhecida', 'Anticoncepcional oral', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (14, 53, 1, '2025-10-27 15:50:00', 'Olheiras profundas', 'Nenhum procedimento estético anterior.', 'Látex', 'Levotiroxina', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (15, 83, 1, '2025-10-27 16:50:00', 'Contorno mandibular pouco definido', 'Já realizou toxina botulínica há mais de um ano.', 'Nenhuma conhecida', 'Nenhum', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (16, 117, 1, '2025-10-29 16:50:00', 'Rugas ao redor dos olhos', 'Sem doenças crônicas relatadas.', 'Nenhuma conhecida', 'Nenhum', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (17, 21, 1, '2025-11-06 10:50:00', 'Flacidez facial', 'Hipertensão controlada com medicação.', 'Nenhuma conhecida', 'Anticoncepcional oral', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (18, 102, 1, '2025-11-10 12:50:00', 'Linhas de expressão na testa', 'Já realizou toxina botulínica há mais de um ano.', 'Penicilina', 'Vitamina D', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (19, 110, 1, '2025-11-11 10:50:00', 'Pele desidratada e sem viço', 'Já realizou toxina botulínica há mais de um ano.', 'Dipirona', 'Anticoncepcional oral', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (20, 122, 1, '2025-11-13 09:50:00', 'Rugas ao redor dos olhos', 'Hipertensão controlada com medicação.', 'Nenhuma conhecida', 'Losartana', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (21, 72, 1, '2025-11-13 13:50:00', 'Perda de volume no rosto', 'Sem doenças crônicas relatadas.', 'Nenhuma conhecida', 'Levotiroxina', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (22, 26, 1, '2025-11-13 14:20:00', 'Flacidez facial', 'Rinite alérgica.', 'Nenhuma conhecida', 'Losartana', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (23, 7, 1, '2025-11-17 10:50:00', 'Flacidez facial', 'Rinite alérgica.', 'Látex', 'Losartana', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (24, 108, 1, '2025-11-17 10:50:00', 'Contorno mandibular pouco definido', 'Sem doenças crônicas relatadas.', 'Penicilina', 'Nenhum', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (25, 23, 1, '2025-11-17 12:50:00', 'Flacidez facial', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Losartana', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (26, 71, 1, '2025-11-18 09:50:00', 'Pele desidratada e sem viço', 'Sem doenças crônicas relatadas.', 'Dipirona', 'Anticoncepcional oral', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (27, 63, 1, '2025-11-19 09:50:00', 'Contorno mandibular pouco definido', 'Nenhum procedimento estético anterior.', 'Látex', 'Nenhum', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (28, 54, 1, '2025-11-19 13:50:00', 'Flacidez facial', 'Já realizou toxina botulínica há mais de um ano.', 'Nenhuma conhecida', 'Losartana', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (29, 65, 1, '2025-11-21 12:50:00', 'Lábios finos e assimétricos', 'Já realizou toxina botulínica há mais de um ano.', 'Nenhuma conhecida', 'Losartana', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (30, 97, 1, '2025-11-21 15:50:00', 'Olheiras profundas', 'Sem doenças crônicas relatadas.', 'Dipirona', 'Nenhum', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (31, 121, 1, '2025-11-24 08:50:00', 'Pele desidratada e sem viço', 'Já realizou toxina botulínica há mais de um ano.', 'Dipirona', 'Nenhum', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (32, 99, 1, '2025-11-27 08:50:00', 'Olheiras profundas', 'Hipotireoidismo controlado.', 'Nenhuma conhecida', 'Anticoncepcional oral', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (33, 82, 1, '2025-11-27 10:50:00', 'Perda de volume no rosto', 'Hipertensão controlada com medicação.', 'Látex', 'Nenhum', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (34, 31, 1, '2025-12-01 13:50:00', 'Perda de volume no rosto', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Vitamina D', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (35, 91, 1, '2025-12-04 12:50:00', 'Flacidez facial', 'Rinite alérgica.', 'Nenhuma conhecida', 'Vitamina D', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (36, 49, 1, '2025-12-08 08:50:00', 'Linhas de expressão na testa', 'Rinite alérgica.', 'Penicilina', 'Nenhum', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (37, 37, 1, '2025-12-08 09:50:00', 'Lábios finos e assimétricos', 'Hipertensão controlada com medicação.', 'Nenhuma conhecida', 'Nenhum', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (38, 79, 1, '2025-12-08 10:20:00', 'Linhas de expressão na testa', 'Sem doenças crônicas relatadas.', 'Nenhuma conhecida', 'Levotiroxina', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (39, 85, 1, '2025-12-17 10:50:00', 'Flacidez facial', 'Hipotireoidismo controlado.', 'Penicilina', 'Losartana', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (40, 86, 1, '2025-12-24 13:20:00', 'Flacidez facial', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Nenhum', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (41, 5, 1, '2025-12-25 09:20:00', 'Perda de volume no rosto', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Nenhum', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (42, 32, 1, '2025-12-29 08:50:00', 'Contorno mandibular pouco definido', 'Hipotireoidismo controlado.', 'Dipirona', 'Nenhum', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (43, 45, 1, '2025-12-30 08:50:00', 'Pele desidratada e sem viço', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Vitamina D', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (44, 88, 1, '2025-12-31 12:50:00', 'Pele desidratada e sem viço', 'Já realizou toxina botulínica há mais de um ano.', 'Nenhuma conhecida', 'Levotiroxina', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (45, 4, 1, '2026-01-01 14:50:00', 'Lábios finos e assimétricos', 'Rinite alérgica.', 'Nenhuma conhecida', 'Losartana', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (46, 1, 1, '2026-01-05 09:50:00', 'Flacidez facial', 'Hipertensão controlada com medicação.', 'Látex', 'Nenhum', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (47, 55, 1, '2026-01-05 12:50:00', 'Lábios finos e assimétricos', 'Hipertensão controlada com medicação.', 'Látex', 'Levotiroxina', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (48, 47, 1, '2026-01-06 15:50:00', 'Rugas ao redor dos olhos', 'Nenhum procedimento estético anterior.', 'Dipirona', 'Anticoncepcional oral', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (49, 118, 1, '2026-01-09 08:50:00', 'Flacidez facial', 'Já realizou toxina botulínica há mais de um ano.', 'Nenhuma conhecida', 'Nenhum', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (50, 92, 1, '2026-01-19 12:50:00', 'Contorno mandibular pouco definido', 'Rinite alérgica.', 'Látex', 'Losartana', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (51, 50, 1, '2026-01-19 14:50:00', 'Perda de volume no rosto', 'Sem doenças crônicas relatadas.', 'Nenhuma conhecida', 'Nenhum', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (52, 93, 1, '2026-01-19 16:50:00', 'Contorno mandibular pouco definido', 'Rinite alérgica.', 'Látex', 'Levotiroxina', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (53, 107, 1, '2026-01-19 17:20:00', 'Perda de volume no rosto', 'Sem doenças crônicas relatadas.', 'Nenhuma conhecida', 'Nenhum', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (54, 104, 1, '2026-01-20 13:50:00', 'Rugas ao redor dos olhos', 'Sem doenças crônicas relatadas.', 'Dipirona', 'Vitamina D', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (55, 89, 1, '2026-01-21 12:50:00', 'Flacidez facial', 'Hipotireoidismo controlado.', 'Nenhuma conhecida', 'Anticoncepcional oral', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (56, 25, 1, '2026-01-26 09:50:00', 'Flacidez facial', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Vitamina D', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (57, 15, 1, '2026-01-27 09:50:00', 'Contorno mandibular pouco definido', 'Sem doenças crônicas relatadas.', 'Nenhuma conhecida', 'Nenhum', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (58, 119, 1, '2026-01-28 14:50:00', 'Perda de volume no rosto', 'Hipotireoidismo controlado.', 'Penicilina', 'Anticoncepcional oral', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (59, 9, 1, '2026-01-29 14:50:00', 'Perda de volume no rosto', 'Já realizou toxina botulínica há mais de um ano.', 'Nenhuma conhecida', 'Anticoncepcional oral', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (60, 58, 1, '2026-02-02 08:50:00', 'Pele desidratada e sem viço', 'Hipotireoidismo controlado.', 'Dipirona', 'Anticoncepcional oral', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (61, 20, 1, '2026-02-02 10:50:00', 'Pele desidratada e sem viço', 'Rinite alérgica.', 'Nenhuma conhecida', 'Losartana', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (62, 29, 1, '2026-02-02 12:50:00', 'Rugas ao redor dos olhos', 'Já realizou toxina botulínica há mais de um ano.', 'Nenhuma conhecida', 'Anticoncepcional oral', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (63, 6, 1, '2026-02-02 14:50:00', 'Olheiras profundas', 'Sem doenças crônicas relatadas.', 'Nenhuma conhecida', 'Anticoncepcional oral', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (64, 126, 1, '2026-02-04 16:50:00', 'Flacidez facial', 'Hipotireoidismo controlado.', 'Nenhuma conhecida', 'Losartana', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (65, 96, 1, '2026-02-05 08:50:00', 'Flacidez facial', 'Já realizou toxina botulínica há mais de um ano.', 'Látex', 'Nenhum', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (66, 87, 1, '2026-02-06 15:50:00', 'Rugas ao redor dos olhos', 'Sem doenças crônicas relatadas.', 'Dipirona', 'Anticoncepcional oral', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (67, 22, 1, '2026-02-16 12:50:00', 'Perda de volume no rosto', 'Sem doenças crônicas relatadas.', 'Nenhuma conhecida', 'Vitamina D', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (68, 43, 1, '2026-02-17 16:50:00', 'Linhas de expressão na testa', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Anticoncepcional oral', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (69, 74, 1, '2026-02-19 16:50:00', 'Perda de volume no rosto', 'Hipotireoidismo controlado.', 'Nenhuma conhecida', 'Nenhum', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (70, 30, 1, '2026-02-23 14:50:00', 'Lábios finos e assimétricos', 'Hipotireoidismo controlado.', 'Penicilina', 'Anticoncepcional oral', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (71, 73, 1, '2026-02-25 10:50:00', 'Contorno mandibular pouco definido', 'Rinite alérgica.', 'Nenhuma conhecida', 'Vitamina D', 'Orientada sobre cuidados pós-procedimento.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (72, 36, 1, '2026-03-02 10:50:00', 'Flacidez facial', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Vitamina D', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (73, 61, 1, '2026-03-03 09:50:00', 'Contorno mandibular pouco definido', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Levotiroxina', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (74, 95, 1, '2026-03-04 16:50:00', 'Perda de volume no rosto', 'Hipotireoidismo controlado.', 'Dipirona', 'Levotiroxina', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (75, 28, 1, '2026-03-09 08:50:00', 'Contorno mandibular pouco definido', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Vitamina D', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (76, 39, 1, '2026-03-09 09:50:00', 'Contorno mandibular pouco definido', 'Sem doenças crônicas relatadas.', 'Penicilina', 'Nenhum', 'Paciente prefere resultado natural.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (77, 8, 1, '2026-03-09 10:50:00', 'Perda de volume no rosto', 'Nenhum procedimento estético anterior.', 'Nenhuma conhecida', 'Levotiroxina', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (78, 27, 1, '2026-03-09 13:50:00', 'Flacidez facial', 'Sem doenças crônicas relatadas.', 'Látex', 'Nenhum', NULL);
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (79, 44, 1, '2026-03-09 13:50:00', 'Perda de volume no rosto', 'Nenhum procedimento estético anterior.', 'Dipirona', 'Losartana', 'Retorno sugerido conforme evolução.');
INSERT INTO anamnese (id_anamnese, id_paciente, id_profissional, data_registro, queixa_principal, historico_saude, alergias, medicamentos_em_uso, observacoes) VALUES (80, 38, 1, '2026-03-09 16:50:00', 'Linhas de expressão na testa', 'Já realizou toxina botulínica há mais de um ano.', 'Dipirona', 'Anticoncepcional oral', 'Paciente prefere resultado natural.');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (1, NULL, 'Marketing', 'Impulsionamento de publicações', 712.00, '2025-10-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (2, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2025-10-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (3, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2025-10-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (4, 1, 'Limpeza', 'Material de limpeza da sala', 150.00, '2025-10-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (5, 2, 'Limpeza', 'Material de limpeza da sala', 92.00, '2025-10-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (6, 3, 'Limpeza', 'Material de limpeza da sala', 172.00, '2025-10-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (7, 2, 'Manutenção', 'Manutenção de equipamento', 154.00, '2025-10-20', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (8, NULL, 'Venda de produtos', 'Venda de dermocosmético home care', 151.00, '2025-10-25', 'RECEITA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (9, NULL, 'Marketing', 'Impulsionamento de publicações', 1067.00, '2025-11-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (10, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2025-11-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (11, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2025-11-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (12, 1, 'Limpeza', 'Material de limpeza da sala', 110.00, '2025-11-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (13, 2, 'Limpeza', 'Material de limpeza da sala', 124.00, '2025-11-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (14, 3, 'Limpeza', 'Material de limpeza da sala', 112.00, '2025-11-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (15, NULL, 'Marketing', 'Impulsionamento de publicações', 697.00, '2025-12-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (16, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2025-12-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (17, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2025-12-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (18, 1, 'Limpeza', 'Material de limpeza da sala', 134.00, '2025-12-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (19, 2, 'Limpeza', 'Material de limpeza da sala', 178.00, '2025-12-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (20, 3, 'Limpeza', 'Material de limpeza da sala', 134.00, '2025-12-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (21, NULL, 'Venda de produtos', 'Venda de dermocosmético home care', 351.00, '2025-12-25', 'RECEITA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (22, NULL, 'Marketing', 'Impulsionamento de publicações', 783.00, '2026-01-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (23, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-01-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (24, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-01-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (25, 1, 'Limpeza', 'Material de limpeza da sala', 119.00, '2026-01-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (26, 2, 'Limpeza', 'Material de limpeza da sala', 119.00, '2026-01-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (27, 3, 'Limpeza', 'Material de limpeza da sala', 114.00, '2026-01-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (28, 3, 'Manutenção', 'Manutenção de equipamento', 533.00, '2026-01-20', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (29, NULL, 'Marketing', 'Impulsionamento de publicações', 735.00, '2026-02-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (30, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-02-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (31, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-02-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (32, 1, 'Limpeza', 'Material de limpeza da sala', 131.00, '2026-02-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (33, 2, 'Limpeza', 'Material de limpeza da sala', 125.00, '2026-02-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (34, 3, 'Limpeza', 'Material de limpeza da sala', 146.00, '2026-02-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (35, 2, 'Manutenção', 'Manutenção de equipamento', 462.00, '2026-02-20', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (36, NULL, 'Venda de produtos', 'Venda de dermocosmético home care', 159.00, '2026-02-25', 'RECEITA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (37, NULL, 'Marketing', 'Impulsionamento de publicações', 757.00, '2026-03-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (38, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-03-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (39, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-03-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (40, 1, 'Limpeza', 'Material de limpeza da sala', 87.00, '2026-03-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (41, 2, 'Limpeza', 'Material de limpeza da sala', 90.00, '2026-03-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (42, 3, 'Limpeza', 'Material de limpeza da sala', 156.00, '2026-03-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (43, NULL, 'Venda de produtos', 'Venda de dermocosmético home care', 173.00, '2026-03-25', 'RECEITA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (44, NULL, 'Marketing', 'Impulsionamento de publicações', 1099.00, '2026-04-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (45, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-04-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (46, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-04-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (47, 1, 'Limpeza', 'Material de limpeza da sala', 81.00, '2026-04-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (48, 2, 'Limpeza', 'Material de limpeza da sala', 82.00, '2026-04-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (49, 3, 'Limpeza', 'Material de limpeza da sala', 153.00, '2026-04-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (50, NULL, 'Venda de produtos', 'Venda de dermocosmético home care', 441.00, '2026-04-25', 'RECEITA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (51, NULL, 'Marketing', 'Impulsionamento de publicações', 759.00, '2026-05-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (52, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-05-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (53, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-05-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (54, 1, 'Limpeza', 'Material de limpeza da sala', 154.00, '2026-05-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (55, 2, 'Limpeza', 'Material de limpeza da sala', 180.00, '2026-05-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (56, 3, 'Limpeza', 'Material de limpeza da sala', 166.00, '2026-05-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (57, NULL, 'Marketing', 'Impulsionamento de publicações', 1067.00, '2026-06-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (58, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-06-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (59, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-06-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (60, 1, 'Limpeza', 'Material de limpeza da sala', 125.00, '2026-06-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (61, 2, 'Limpeza', 'Material de limpeza da sala', 100.00, '2026-06-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (62, 3, 'Limpeza', 'Material de limpeza da sala', 123.00, '2026-06-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (63, 3, 'Manutenção', 'Manutenção de equipamento', 452.00, '2026-06-20', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (64, NULL, 'Marketing', 'Impulsionamento de publicações', 993.00, '2026-07-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (65, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-07-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (66, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-07-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (67, 1, 'Limpeza', 'Material de limpeza da sala', 177.00, '2026-07-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (68, 2, 'Limpeza', 'Material de limpeza da sala', 105.00, '2026-07-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (69, 3, 'Limpeza', 'Material de limpeza da sala', 175.00, '2026-07-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (70, 3, 'Manutenção', 'Manutenção de equipamento', 182.00, '2026-07-20', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (71, NULL, 'Marketing', 'Impulsionamento de publicações', 923.00, '2026-08-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (72, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-08-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (73, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-08-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (74, 1, 'Limpeza', 'Material de limpeza da sala', 169.00, '2026-08-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (75, 2, 'Limpeza', 'Material de limpeza da sala', 118.00, '2026-08-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (76, 3, 'Limpeza', 'Material de limpeza da sala', 135.00, '2026-08-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (77, NULL, 'Marketing', 'Impulsionamento de publicações', 822.00, '2026-09-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (78, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-09-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (79, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-09-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (80, 1, 'Limpeza', 'Material de limpeza da sala', 138.00, '2026-09-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (81, 2, 'Limpeza', 'Material de limpeza da sala', 120.00, '2026-09-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (82, 3, 'Limpeza', 'Material de limpeza da sala', 80.00, '2026-09-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (83, 3, 'Manutenção', 'Manutenção de equipamento', 496.00, '2026-09-20', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (84, NULL, 'Marketing', 'Impulsionamento de publicações', 1072.00, '2026-10-03', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (85, NULL, 'Contabilidade', 'Honorários do escritório contábil', 650.00, '2026-10-10', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (86, NULL, 'Software', 'Assinatura de sistemas e agenda', 189.00, '2026-10-12', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (87, 1, 'Limpeza', 'Material de limpeza da sala', 146.00, '2026-10-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (88, 2, 'Limpeza', 'Material de limpeza da sala', 103.00, '2026-10-15', 'DESPESA');
INSERT INTO lancamento (id_lancamento, id_unidade, categoria, descricao, valor, data_lancamento, tipo) VALUES (89, 3, 'Limpeza', 'Material de limpeza da sala', 114.00, '2026-10-15', 'DESPESA');
COMMIT;

-- ====================== 3. CONSULTAS ======================
-- ============================================================
-- ZENITH - consultas de apoio aos requisitos RF03, RF07, RF08 e RF09
-- (agenda, retornos, financeiro, estoque e relatórios gerenciais).
-- A associação exata de cada consulta ao número do requisito deve ser
-- conferida com o documento de requisitos do relatório.
--
-- Executar no Workbench conectado ao banco zenith (ou com
-- `python consultas_executar.py`, que roda todas como zenith_app).
-- Cada consulta começa com uma linha "-- [NN] título".
-- Parâmetros ficam em variáveis (@...) logo acima de cada consulta.
-- ============================================================
USE zenith_teste;

-- [01] Agenda por unidade e período (JOIN de 5 tabelas)
-- Lista os atendimentos de uma unidade num intervalo, com paciente,
-- telefone e procedimentos previstos.
SET @unidade = 1;
SET @inicio  = '2026-10-16';
SET @fim     = '2026-11-15';
SELECT a.id_atendimento,
       a.data_hora,
       u.nome_clinica,
       p.nome_completo                                         AS paciente,
       p.telefone_paciente,
       a.status,
       GROUP_CONCAT(pr.nome_procedimento ORDER BY pr.nome_procedimento SEPARATOR ', ')
                                                               AS procedimentos
FROM atendimento a
JOIN unidade u  ON u.id_unidade  = a.id_unidade
JOIN paciente p ON p.id_paciente = a.id_paciente
LEFT JOIN atendimento_procedimento ap ON ap.id_atendimento = a.id_atendimento
LEFT JOIN procedimento pr             ON pr.id_procedimento = ap.id_procedimento
WHERE a.id_unidade = @unidade
  AND a.data_hora >= @inicio
  AND a.data_hora <  @fim + INTERVAL 1 DAY
GROUP BY a.id_atendimento, a.data_hora, u.nome_clinica, p.nome_completo,
         p.telefone_paciente, a.status
ORDER BY a.data_hora;

-- [02] Retornos pendentes: prazo de retorno vencido e paciente sem novo
-- atendimento agendado ou realizado (view vw_dash_retorno).
SELECT r.nome_completo,
       r.telefone_paciente,
       r.nome_procedimento,
       r.ultima_data,
       r.data_retorno_prevista,
       DATEDIFF(CURDATE(), r.data_retorno_prevista) AS dias_em_atraso
FROM vw_dash_retorno r
WHERE r.vencido AND NOT r.retornou
ORDER BY dias_em_atraso DESC;

-- [03] Faturamento, custo de locação, despesas e margem por unidade e mês
-- SUPOSIÇÃO: custo de locação = valor_locacao x dias com atendimento
-- Realizado (regra a confirmar com a cliente; ver vw_dash_unidade).
SELECT ano_mes, nome_clinica, faturamento, dias_com_atendimento,
       custo_locacao, despesas, margem
FROM vw_dash_unidade
ORDER BY ano_mes, nome_clinica;

-- [04] Faturamento por procedimento no período (GROUP BY)
SET @inicio = '2026-07-01';
SET @fim    = '2026-09-30';
SELECT nome_procedimento,
       SUM(quantidade_realizada) AS vezes_realizado,
       SUM(faturamento)          AS faturamento
FROM vw_dash_procedimento
WHERE ano_mes BETWEEN DATE_FORMAT(@inicio, '%Y-%m') AND DATE_FORMAT(@fim, '%Y-%m')
GROUP BY id_procedimento, nome_procedimento
ORDER BY faturamento DESC;

-- [05] Ticket médio por unidade (só atendimentos Realizado)
SELECT f.nome_clinica,
       COUNT(*)                      AS atendimentos_realizados,
       SUM(f.valor_total)            AS faturamento,
       ROUND(AVG(f.valor_total), 2)  AS ticket_medio
FROM vw_faturamento f
GROUP BY f.id_unidade, f.nome_clinica
ORDER BY ticket_medio DESC;

-- [06] Pacientes ativos por cidade e bairro, só bairros com 3 ou mais
-- pacientes (GROUP BY com HAVING)
SELECT cidade_paciente AS cidade,
       bairro_paciente AS bairro,
       COUNT(*)        AS pacientes_ativos
FROM paciente
WHERE ativo = TRUE
GROUP BY cidade_paciente, bairro_paciente
HAVING COUNT(*) >= 3
ORDER BY cidade, pacientes_ativos DESC;

-- [07] Taxa de comparecimento por unidade:
-- realizados / (realizados + faltas). Cancelados não entram.
SELECT u.nome_clinica,
       SUM(c.realizados) AS realizados,
       SUM(c.faltas)     AS faltas,
       ROUND(100 * SUM(c.realizados) / NULLIF(SUM(c.realizados) + SUM(c.faltas), 0), 1)
                         AS taxa_comparecimento_pct
FROM vw_dash_comparecimento c
JOIN unidade u ON u.id_unidade = c.id_unidade
GROUP BY u.id_unidade, u.nome_clinica
ORDER BY taxa_comparecimento_pct DESC;

-- [08] Estoque atual de todos os insumos ativos, com alerta de mínimo
SELECT nome_insumo, marca, unidade_medida, total_comprado, total_consumido,
       saldo, estoque_minimo,
       CASE WHEN abaixo_minimo THEN 'ABAIXO DO MÍNIMO' ELSE 'OK' END AS situacao
FROM vw_estoque_atual
WHERE ativo = TRUE
ORDER BY abaixo_minimo DESC, nome_insumo;

-- [09] Alertas de validade: lotes vencidos ou que vencem em até 60 dias
-- (SUPOSIÇÃO: sem controle FIFO por lote; o saldo é o do insumo).
SELECT nome_insumo, lote, data_compra, data_validade, dias_para_vencer,
       CASE WHEN vencido THEN 'VENCIDO' ELSE 'VENCE EM BREVE' END AS situacao,
       saldo_insumo
FROM vw_alerta_validade
ORDER BY data_validade;

-- [10] Custo estimado de insumos por procedimento e margem estimada
-- (quantidade padrão x preço da compra mais recente).
SELECT nome_procedimento, preco_tabela, custo_insumos, margem_estimada,
       ROUND(100 * margem_estimada / NULLIF(preco_tabela, 0), 1) AS margem_pct
FROM vw_custo_procedimento
ORDER BY margem_estimada DESC;

-- [11] Ranking de origem de captação dos pacientes (GROUP BY com HAVING:
-- só origens com pelo menos 5 pacientes)
SELECT origem_captacao,
       COUNT(*)                                            AS pacientes,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM paciente), 1) AS percentual
FROM paciente
GROUP BY origem_captacao
HAVING COUNT(*) >= 5
ORDER BY pacientes DESC;

-- [12] Novos pacientes por mês (pela data de cadastro)
SELECT DATE_FORMAT(criado_em, '%Y-%m') AS ano_mes,
       COUNT(*)                        AS novos_pacientes
FROM paciente
GROUP BY DATE_FORMAT(criado_em, '%Y-%m')
ORDER BY ano_mes;

-- [13] Histórico de atendimentos de um paciente (JOIN de 4 tabelas)
SET @paciente = 1;
SELECT a.data_hora,
       u.nome_clinica,
       a.status,
       pr.nome_procedimento,
       ap.regiao_aplicada,
       ap.quantidade_aplicada,
       ap.valor_cobrado
FROM atendimento a
JOIN unidade u                   ON u.id_unidade      = a.id_unidade
JOIN atendimento_procedimento ap ON ap.id_atendimento = a.id_atendimento
JOIN procedimento pr             ON pr.id_procedimento = ap.id_procedimento
WHERE a.id_paciente = @paciente
ORDER BY a.data_hora DESC;

-- [14] Consumo real x quantidade padrão por procedimento e insumo
-- (JOIN de 5 tabelas). Responde "quanto cada procedimento consome de
-- insumo": o padrão sugerido e a média realmente usada.
SELECT pr.nome_procedimento,
       i.nome_insumo,
       i.unidade_medida,
       pi.quantidade_padrao,
       ROUND(AVG(c.quantidade), 2) AS media_consumida,
       COUNT(*)                    AS registros
FROM consumo c
JOIN atendimento_procedimento ap ON ap.id_atendimento = c.id_atendimento
JOIN procedimento_insumo pi      ON pi.id_procedimento = ap.id_procedimento
                                AND pi.id_insumo      = c.id_insumo
JOIN procedimento pr             ON pr.id_procedimento = ap.id_procedimento
JOIN insumo i                    ON i.id_insumo       = c.id_insumo
GROUP BY pr.nome_procedimento, i.nome_insumo, i.unidade_medida, pi.quantidade_padrao
ORDER BY pr.nome_procedimento, i.nome_insumo;

-- [15] Compras por fornecedor e insumo (JOIN de 3 tabelas): mostra que o
-- mesmo insumo é comprado de mais de um fornecedor (relação N:M).
SELECT i.nome_insumo,
       f.razao_social,
       COUNT(*)                         AS compras,
       SUM(co.quantidade)               AS quantidade_total,
       ROUND(AVG(co.preco_unitario), 2) AS preco_medio
FROM compra co
JOIN insumo i     ON i.id_insumo     = co.id_insumo
JOIN fornecedor f ON f.id_fornecedor = co.id_fornecedor
GROUP BY i.nome_insumo, f.razao_social
ORDER BY i.nome_insumo, compras DESC;

-- [16] Pacientes ativos sem nenhum atendimento realizado nos últimos 180 dias
-- (subconsulta com NOT EXISTS): lista para ação de reativação.
SELECT p.nome_completo, p.telefone_paciente, p.origem_captacao
FROM paciente p
WHERE p.ativo = TRUE
  AND NOT EXISTS (SELECT 1
                    FROM atendimento a
                   WHERE a.id_paciente = p.id_paciente
                     AND a.status = 'Realizado'
                     AND a.data_hora >= CURDATE() - INTERVAL 180 DAY)
ORDER BY p.nome_completo;

-- [17] Procedimentos com faturamento acima da média dos procedimentos
-- (subconsulta na cláusula HAVING)
SELECT nome_procedimento, SUM(faturamento) AS faturamento
FROM vw_dash_procedimento
GROUP BY id_procedimento, nome_procedimento
HAVING SUM(faturamento) > (SELECT AVG(total)
                             FROM (SELECT SUM(faturamento) AS total
                                     FROM vw_dash_procedimento
                                    GROUP BY id_procedimento) t)
ORDER BY faturamento DESC;

-- [18] Insumos cujo preço da última compra ficou acima do preço médio
-- histórico (subconsulta correlacionada)
SELECT i.nome_insumo,
       pa.preco_unitario                         AS preco_atual,
       (SELECT ROUND(AVG(co.preco_unitario), 2)
          FROM compra co WHERE co.id_insumo = i.id_insumo) AS preco_medio
FROM insumo i
JOIN vw_preco_insumo_atual pa ON pa.id_insumo = i.id_insumo
WHERE pa.preco_unitario > (SELECT AVG(co.preco_unitario)
                             FROM compra co WHERE co.id_insumo = i.id_insumo)
ORDER BY i.nome_insumo;

-- [19] Faturamento por forma de pagamento (GROUP BY com HAVING:
-- só formas com faturamento acima de R$ 10.000)
SELECT forma_pagamento,
       COUNT(*)         AS atendimentos,
       SUM(valor_total) AS faturamento
FROM vw_faturamento
GROUP BY forma_pagamento
HAVING SUM(valor_total) > 10000
ORDER BY faturamento DESC;

-- [20] Faturamento mensal total (base do gráfico de linha do dashboard)
SELECT ano_mes, SUM(faturamento) AS faturamento, SUM(realizados) AS realizados
FROM vw_dash_kpis_mensal
GROUP BY ano_mes
ORDER BY ano_mes;

-- ====================== 4. FIM ======================
COMMIT;
