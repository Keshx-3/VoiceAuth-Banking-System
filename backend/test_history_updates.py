import requests
import random
import string
import time

BASE_URL = "http://127.0.0.1:8000/api/v1"

def random_phone():
    return "9" + "9" + ''.join(random.choices(string.digits, k=8))

def create_user(phone, name, password="password"):
    print(f"Creating user {name} ({phone})...")
    response = requests.post(f"{BASE_URL}/auth/signup", data={
        "full_name": name,
        "phone_number": phone,
        "password": password,
    })
    return response

def login(phone, password="password"):
    response = requests.post(f"{BASE_URL}/auth/login", data={
        "username": phone,
        "password": password
    })
    if response.status_code != 200:
        return None
    return response.json().get("access_token")

def test_history_features():
    # 1. Setup
    phone_a = random_phone()
    phone_b = random_phone()
    
    create_user(phone_a, "User Alice")
    create_user(phone_b, "User Bob")
    
    token_a = login(phone_a)
    token_b = login(phone_b)
    
    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    user_a_id = requests.get(f"{BASE_URL}/users/me", headers=headers_a).json()["id"]
    user_b_id = requests.get(f"{BASE_URL}/users/me", headers=headers_b).json()["id"]

    print(f"User A ID: {user_a_id}, User B ID: {user_b_id}")

    # 2. Deposit and Transfer (Standard Transfer)
    print("\n--- Testing Standard Transfer (RECEIVED label) ---")
    requests.post(f"{BASE_URL}/transactions/deposit", json={"amount": 1000}, headers=headers_a)
    requests.post(f"{BASE_URL}/transactions/transfer", json={"amount": 300, "receiver_phone": phone_b}, headers=headers_a)
    
    # Check History for user B
    hist_b = requests.get(f"{BASE_URL}/transactions/history", headers=headers_b).json()
    transfer_txn = next((t for t in hist_b if t["amount"] == 300), None)
    if transfer_txn and transfer_txn["transaction_type"] == "RECEIVED":
        print("✅ SUCCESS: Transfer shows as 'RECEIVED' for receiver in history.")
    else:
        print(f"❌ FAILURE: Expected 'RECEIVED' type, got {transfer_txn['transaction_type'] if transfer_txn else 'None'}")

    # 3. Payment Request (Pending)
    print("\n--- Testing Pending Payment Request in Chat ---")
    req_res = requests.post(f"{BASE_URL}/requests/", json={"amount": 150, "payer_phone": phone_a}, headers=headers_b)
    req_id = req_res.json()["id"]
    
    # Check Chat for user A
    chat_a = requests.get(f"{BASE_URL}/transactions/chat/{user_b_id}", headers=headers_a).json()
    req_item = next((t for t in chat_a if t["amount"] == 150 and t["transaction_type"] == "REQUEST"), None)
    if req_item and req_item["status"] == "PENDING":
        print("✅ SUCCESS: Pending request shows up in chat history.")
    else:
        print("❌ FAILURE: Pending request missing from chat.")

    # 4. Accept Payment Request (REQUEST type transaction)
    print("\n--- Testing Accepted Payment Request (REQUEST type) ---")
    requests.post(f"{BASE_URL}/requests/{req_id}/ACCEPT", headers=headers_a)
    
    # Check History for user A
    hist_a = requests.get(f"{BASE_URL}/transactions/history", headers=headers_a).json()
    req_txn = next((t for t in hist_a if t["amount"] == 150), None)
    if req_txn and req_txn["transaction_type"] == "REQUEST":
        print("✅ SUCCESS: Accepted request shows as 'REQUEST' type in history.")
    else:
        print(f"❌ FAILURE: Expected 'REQUEST' type for accepted request, got {req_txn['transaction_type'] if req_txn else 'None'}")

    # Check Chat for user A (Should see the TRANSACTION instead of REQUEST if logic filters correctly, or both if sorted)
    # Actually, we filtered 'ACCEPTED' requests from being duplicated.
    chat_a_final = requests.get(f"{BASE_URL}/transactions/chat/{user_b_id}", headers=headers_a).json()
    # There should be exactly one item for amount 150 (the transaction)
    items_150 = [t for t in chat_a_final if t["amount"] == 150]
    if len(items_150) == 1 and items_150[0]["transaction_type"] == "REQUEST":
        print("✅ SUCCESS: Chat history shows the accepted request correctly without duplication.")
    else:
        print(f"❌ FAILURE: Chat history duplication or missing item. Count: {len(items_150)}")

if __name__ == "__main__":
    test_history_features()
