@echo off
cd /d "%~dp0"
python main.py
if errorlevel 1 (
  echo.
  echo O programa fechou com erro. Copie a mensagem acima e envie ao Claude.
  pause
)
