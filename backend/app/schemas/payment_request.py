from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class PaymentRequestCreate(BaseModel):
    amount: float
    payer_phone: str

class PaymentRequestResponse(BaseModel):
    id: int
    requester_id: int
    payer_id: int
    amount: float
    status: str
    fraud_score: Optional[float] = None
    fraud_reason: Optional[str] = None
    created_at: datetime
    
    requester_name: Optional[str] = None
    payer_name: Optional[str] = None

    class Config:
        from_attributes = True
