#!/bin/bash

# Directory containing keystore JSON files
KEYSTORE_DIR="${1:-./config/keystores}"

# API endpoint
ENDPOINT="http://127.0.0.1:9000/eth/v1/keystores"

# Password for all keystores
PASSWORD="password"

# Check if directory exists
if [ ! -d "$KEYSTORE_DIR" ]; then
    echo "Error: Directory '$KEYSTORE_DIR' does not exist"
    exit 1
fi

# Find all .json files in the directory
json_files=("$KEYSTORE_DIR"/*.json)

# Check if any JSON files exist
if [ ! -e "${json_files[0]}" ]; then
    echo "Error: No .json files found in '$KEYSTORE_DIR'"
    exit 1
fi

# Initialize arrays for keystores and passwords
keystores_array="["
passwords_array="["

first=true

# Read each JSON file and build the arrays
for file in "${json_files[@]}"; do
    if [ -f "$file" ]; then
        echo "Processing: $file"

        # Read the file content and escape it properly for JSON
        content=$(cat "$file" | jq -c .)

        # Add comma separator for all but the first item
        if [ "$first" = true ]; then
            first=false
        else
            keystores_array+=","
            passwords_array+=","
        fi

        # Add the keystore content as an escaped JSON string
        keystores_array+=$(printf '%s' "$content" | jq -R .)
        passwords_array+="\"$PASSWORD\""
    fi
done

keystores_array+="]"
passwords_array+="]"

# Build the final JSON payload
payload=$(jq -n \
    --argjson keystores "$keystores_array" \
    --argjson passwords "$passwords_array" \
    '{keystores: $keystores, passwords: $passwords}')

echo "Sending request to $ENDPOINT..."
echo "Payload:"
echo "$payload" | jq .

# Send the POST request
response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$ENDPOINT" \
    --header "Content-Type: application/json" \
    --data "$payload")

# Extract response body and status
http_body=$(echo "$response" | sed -e 's/HTTP_STATUS\:.*//g')
http_status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')

echo ""
echo "HTTP Status: $http_status"
echo "Response:"
echo "$http_body" | jq . 2>/dev/null || echo "$http_body"

# Exit with appropriate code
if [ "$http_status" -ge 200 ] && [ "$http_status" -lt 300 ]; then
    echo ""
    echo "✓ Keystores imported successfully"
    exit 0
else
    echo ""
    echo "✗ Failed to import keystores"
    exit 1
fi