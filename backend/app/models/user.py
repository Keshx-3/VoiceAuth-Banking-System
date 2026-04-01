from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base
import random

def generate_six_digit_id():
    """Generates a random 6-digit number between 100000 and 999999."""
    return random.randint(100000, 999999)

class User(Base):
    __tablename__ = "users"

    # 2. Add 'default=generate_six_digit_id' to the column definition
    # We remove 'autoincrement=True' effectively by providing a manual default
    id = Column(
        Integer, 
        primary_key=True, 
        index=True, 
        default=generate_six_digit_id,
        unique=True
    )
    
    phone_number = Column(String, unique=True, index=True)
    full_name = Column(String)
    hashed_password = Column(String)
    profile_pic = Column(String, nullable=True)
    balance = Column(Float, default=0.0)
    is_active = Column(Boolean, default=True)
    use_voice_auth = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    voice_profiles = relationship("VoiceProfile", back_populates="user", cascade="all, delete-orphan")