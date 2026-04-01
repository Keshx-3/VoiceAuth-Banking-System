from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from loguru import logger
from typing import List

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.payment_request import PaymentRequest
from app.models.transaction import Transaction
from app.schemas.payment_request import PaymentRequestCreate, PaymentRequestResponse
from app.core.fraud_engine import run_fraud_model

router = APIRouter()

@router.post("/", response_model=PaymentRequestResponse)
def create_payment_request(
    request: PaymentRequestCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 1. Validate Payer
    payer = db.query(User).filter(User.phone_number == request.payer_phone).first()
    if not payer:
        raise HTTPException(status_code=404, detail="Payer not found")
    
    if payer.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot request money from yourself")

    # 2. Run Fraud Check (Simulating Payer -> Requester transaction)
    # Why? We want to warn the PAYER if this looks like a fraud transaction when they see it.
    fraud_input = {
        "type": "PAYMENT",
        "amount": request.amount,
        "oldbalanceOrg": payer.balance,
        "newbalanceOrig": payer.balance - request.amount, # Simulation
        "oldbalanceDest": current_user.balance,
        "newbalanceDest": current_user.balance + request.amount # Simulation
    }
    
    prediction, score = run_fraud_model(fraud_input)
    fraud_reason = None
    
    if prediction == 1:
        fraud_reason = "ML model detected suspicious request pattern"
        logger.warning(f"Payment Request FLAGGED | Score: {score}")

    # 3. Create Request
    payment_request = PaymentRequest(
        requester_id=current_user.id,
        payer_id=payer.id,
        amount=request.amount,
        status="PENDING",
        fraud_score=score,
        fraud_reason=fraud_reason
    )
    
    db.add(payment_request)
    db.commit()
    db.refresh(payment_request)
    
    # 4. Populate names
    payment_request.requester_name = current_user.full_name
    payment_request.payer_name = payer.full_name
    
    return payment_request

@router.get("/", response_model=List[PaymentRequestResponse])
def get_payment_requests(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    requests = db.query(PaymentRequest).filter(
        (PaymentRequest.requester_id == current_user.id) | 
        (PaymentRequest.payer_id == current_user.id)
    ).order_by(PaymentRequest.created_at.desc()).all()
    
    for req in requests:
        req.requester_name = req.requester.full_name if req.requester else "Unknown"
        req.payer_name = req.payer.full_name if req.payer else "Unknown"
        
        # Only show fraud warning to the PAYER (when PENDING)
        if req.payer_id == current_user.id and req.status == "PENDING":
            pass # Keep fields as is
        elif req.requester_id == current_user.id:
            # Hide fraud info from requester (optional security choice)
            req.fraud_reason = None
            req.fraud_score = None
            
    return requests

@router.post("/{request_id}/{action}", response_model=PaymentRequestResponse)
def respond_payment_request(
    request_id: int,
    action: str, # ACCEPT or REJECT
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    payment_request = db.query(PaymentRequest).filter(PaymentRequest.id == request_id).first()
    
    if not payment_request:
        raise HTTPException(status_code=404, detail="Request not found")
        
    if payment_request.payer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to respond to this request")
        
    if payment_request.status != "PENDING":
        raise HTTPException(status_code=400, detail="Request already processed")

    action = action.upper()
    
    if action == "REJECT":
        payment_request.status = "REJECTED"
        db.commit()
        db.refresh(payment_request)
        return payment_request
        
    elif action == "ACCEPT":
        # Execute Transfer Logic
        if current_user.balance < payment_request.amount:
             raise HTTPException(status_code=400, detail="Insufficient Balance")
             
        requester = db.query(User).filter(User.id == payment_request.requester_id).first()
        if not requester:
             raise HTTPException(status_code=404, detail="Requester user not found")
             
        # 1. Update Balances
        current_user.balance -= payment_request.amount
        requester.balance += payment_request.amount
        
        # 2. Create Transaction Record
        transaction = Transaction(
            sender_id=current_user.id,
            receiver_id=requester.id,
            amount=payment_request.amount,
            transaction_type="REQUEST",
            status="SUCCESS",
            fraud_score=payment_request.fraud_score, # Carry over the score
            fraud_reason=payment_request.fraud_reason
        )
        db.add(transaction)
        
        # 3. Update Request Status
        payment_request.status = "ACCEPTED"
        
        db.commit()
        db.refresh(payment_request)
        
        # Populate for response
        payment_request.requester_name = requester.full_name
        payment_request.payer_name = current_user.full_name
        
        return payment_request
    
    else:
        raise HTTPException(status_code=400, detail="Invalid action")
