from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    PROJECT_NAME: str = "FastAPI Bank"
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    BASE_URL: str = "http://127.0.0.1:8000"

    SAVE_LOCAL: bool = False

    AWS_REGION: str | None = None
    AWS_S3_BUCKET: str | None = None
    AWS_ACCESS_KEY_ID: str | None = None
    AWS_SECRET_ACCESS_KEY: str | None = None

    class Config:
        env_file = ".env"
        case_sensitive = True

@lru_cache
def get_settings():
    return Settings()

settings = get_settings()
