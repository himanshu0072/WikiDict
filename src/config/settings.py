from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict, YamlConfigSettingsSource
from pathlib import Path
from typing import Tuple, Type

PROJECT_ROOT = Path(__file__).parent.parent.parent
ENV_FILE_PATH = PROJECT_ROOT / ".env"
CONFIG_FILE_PATH = PROJECT_ROOT / "config.yaml"

class EnvSettings(BaseSettings):
    access_key: str = Field(alias="AWS_ACCESS_KEY")
    secret_key: str = Field(alias="AWS_SECRET_KEY")
    region: str = Field(alias="AWS_REGION")
    bucket_name: str = Field(alias="AWS_BUCKET_NAME")

    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE_PATH),
        env_file_encoding="utf-8",
        validate_default=True
    )

class LoggingConfig(BaseModel):
    level: str = "INFO"
    format: str
    file: str
    max_size: int
    backup_count: int

class AutoSuggestConfig(BaseModel):
    enabled: bool
    max_suggestions: int

class CacheConfig(BaseModel):
    """LRU cache configuration for S3 meaning lookups."""
    max_size: int = 10000  # Default: 10,000 entries (~80 MB)
    enabled: bool = True

class AppSettings(BaseSettings):
    service_name: str
    description: str
    version: str
    environment: str
    host: str
    port: int
    debug: bool
    api_prefix: str
    cors_origins: list[str]
    logging: LoggingConfig
    autosuggest: AutoSuggestConfig
    cache: CacheConfig = Field(default_factory=CacheConfig)  # Optional with defaults
    base_url: str

    model_config = SettingsConfigDict(
        yaml_file=str(CONFIG_FILE_PATH),
        extra='ignore'
    )

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: Type[BaseSettings],
        init_settings,
        env_settings,
        dotenv_settings,
        file_secret_settings,
    ) -> Tuple:
        return (
            init_settings,
            YamlConfigSettingsSource(settings_cls),
            env_settings,
            file_secret_settings,
        )
    

# Instantiate settings
env_settings = EnvSettings()
app_settings = AppSettings()
