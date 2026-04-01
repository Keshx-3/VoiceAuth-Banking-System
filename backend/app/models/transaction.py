from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base
import random

def generate_transaction_id():
    return random.randint(1000, 9999)

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(
        Integer, 
        primary_key=True, 
        index=True, 
        default=generate_transaction_id, 
        unique=True
    )
    
    # Who sent the money? (Nullable for Deposits)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    
    # Who got the money?
    receiver_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    amount = Column(Float, nullable=False)
    transaction_type = Column(String, nullable=False) # "DEPOSIT" or "TRANSFER"
    status = Column(String, default="SUCCESS")
    fraud_score = Column(Float, nullable=True)
    fraud_reason = Column(String, nullable=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships to access User details easily
    sender = relationship("User", foreign_keys=[sender_id], backref="sent_transactions")
    receiver = relationship("User", foreign_keys=[receiver_id], backref="received_transactions")