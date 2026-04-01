from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class TokenBlacklist(Base):
    __tablename__ = "token_blacklist"

    id = Column(Integer, primary_key=True, index=True)
    token = Column(String, unique=True, index=True)
    blacklisted_on = Column(DateTime(timezone=True), server_default=func.now())