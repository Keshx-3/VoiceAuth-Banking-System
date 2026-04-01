from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

class PaymentRequest(Base):
    __tablename__ = "payment_requests"

    id = Column(Integer, primary_key=True, index=True)
    
    # requester: the one asking for money
    requester_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # payer: the one who is supposed to pay
    payer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    amount = Column(Float, nullable=False)
    
    # PENDING, ACCEPTED, REJECTED
    status = Column(String, default="PENDING")
    
    # Fraud details
    fraud_score = Column(Float, nullable=True)
    fraud_reason = Column(String, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    requester = relationship("User", foreign_keys=[requester_id], backref="sent_payment_requests")
    payer = relationship("User", foreign_keys=[payer_id], backref="received_payment_requests")
