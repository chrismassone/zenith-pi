@echo off
cd /d "%~dp0"
echo === Sem banco ===
python -m testes.teste_validacoes
python -m testes.teste_formatos
python -m testes.teste_login
echo.
echo === Banco zenith (somente leitura) ===
python -m testes.teste_conexao
python -m ferramentas.popular_validar
python -m ferramentas.consultas_executar
python -m testes.teste_dashboard
echo.
echo === Banco zenith_teste (grava e apaga) ===
python -m ferramentas.popular_validar --teste
python -m testes.teste_paciente
python -m testes.teste_servicos
python -m testes.teste_retorno_agenda
echo.
echo === Interface (abre a janela; nao mexa no mouse) ===
python -m testes.teste_rolagem
python -m testes.teste_fluxo_pacientes
python -m testes.teste_fluxo_interface
echo.
pause
