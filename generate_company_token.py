#!/usr/bin/env python3
import jwt
import os
from datetime import datetime, timedelta

# Get JWT secret from environment (same as your functions use)
JWT_SECRET = os.environ.get('JWT_SECRET_KEY', '62f2785e5abdde713287eb15dbce7b5db6e09e68804e6ec512a4d45f465ad9a4195ff288b0534f41803a9df2e2d368587ccfbd84bc3acca9185d680171c96f9f')

def generate_company_token(user_id, company_name="", days_valid=365):
    """Generate a JWT token for a company"""
    
    # Token expires in 1 year (you can change this)
    expiration = datetime.utcnow() + timedelta(days=days_valid)
    
    payload = {
        'user_id': user_id,
        'type': 'access',
        'exp': int(expiration.timestamp()),
        'company': company_name
    }
    
    token = jwt.encode(payload, JWT_SECRET, algorithm='HS256')
    return token

if __name__ == "__main__":
    # The company user ID you mentioned
    company_user_id = "03dc9ce2-3e66-4302-a8bc-8f6bf8b3929a"
    company_name = "Kataloff"  # You can change this
    
    token = generate_company_token(company_user_id, company_name)
    
    print("=" * 60)
    print("COMPANY API ACCESS CREDENTIALS")
    print("=" * 60)
    print(f"Company User ID: {company_user_id}")
    print(f"Company Name: {company_name}")
    print(f"API URL: https://d5degr4sfnv9p7i065ga.kf69zffa.apigw.yandexcloud.net")
    print(f"JWT Token: {token}")
    print("=" * 60)
    print("\nThis token is valid for 1 year.")
    print("Give the API URL and JWT Token to your website developer."