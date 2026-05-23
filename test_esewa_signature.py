#!/usr/bin/env python3
"""
Test script to verify eSewa signature generation
Run this to verify your signature matches eSewa's expectations
"""

import hmac
import hashlib
import base64

# eSewa test configuration
SECRET_KEY = "8gBm/:&EnhH.1/q"
PRODUCT_CODE = "EPAYTEST"

def generate_signature(total_amount, transaction_uuid, product_code):
    """Generate HMAC-SHA256 signature for eSewa"""
    message = f"total_amount={total_amount},transaction_uuid={transaction_uuid},product_code={product_code}"
    print(f"Message: {message}")
    
    signature = base64.b64encode(
        hmac.new(
            SECRET_KEY.encode('utf-8'),
            message.encode('utf-8'),
            hashlib.sha256
        ).digest()
    ).decode('utf-8')
    
    return signature

# Test cases
test_cases = [
    {
        "total_amount": "499.00",
        "transaction_uuid": "SUB-1777487565166-9597",
        "product_code": "EPAYTEST"
    },
    {
        "total_amount": "100.00",
        "transaction_uuid": "TEST-123456",
        "product_code": "EPAYTEST"
    },
]

print("=" * 60)
print("eSewa Signature Generation Test")
print("=" * 60)
print()

for i, test in enumerate(test_cases, 1):
    print(f"Test Case {i}:")
    print(f"  Total Amount: {test['total_amount']}")
    print(f"  Transaction UUID: {test['transaction_uuid']}")
    print(f"  Product Code: {test['product_code']}")
    print()
    
    signature = generate_signature(
        test['total_amount'],
        test['transaction_uuid'],
        test['product_code']
    )
    
    print(f"  Signature: {signature}")
    print()
    print("-" * 60)
    print()

# Verify with your actual values
print("To verify your actual payment:")
print("1. Get the total_amount, transaction_uuid from your Flutter logs")
print("2. Run: python3 test_esewa_signature.py")
print("3. Compare the signature with what's in your logs")
print()
print("Expected log format:")
print("  🔐 Signature message: total_amount=X,transaction_uuid=Y,product_code=Z")
print("  🔐 Generated signature: [base64 string]")
