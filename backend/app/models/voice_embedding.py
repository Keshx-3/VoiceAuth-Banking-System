from sqlalchemy import Column, Integer, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class VoiceProfile(Base):
    __tablename__ = "voice_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)  # foreign key
    embedding = Column(Text)  # store embedding as JSON string

    # Relationship back to User
    user = relationship("User", back_populates="voice_profiles")
