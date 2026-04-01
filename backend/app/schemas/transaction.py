from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional
from zoneinfo import ZoneInfo

# Base schema
class TransactionBase(BaseModel):
    amount: float = Field(..., gt=0, description="Amount must be positive")

# Input for Deposit (Just amount needed)
class DepositRequest(TransactionBase):
    pass

# Input for Transfer (Receiver + Amount needed)
class TransferRequest(TransactionBase):
    receiver_phone: str
    confirm_fraud: bool = False

# Output Schema (What the user sees)
class TransactionResponse(BaseModel):
    id: int
    amount: float
    transaction_type: str
    status: str
    
    # We want the final output to be a string
    timestamp: str 

    # --- ADD THESE TWO FIELDS ---
    sender_id: Optional[int] = None
    receiver_id: int
    # ----------------------------
    
    sender_name: Optional[str] = None
    receiver_name: str

    # --- THE FIX: mode="before" ---
    # This allows the validator to accept the 'datetime' from the DB 
    # and convert it to 'str' BEFORE Pydantic checks the type.
    @field_validator("timestamp", mode="before")
    @classmethod
    def format_timestamp(cls, v):
        # Handle case where v is already a string (rare but possible)
        if isinstance(v, str):
            return v
            
        # Ensure it's a datetime object
        if isinstance(v, datetime):
            # 1. Ensure the datetime is aware (Assume UTC if naive)
            if v.tzinfo is None:
                v = v.replace(tzinfo=ZoneInfo("UTC"))
                
            # 2. Convert to Indian Standard Time (Asia/Kolkata)
            ist_time = v.astimezone(ZoneInfo("Asia/Kolkata"))
            
            # 3. Format as dd-mm-yyyy hh:mm:ss
            return ist_time.strftime("%d-%m-%Y %H:%M:%S")
            
        return str(v) # Fallback
    # ------------------------------

    class Config:
        from_attributes = True
