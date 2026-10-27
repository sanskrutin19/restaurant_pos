import requests
import json

BASE_URL = "http://127.0.0.1:8000"

def test_roles_endpoint():
    # 1. Login to get token
    login_data = {"username": "admin", "password": "admin123"}
    resp = requests.post(f"{BASE_URL}/auth/token", data=login_data)
    if resp.status_code != 200:
        print(f"Login failed: {resp.text}")
        return
    
    token = resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 2. Call roles endpoint
    resp = requests.get(f"{BASE_URL}/admin/roles", headers=headers)
    print(f"Roles status: {resp.status_code}")
    print(f"Roles body: {resp.text}")

if __name__ == "__main__":
    test_roles_endpoint()
