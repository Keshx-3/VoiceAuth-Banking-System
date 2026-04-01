from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from sqlalchemy.exc import IntegrityError
from loguru import logger

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.transaction import Transaction
from app.schemas.transaction import DepositRequest, TransferRequest, TransactionResponse
from sqlalchemy import or_
from sqlalchemy import func
from app.core.fraud_engine import run_fraud_model

router = APIRouter()

# --- 1. DEPOSIT MONEY ---
@router.post("/deposit", response_model=TransactionResponse)
def deposit_money(
    request: DepositRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    logger.info(f"User {current_user.id} attempting to deposit {request.amount}")

    max_retries = 5
    for attempt in range(max_retries):
        try:
            # 1. Get User
            # We removed 'with db.begin()' because the session IS the transaction
            user = db.query(User).filter(User.id == current_user.id).first()
            
            if not user:
                raise HTTPException(status_code=404, detail="User not found")

            # 2. Update Balance
            user.balance += request.amount
            
            # 3. Create Transaction
            transaction = Transaction(
                sender_id=None,
                receiver_id=user.id,
                amount=request.amount,
                transaction_type="DEPOSIT",
                status="SUCCESS"
            )
            db.add(transaction)
            
            # 4. Commit & Refresh
            # This saves everything permanently. If it fails, it goes to 'except'
            db.commit()
            
            # Refresh gets the generated ID and Timestamp from the DB
            db.refresh(transaction)
            
            # Set names for response
            setattr(transaction, 'sender_name', "Self (Deposit)")
            setattr(transaction, 'receiver_name', user.full_name)

            logger.success(f"Deposit successful. New Balance: {user.balance} | Txn ID: {transaction.id}")
            return transaction

        except IntegrityError as e:
            db.rollback() # CRITICAL: Undo changes if DB fails
            error_str = str(e)
            if "UNIQUE constraint failed: transactions.id" in error_str or "transactions_pkey" in error_str:
                logger.warning(f"ID Collision on attempt {attempt+1}. Retrying...")
                continue
            logger.error(f"Database Error: {e}")
            raise HTTPException(status_code=500, detail="Database error occurred")
        
        except Exception as e:
            db.rollback() # CRITICAL: Undo changes if Logic/Server fails
            logger.error(f"Deposit failed: {e}")
            raise HTTPException(status_code=500, detail=f"Deposit failed: {str(e)}")

    raise HTTPException(status_code=500, detail="System busy. Please try again.")


# --- 2. TRANSFER MONEY ---
@router.post("/transfer", response_model=TransactionResponse)
def transfer_money(
    request: TransferRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    logger.info(f"Transfer request: {current_user.phone_number} -> {request.receiver_phone}")

    if current_user.phone_number == request.receiver_phone:
        raise HTTPException(status_code=400, detail="Cannot send money to yourself")

    max_retries = 5
    FLAGGED_LIMIT = 5

    for attempt in range(max_retries):
        try:
            # 1️⃣ Get Sender
            sender = db.query(User).filter(User.id == current_user.id).first()
            if not sender:
                raise HTTPException(status_code=404, detail="Sender not found")

            # 2️⃣ Get Receiver
            receiver = db.query(User).filter(User.phone_number == request.receiver_phone).first()
            if not receiver:
                raise HTTPException(status_code=404, detail="Receiver not found")

            # 3️⃣ Pre-check: Block if receiver is risky
            flagged_count = db.query(func.count(Transaction.id)).filter(
                Transaction.receiver_id == receiver.id,
                Transaction.status == "FLAGGED"
            ).scalar()

            if flagged_count >= FLAGGED_LIMIT:
                logger.warning(
                    f"Transfer blocked: Receiver {receiver.id} has {flagged_count} flagged transactions"
                )
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Account under review due to suspicious activity"
                )

            # 4️⃣ Balance check
            if sender.balance < request.amount:
                raise HTTPException(status_code=400, detail="Insufficient Balance")

            # 5️⃣ Fraud detection (BEFORE transfer)
            fraud_input = {
                "type": "PAYMENT",
                "amount": request.amount,
                "oldbalanceOrg": sender.balance,
                "newbalanceOrig": sender.balance - request.amount,
                "oldbalanceDest": receiver.balance,
                "newbalanceDest": receiver.balance + request.amount
            }

            prediction, score = run_fraud_model(fraud_input)
            
            # If fraud detected and NOT confirmed, block and ask for confirmation
            if prediction == 1 and not request.confirm_fraud:
                logger.warning(f"Potential fraud detected for transfer {sender.id} -> {receiver.id} | Score: {score}")
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={
                        "message": "PROBABLE_FRAUD",
                        "fraud_score": score,
                        "explanation": f"This transaction looks suspicious (Fraud Score: {score*100:.2f}%). Do you want to proceed?"
                    }
                )

            # 6️⃣ Execute transfer (Balance update)
            sender.balance -= request.amount
            receiver.balance += request.amount

            # 7️⃣ Create transaction record
            transaction = Transaction(
                sender_id=sender.id,
                receiver_id=receiver.id,
                amount=request.amount,
                transaction_type="TRANSFER",
                status="FLAGGED" if prediction == 1 else "SUCCESS",
                fraud_score=score if prediction == 1 else None,
                fraud_reason="ML model detected suspicious transaction (User Confirmed)" if prediction == 1 else None
            )
            db.add(transaction)
            db.commit()
            db.refresh(transaction)

            if prediction == 1:
                logger.warning(f"Transaction {transaction.id} PROCESSED with FLAGGED status | Fraud Score: {score}")
            else:
                logger.info(f"Transaction {transaction.id} SUCCESS | Fraud Score: {score}")

            # 8️⃣ Set names for response
            setattr(transaction, "sender_name", sender.full_name)
            setattr(transaction, "receiver_name", receiver.full_name)

            logger.success(f"Transfer completed. ID: {transaction.id}")
            return transaction

        except IntegrityError as e:
            db.rollback()
            error_str = str(e)
            if "UNIQUE constraint failed: transactions.id" in error_str or "transactions_pkey" in error_str:
                logger.warning(f"ID Collision on attempt {attempt + 1}. Retrying...")
                continue
            logger.error(f"Database Error: {e}")
            raise HTTPException(status_code=500, detail="Database error occurred")

        except HTTPException as he:
            db.rollback()
            raise he

        except Exception as e:
            db.rollback()
            logger.error(f"Transfer failed: {e}")
            raise HTTPException(status_code=500, detail=f"Transfer failed: {str(e)}")

    raise HTTPException(status_code=500, detail="System busy. Please try again.")




