#!/bin/bash

# Polygon API Gateway Registration Script

EMAIL="tom@spacebarcreative.com"
PASSWORD="SpaceBar@2024!"  # Example password - change this to your desired password

echo "========================================="
echo "Polygon API Gateway Registration"
echo "========================================="
echo ""

# Step 1: Register with Polygon API Gateway
echo "Step 1: Registering with email: $EMAIL"
echo "----------------------------------------"

RESPONSE=$(curl -s -w "\n%{http_code}" --location 'https://api-gateway.polygon.technology/api/users/register' \
--header 'Content-Type: application/json' \
--data-raw "{
    \"email\": \"$EMAIL\",
    \"password\": \"$PASSWORD\"
}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "Response: $BODY"
echo "HTTP Status: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "✅ Registration successful!"
    echo ""
    echo "========================================="
    echo "IMPORTANT: Next Steps"
    echo "========================================="
    echo "1. Check your email (tom@spacebarcreative.com) for verification link"
    echo "2. The verification link will be from: no-reply@polygon.technology"
    echo "3. Link expires in 30 minutes!"
    echo "4. Click the link to verify and receive your API key"
    echo ""
    echo "After clicking the verification link, you can retrieve your API key using:"
    echo "./scripts/polygon-api-getkey.sh"
else
    echo "❌ Registration failed. Please check the error message above."
    echo ""
    echo "Common issues:"
    echo "- Email already registered"
    echo "- Password doesn't meet requirements (min 10 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char)"
fi