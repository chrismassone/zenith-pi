@echo off
cd /d "%~dp0"
echo === Testes de logica (sem banco) ===
python teste_validacoes.py
python teste_formatos.py
python teste_login.py
echo.
echo === Banco principal zenith (somente leitura) ===
python teste_conexao.py
python popular_validar.py
python consultas_executar.py
python teste_dashboard.py
echo.
echo === Banco de TESTE zenith_teste (grava e apaga) ===
python popular_validar.py --teste
python teste_paciente.py
python teste_servicos.py
python teste_retorno_agenda.py
echo.
echo === Interface (abre a janela; nao mexa no mouse/teclado) ===
python teste_rolagem.py
python teste_fluxo_pacientes.py
python teste_fluxo_interface.py
echo.
pause
