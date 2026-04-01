import requests
import random
import string

BASE_URL = "http://127.0.0.1:8000/api/v1"

def random_string(length=8):
    return ''.join(random.choices(string.ascii_letters, k=length))

def random_phone():
    return "9" + "9" + ''.join(random.choices(string.digits, k=8))

def create_user(phone, name, password="password"):
    print(f"DTO: Creating user {name} ({phone})...")
    response = requests.post(f"{BASE_URL}/auth/signup", data={
        "full_name": name,
        "phone_number": phone,
        "password": password,
        # "email": ... email is not accepted by the endpoint logic shown in auth.py 
        # (Wait, auth.py logic lines 34-40 do NOT list email. It only takes phone, name, password, pic.
        # So passing email in JSON was ignored before, but passing it in Form data is fine as extra field, 
        # but I should remove it to be clean)
    })
    print(f"Signup Status: {response.status_code}")
    if response.status_code != 200:
        print(f"Signup Error: {response.text}")
    return response

def login(phone, password="password"):
    print(f"DTO: Logging in {phone}...")
    response = requests.post(f"{BASE_URL}/auth/login", data={
        "username": phone, # OAuth2 expects username, we use phone
        "password": password
    })
    if response.status_code != 200:
        print(f"Login Error: {response.text}")
        return None
    return response.json().get("access_token")

def test_payment_request():
    # 1. Setup Random Users to avoid conflicts
    user_a_phone = random_phone()
    user_b_phone = random_phone()
    
    create_user(user_a_phone, "User A")
    create_user(user_b_phone, "User B")
    
    token_a = login(user_a_phone)
    token_b = login(user_b_phone)
    
    if not token_a or not token_b:
        print("Failed to login")
        return

    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # 2. Deposit money to User B (so they can pay)
    print("\n--- Depositing to User B ---")
    requests.post(f"{BASE_URL}/transactions/deposit", json={"amount": 1000}, headers=headers_b)

    # 3. User A requests 500 from User B
    print("\n--- Creating Request ---")
    req_payload = {"amount": 500, "payer_phone": user_b_phone}
    res = requests.post(f"{BASE_URL}/requests/", json=req_payload, headers=headers_a)
    print(f"Create Request Status: {res.status_code}")
    print(f"Response: {res.json()}")
    
    if res.status_code != 200:
        return
        
    req_id = res.json()["id"]

    # 4. User B checks requests
    print("\n--- Listing Requests ---")
    res = requests.get(f"{BASE_URL}/requests/", headers=headers_b)
    print(f"User B Requests: {res.json()}")
    
    # 5. User B Accepts
    print("\n--- User B Accepting ---")
    res = requests.post(f"{BASE_URL}/requests/{req_id}/accept", headers=headers_b)
    print(f"Accept Status: {res.status_code}")
    print(f"Response: {res.json()}")
    
    if res.status_code != 200:
        print(f"Accept Error: {res.text}")
        return

    # 6. Verify Transaction
    print("\n--- Verifying Transaction History ---")
    res = requests.get(f"{BASE_URL}/transactions/history", headers=headers_a)
    # Check if latest transaction is transfer from User B
    txns = res.json()
    found = False
    for txn in txns:
        if txn.get('amount') == 500 and txn.get('transaction_type') == "TRANSFER":
             found = True
             break
             
    if found:
        print("SUCCESS: Transaction record found!")
    else:
        print("WARNING: Transaction record verification failed or different.")
        print("History:", txns)

if __name__ == "__main__":
    test_payment_request()
