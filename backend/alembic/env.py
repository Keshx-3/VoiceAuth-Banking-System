import sys
import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

# -----------------------------------------------------------
# 1. ADD THIS BLOCK to allow imports from your 'app' folder
# -----------------------------------------------------------
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

# 2. Import your Database Base and Config
from app.core.database import Base
from app.core.config import settings

# 3. Import ALL your models here so Alembic can "see" them
from app.models.user import User 
from app.models.transaction import Transaction
from app.models.token import TokenBlacklist
from app.models.payment_request import PaymentRequest
# from app.models.transaction import Transaction (Add this later when you create it)
# -----------------------------------------------------------

config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# -----------------------------------------------------------
# 4. Set the Database URL from your settings (Environment Variable)
# -----------------------------------------------------------
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# 5. Set target_metadata to your Base.metadata
target_metadata = Base.metadata
# -----------------------------------------------------------

def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, 
            target_metadata=target_metadata,
            render_as_batch=True # <--- KEEP THIS TRUE FOR SQLITE
        )

        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()