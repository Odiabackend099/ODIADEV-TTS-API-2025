#!/usr/bin/env python3
import sys
import requests
import time

def health_check():
    try:
        response = requests.get("http://localhost:3000/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            if data.get("status") == "ok":
                print("Health check passed")
                return 0
        print("Health check failed")
        return 1
    except Exception as e:
        print(f"Health check error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(health_check())