@echo off
cd /d "%~dp0"
echo Instalando as bibliotecas...
python -m pip install -r requirements.txt
echo.
echo Se nao apareceu nenhum erro acima, de dois cliques em iniciar.bat
pause
