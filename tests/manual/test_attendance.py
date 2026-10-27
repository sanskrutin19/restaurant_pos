import requests
import json

BASE_URL = "http://127.0.0.1:8000"

def test_clock_in_api():
    # 1. Login to get token for Captain
    login_data = {"username": "captain", "password": "captain123"}
    resp = requests.post(f"{BASE_URL}/auth/token", data=login_data)
    if resp.status_code != 200:
        print(f"Login failed: {resp.text}")
        return
    
    token_resp = resp.json()
    token = token_resp["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 2. Get user ID from staff list
    resp = requests.get(f"{BASE_URL}/staff/users", headers=headers)
    users = resp.json()
    captain = next((u for u in users if u["username"] == "captain"), None)
    if not captain:
        print("Captain not found in staff list")
        return
    
    user_id = captain["id"]
    print(f"Captain ID: {user_id}")
    
    # 3. Try to clock in
    resp = requests.post(f"{BASE_URL}/staff/clock-in/{user_id}", headers=headers)
    print(f"Clock-in status: {resp.status_code}")
    print(f"Clock-in body: {resp.text}")
    
    # 4. Check status again
    resp = requests.get(f"{BASE_URL}/staff/users", headers=headers)
    users = resp.json()
    captain = next((u for u in users if u["username"] == "captain"), None)
    print(f"Is Clocked In after API: {captain.get('is_clocked_in')}")

if __name__ == "__main__":
    test_clock_in_api()
