@echo off
cd /d "%~dp0"
echo === Teste das validacoes ===
python teste_validacoes.py
echo.
echo === Teste da formatacao da tela de pacientes ===
python teste_formatos.py
echo.
echo === Teste da conexao com o banco ===
python teste_conexao.py
echo.
echo === Teste do cadastro de pacientes ===
python teste_paciente.py
echo.
pause
