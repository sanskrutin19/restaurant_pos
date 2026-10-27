
import requests
import sys

try:
    response = requests.get("http://127.0.0.1:8000/")
    print(f"Status: {response.status_code}")
    print(f"JSON: {response.json()}")
except Exception as e:
    print(f"Error: {e}")
