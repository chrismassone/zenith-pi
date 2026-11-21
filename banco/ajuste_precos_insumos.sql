-- ============================================================
-- ZENITH - AJUSTE DOS PRECOS DE COMPRA DOS INSUMOS (16/11/2026)
-- Alternativa a rodar zenith_completo.sql de novo: atualiza SO o
-- preco_unitario das compras, sem apagar o banco (usuarios do app,
-- atendimentos e demais dados ficam como estao).
-- Mesmos valores que popular_gerar.py passa a gerar: insumos em
-- ~25-35% do preco de cada procedimento.
-- Execute como root no MySQL Workbench. Tambem remove a compra de
-- teste 147 (Botulift a R$ 350/U), se ela ainda existir.
-- ============================================================
USE zenith;
START TRANSACTION;
DELETE FROM compra WHERE id_compra = 147 AND id_insumo = 3 AND preco_unitario = 350.00;
UPDATE compra SET preco_unitario = 434.79 WHERE id_compra = 1 AND id_insumo = 7;  -- antes 600.42
UPDATE compra SET preco_unitario = 7.88 WHERE id_compra = 3 AND id_insumo = 1;  -- antes 14.28
UPDATE compra SET preco_unitario = 725.47 WHERE id_compra = 4 AND id_insumo = 9;  -- antes 2031.32
UPDATE compra SET preco_unitario = 5.24 WHERE id_compra = 6 AND id_insumo = 3;  -- antes 7.24
UPDATE compra SET preco_unitario = 646.90 WHERE id_compra = 7 AND id_insumo = 11;  -- antes 716.57
UPDATE compra SET preco_unitario = 341.16 WHERE id_compra = 11 AND id_insumo = 4;  -- antes 1013.14
UPDATE compra SET preco_unitario = 598.57 WHERE id_compra = 13 AND id_insumo = 10;  -- antes 887.88
UPDATE compra SET preco_unitario = 379.85 WHERE id_compra = 14 AND id_insumo = 6;  -- antes 569.77
UPDATE compra SET preco_unitario = 8.84 WHERE id_compra = 21 AND id_insumo = 2;  -- antes 17.49
UPDATE compra SET preco_unitario = 135.13 WHERE id_compra = 22 AND id_insumo = 5;  -- antes 598.43
UPDATE compra SET preco_unitario = 134.24 WHERE id_compra = 23 AND id_insumo = 5;  -- antes 594.48
UPDATE compra SET preco_unitario = 891.91 WHERE id_compra = 24 AND id_insumo = 8;  -- antes 1941.21
UPDATE compra SET preco_unitario = 7.78 WHERE id_compra = 26 AND id_insumo = 1;  -- antes 14.11
UPDATE compra SET preco_unitario = 777.48 WHERE id_compra = 27 AND id_insumo = 9;  -- antes 2176.95
UPDATE compra SET preco_unitario = 367.31 WHERE id_compra = 28 AND id_insumo = 6;  -- antes 550.96
UPDATE compra SET preco_unitario = 321.20 WHERE id_compra = 29 AND id_insumo = 4;  -- antes 953.88
UPDATE compra SET preco_unitario = 8.66 WHERE id_compra = 31 AND id_insumo = 2;  -- antes 17.13
UPDATE compra SET preco_unitario = 413.71 WHERE id_compra = 33 AND id_insumo = 7;  -- antes 571.32
UPDATE compra SET preco_unitario = 5.66 WHERE id_compra = 34 AND id_insumo = 3;  -- antes 7.82
UPDATE compra SET preco_unitario = 339.05 WHERE id_compra = 35 AND id_insumo = 4;  -- antes 1006.89
UPDATE compra SET preco_unitario = 137.08 WHERE id_compra = 37 AND id_insumo = 5;  -- antes 607.08
UPDATE compra SET preco_unitario = 352.29 WHERE id_compra = 38 AND id_insumo = 6;  -- antes 528.44
UPDATE compra SET preco_unitario = 7.77 WHERE id_compra = 40 AND id_insumo = 1;  -- antes 14.08
UPDATE compra SET preco_unitario = 331.64 WHERE id_compra = 42 AND id_insumo = 4;  -- antes 984.88
UPDATE compra SET preco_unitario = 776.63 WHERE id_compra = 43 AND id_insumo = 9;  -- antes 2174.57
UPDATE compra SET preco_unitario = 133.42 WHERE id_compra = 44 AND id_insumo = 5;  -- antes 590.86
UPDATE compra SET preco_unitario = 347.67 WHERE id_compra = 46 AND id_insumo = 6;  -- antes 521.51
UPDATE compra SET preco_unitario = 317.04 WHERE id_compra = 47 AND id_insumo = 4;  -- antes 941.52
UPDATE compra SET preco_unitario = 8.09 WHERE id_compra = 48 AND id_insumo = 1;  -- antes 14.66
UPDATE compra SET preco_unitario = 577.55 WHERE id_compra = 49 AND id_insumo = 10;  -- antes 856.70
UPDATE compra SET preco_unitario = 852.27 WHERE id_compra = 50 AND id_insumo = 8;  -- antes 1854.94
UPDATE compra SET preco_unitario = 863.48 WHERE id_compra = 52 AND id_insumo = 8;  -- antes 1879.33
UPDATE compra SET preco_unitario = 7.91 WHERE id_compra = 55 AND id_insumo = 1;  -- antes 14.34
UPDATE compra SET preco_unitario = 724.99 WHERE id_compra = 56 AND id_insumo = 9;  -- antes 2029.97
UPDATE compra SET preco_unitario = 318.52 WHERE id_compra = 58 AND id_insumo = 4;  -- antes 945.90
UPDATE compra SET preco_unitario = 368.22 WHERE id_compra = 59 AND id_insumo = 6;  -- antes 552.33
UPDATE compra SET preco_unitario = 656.54 WHERE id_compra = 60 AND id_insumo = 11;  -- antes 727.25
UPDATE compra SET preco_unitario = 147.03 WHERE id_compra = 61 AND id_insumo = 5;  -- antes 651.15
UPDATE compra SET preco_unitario = 134.52 WHERE id_compra = 62 AND id_insumo = 5;  -- antes 595.72
UPDATE compra SET preco_unitario = 770.18 WHERE id_compra = 63 AND id_insumo = 9;  -- antes 2156.49
UPDATE compra SET preco_unitario = 8.38 WHERE id_compra = 66 AND id_insumo = 1;  -- antes 15.18
UPDATE compra SET preco_unitario = 424.79 WHERE id_compra = 67 AND id_insumo = 7;  -- antes 586.62
UPDATE compra SET preco_unitario = 134.33 WHERE id_compra = 69 AND id_insumo = 5;  -- antes 594.90
UPDATE compra SET preco_unitario = 147.39 WHERE id_compra = 71 AND id_insumo = 5;  -- antes 652.72
UPDATE compra SET preco_unitario = 374.23 WHERE id_compra = 72 AND id_insumo = 6;  -- antes 561.35
UPDATE compra SET preco_unitario = 8.72 WHERE id_compra = 73 AND id_insumo = 2;  -- antes 17.25
UPDATE compra SET preco_unitario = 5.82 WHERE id_compra = 74 AND id_insumo = 3;  -- antes 8.05
UPDATE compra SET preco_unitario = 318.46 WHERE id_compra = 75 AND id_insumo = 4;  -- antes 945.74
UPDATE compra SET preco_unitario = 8.27 WHERE id_compra = 77 AND id_insumo = 1;  -- antes 14.99
UPDATE compra SET preco_unitario = 315.07 WHERE id_compra = 78 AND id_insumo = 4;  -- antes 935.66
UPDATE compra SET preco_unitario = 148.05 WHERE id_compra = 79 AND id_insumo = 5;  -- antes 655.66
UPDATE compra SET preco_unitario = 5.75 WHERE id_compra = 80 AND id_insumo = 3;  -- antes 7.94
UPDATE compra SET preco_unitario = 137.00 WHERE id_compra = 81 AND id_insumo = 5;  -- antes 606.71
UPDATE compra SET preco_unitario = 753.41 WHERE id_compra = 84 AND id_insumo = 9;  -- antes 2109.54
UPDATE compra SET preco_unitario = 331.49 WHERE id_compra = 86 AND id_insumo = 4;  -- antes 984.42
UPDATE compra SET preco_unitario = 8.10 WHERE id_compra = 87 AND id_insumo = 1;  -- antes 14.69
UPDATE compra SET preco_unitario = 669.07 WHERE id_compra = 88 AND id_insumo = 11;  -- antes 741.12
UPDATE compra SET preco_unitario = 756.05 WHERE id_compra = 89 AND id_insumo = 9;  -- antes 2116.93
UPDATE compra SET preco_unitario = 325.88 WHERE id_compra = 90 AND id_insumo = 4;  -- antes 967.77
UPDATE compra SET preco_unitario = 403.98 WHERE id_compra = 91 AND id_insumo = 7;  -- antes 557.87
UPDATE compra SET preco_unitario = 602.89 WHERE id_compra = 94 AND id_insumo = 10;  -- antes 894.29
UPDATE compra SET preco_unitario = 134.32 WHERE id_compra = 95 AND id_insumo = 5;  -- antes 594.84
UPDATE compra SET preco_unitario = 443.34 WHERE id_compra = 96 AND id_insumo = 7;  -- antes 612.23
UPDATE compra SET preco_unitario = 5.55 WHERE id_compra = 99 AND id_insumo = 3;  -- antes 7.67
UPDATE compra SET preco_unitario = 773.84 WHERE id_compra = 101 AND id_insumo = 9;  -- antes 2166.75
UPDATE compra SET preco_unitario = 376.60 WHERE id_compra = 102 AND id_insumo = 6;  -- antes 564.91
UPDATE compra SET preco_unitario = 418.63 WHERE id_compra = 103 AND id_insumo = 7;  -- antes 578.11
UPDATE compra SET preco_unitario = 7.90 WHERE id_compra = 104 AND id_insumo = 1;  -- antes 14.32
UPDATE compra SET preco_unitario = 9.11 WHERE id_compra = 105 AND id_insumo = 2;  -- antes 18.01
UPDATE compra SET preco_unitario = 315.16 WHERE id_compra = 106 AND id_insumo = 4;  -- antes 935.94
UPDATE compra SET preco_unitario = 720.09 WHERE id_compra = 107 AND id_insumo = 9;  -- antes 2016.24
UPDATE compra SET preco_unitario = 720.07 WHERE id_compra = 110 AND id_insumo = 9;  -- antes 2016.21
UPDATE compra SET preco_unitario = 372.58 WHERE id_compra = 111 AND id_insumo = 6;  -- antes 558.87
UPDATE compra SET preco_unitario = 589.63 WHERE id_compra = 112 AND id_insumo = 10;  -- antes 874.62
UPDATE compra SET preco_unitario = 348.03 WHERE id_compra = 113 AND id_insumo = 4;  -- antes 1033.53
UPDATE compra SET preco_unitario = 142.32 WHERE id_compra = 114 AND id_insumo = 5;  -- antes 630.27
UPDATE compra SET preco_unitario = 8.38 WHERE id_compra = 116 AND id_insumo = 1;  -- antes 15.19
UPDATE compra SET preco_unitario = 5.52 WHERE id_compra = 118 AND id_insumo = 3;  -- antes 7.62
UPDATE compra SET preco_unitario = 146.77 WHERE id_compra = 119 AND id_insumo = 5;  -- antes 649.96
UPDATE compra SET preco_unitario = 325.55 WHERE id_compra = 121 AND id_insumo = 4;  -- antes 966.79
UPDATE compra SET preco_unitario = 381.05 WHERE id_compra = 122 AND id_insumo = 6;  -- antes 571.57
UPDATE compra SET preco_unitario = 148.31 WHERE id_compra = 125 AND id_insumo = 5;  -- antes 656.78
UPDATE compra SET preco_unitario = 8.09 WHERE id_compra = 126 AND id_insumo = 1;  -- antes 14.66
UPDATE compra SET preco_unitario = 7.73 WHERE id_compra = 127 AND id_insumo = 1;  -- antes 14.01
UPDATE compra SET preco_unitario = 138.96 WHERE id_compra = 128 AND id_insumo = 5;  -- antes 615.41
UPDATE compra SET preco_unitario = 348.70 WHERE id_compra = 129 AND id_insumo = 6;  -- antes 523.05
UPDATE compra SET preco_unitario = 7.65 WHERE id_compra = 130 AND id_insumo = 1;  -- antes 13.87
UPDATE compra SET preco_unitario = 138.89 WHERE id_compra = 134 AND id_insumo = 5;  -- antes 615.09
UPDATE compra SET preco_unitario = 769.89 WHERE id_compra = 136 AND id_insumo = 9;  -- antes 2155.69
UPDATE compra SET preco_unitario = 339.06 WHERE id_compra = 137 AND id_insumo = 4;  -- antes 1006.90
UPDATE compra SET preco_unitario = 142.85 WHERE id_compra = 138 AND id_insumo = 5;  -- antes 632.60
UPDATE compra SET preco_unitario = 143.18 WHERE id_compra = 139 AND id_insumo = 5;  -- antes 634.09
UPDATE compra SET preco_unitario = 739.30 WHERE id_compra = 140 AND id_insumo = 9;  -- antes 2070.04
UPDATE compra SET preco_unitario = 143.66 WHERE id_compra = 141 AND id_insumo = 5;  -- antes 636.22
UPDATE compra SET preco_unitario = 8.08 WHERE id_compra = 142 AND id_insumo = 1;  -- antes 14.64
UPDATE compra SET preco_unitario = 5.29 WHERE id_compra = 143 AND id_insumo = 3;  -- antes 7.31
UPDATE compra SET preco_unitario = 444.86 WHERE id_compra = 144 AND id_insumo = 7;  -- antes 614.33
UPDATE compra SET preco_unitario = 428.17 WHERE id_compra = 145 AND id_insumo = 7;  -- antes 591.28
UPDATE compra SET preco_unitario = 5.49 WHERE id_compra = 146 AND id_insumo = 3;  -- antes 7.59
COMMIT;

-- Conferencia: deve retornar 146 e 109096.76
SELECT COUNT(*), ROUND(SUM(quantidade * preco_unitario), 2) FROM compra;
