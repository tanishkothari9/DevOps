from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration.

    Non-secret values come from a ConfigMap (APP_ENV, LOG_LEVEL, DB_HOST, DB_PORT, DB_NAME),
    credentials from a Secret (DB_USER, DB_PASSWORD). DATABASE_URL overrides everything
    (used by docker compose and the test-suite).
    """

    app_name: str = "StockPilot API"
    app_version: str = "1.0.0"
    app_env: str = "local"
    log_level: str = "INFO"
    low_stock_alert_threshold: int = 0

    database_url: str | None = None
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "stockpilot"
    db_user: str = "stockpilot"
    db_password: str = "stockpilot"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def sqlalchemy_url(self) -> str:
        if self.database_url:
            return self.database_url
        return (
            f"postgresql+psycopg://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


settings = Settings()
