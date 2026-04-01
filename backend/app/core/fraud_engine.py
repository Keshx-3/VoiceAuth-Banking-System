import joblib
import pandas as pd
from pathlib import Path

MODEL_PATH = Path("app/ml/fraud_detection_pipeline.pkl")

model = joblib.load(MODEL_PATH)

def run_fraud_model(transaction_data: dict):
    """
    Expects keys:
    type, amount, oldbalanceOrg, newbalanceOrig,
    oldbalanceDest, newbalanceDest
    """
    sample = pd.DataFrame([transaction_data])

    prediction = model.predict(sample)[0]
    probability = model.predict_proba(sample)[0][1]

    return prediction, float(probability)
