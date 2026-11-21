import os
from dotenv import load_dotenv

load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "database": os.getenv("DB_NAME", "zenith"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "connection_timeout": int(os.getenv("DB_TIMEOUT", "10")),
}

# TiDB Cloud exige TLS; no MySQL local fica desligado, como antes
if os.getenv("DB_SSL", "off").strip().lower() in ("on", "1", "true", "sim"):
    DB_CONFIG.update(
        ssl_ca=os.getenv("DB_SSL_CA") or None,
        ssl_verify_cert=True,
        ssl_verify_identity=True,
    )

# horário de Brasília em toda sessão (o TiDB Cloud roda em UTC)
DB_TIME_ZONE = os.getenv("DB_TIME_ZONE", "-03:00")