@router.get("/chat/{contact_id}", response_model=list[TransactionResponse])
def get_transaction_chat(
    contact_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Fetch the full transaction history between the logged-in user 
    and a specific contact (contact_id).
    Used to build the 'Chat Interface' for payments.
    """
    # 1. Query Logic
    # Transactions: (Me -> Them) OR (Them -> Me)
    transactions = db.query(Transaction).filter(
        or_(
            (Transaction.sender_id == current_user.id) & (Transaction.receiver_id == contact_id),
            (Transaction.sender_id == contact_id) & (Transaction.receiver_id == current_user.id)
        )
    ).all()

    # Payment Requests: (Me Requesting from Them) OR (Them Requesting from Me)
    # We skip 'ACCEPTED' because those are already in the 'transactions' table as type 'REQUEST'
    from app.models.payment_request import PaymentRequest
    pending_requests = db.query(PaymentRequest).filter(
        or_(
            (PaymentRequest.requester_id == current_user.id) & (PaymentRequest.payer_id == contact_id),
            (PaymentRequest.payer_id == current_user.id) & (PaymentRequest.requester_id == contact_id)
        )
    ).filter(PaymentRequest.status != "ACCEPTED").all()

    # 3. Merge and Format
    history = []

    # Process Transactions
    for txn in transactions:
        if txn.sender_id == current_user.id:
            setattr(txn, 'sender_name', current_user.full_name)
            setattr(txn, 'receiver_name', txn.receiver.full_name)
        else:
            setattr(txn, 'sender_name', txn.sender.full_name)
            setattr(txn, 'receiver_name', current_user.full_name)
        
        # If I am the receiver, the type should be RECEIVED for clarity in chat
        if txn.receiver_id == current_user.id and txn.transaction_type == "TRANSFER":
             setattr(txn, 'transaction_type', "RECEIVED")
        
        history.append(txn)

    # Process Payment Requests (Convert to match TransactionResponse schema)
    for req in pending_requests:
        setattr(req, 'transaction_type', "REQUEST")
        setattr(req, 'timestamp', req.created_at)
        setattr(req, 'sender_id', req.payer_id)
        setattr(req, 'receiver_id', req.requester_id)
        setattr(req, 'sender_name', req.payer.full_name)
        setattr(req, 'receiver_name', req.requester.full_name)
        history.append(req)

    # 4. Sort by timestamp descending
    history.sort(key=lambda x: x.timestamp if hasattr(x, 'timestamp') else x.created_at, reverse=True)

    return history

@router.get("/history", response_model=list[TransactionResponse])
def get_transaction_history(
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Fetch all transactions where the user is either the SENDER or the RECEIVER.
    Supports pagination:
    - skip: Number of records to skip (default 0)
    - limit: Number of records to return (default 20)
    """
    
    # 1. Query Logic: (Sender Is Me) OR (Receiver Is Me)
    transactions = db.query(Transaction).filter(
        or_(
            Transaction.sender_id == current_user.id,
            Transaction.receiver_id == current_user.id
        )
    ).options(
        joinedload(Transaction.sender), 
        joinedload(Transaction.receiver)
    ).order_by(Transaction.timestamp.desc()).offset(skip).limit(limit).all()

    # 2. Populate Display Names for the Schema
    for txn in transactions:
        # Handle Sender Name
        if txn.sender_id is None:
            setattr(txn, 'sender_name', "Bank Deposit") # System deposit
        elif txn.sender_id == current_user.id:
            setattr(txn, 'sender_name', "You")
        else:
            setattr(txn, 'sender_name', txn.sender.full_name if txn.sender else "Unknown")

        # Handle Receiver Name
        if txn.receiver_id == current_user.id:
            setattr(txn, 'receiver_name', "You")
        else:
            setattr(txn, 'receiver_name', txn.receiver.full_name if txn.receiver else "Unknown")

        # Handle Transaction Type Labels (Transfer vs Received vs Request)
        if txn.receiver_id == current_user.id and txn.transaction_type == "TRANSFER":
             setattr(txn, 'transaction_type', "RECEIVED")
        # accepted requests are already 'REQUEST' type in DB

    return transactions
