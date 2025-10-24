#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <API_ENDPOINT_URL> <FOLDER_PATH> <SCHEMA_ID>"
    echo "Example: $0 https://<endpoint>/contentprocessor/submit ./invoices 3ed6060d-4e33-4e6a-b006-4a3dc088b919"
    exit 1
fi

# Assign arguments to variables
API_ENDPOINT_URL=$1
FOLDER_PATH=$2
SCHEMA_ID=$3

# Validate if the folder exists
if [ ! -d "$FOLDER_PATH" ]; then
    echo "Error: Folder '$FOLDER_PATH' does not exist."
    exit 1
fi

# Normalize endpoint: remove any trailing slash (FastAPI route is '/contentprocessor/submit' WITHOUT trailing slash)
API_ENDPOINT_URL="${API_ENDPOINT_URL%/}"

# Check for jq dependency
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: 'jq' is required but not installed."
    exit 1
fi

# Iterate over all files in the folder (non-hidden only)
shopt -s nullglob
for FILE in "$FOLDER_PATH"/*; do
    # Skip if no files are found
    if [ ! -f "$FILE" ]; then
        echo "No files found in the folder '$FOLDER_PATH'."
        continue
    fi

    # Extract the filename
    FILENAME=$(basename "$FILE")

    # Create the JSON payload for the data field (allow override of Metadata_Id via env)
    METADATA_ID_VALUE=${METADATA_ID:-Meta 001}
    DATA_JSON=$(jq -n --arg Metadata_Id "$METADATA_ID_VALUE" --arg Schema_Id "$SCHEMA_ID" \
        '{Metadata_Id: $Metadata_Id, Schema_Id: $Schema_Id}')

    # Invoke the API with multipart/form-data
    # Do NOT set multipart Content-Type header manually; curl sets boundary automatically
    echo "Submitting '$FILENAME' to $API_ENDPOINT_URL" >&2
    RESPONSE=$(curl -s -S -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_ENDPOINT_URL" \
        -F "file=@$FILE;filename=$FILENAME" \
        -F "data=$DATA_JSON;type=application/json")

    # Extract HTTP status code
    HTTP_STATUS=$(echo "$RESPONSE" | sed -n 's/.*HTTP_STATUS://p')
    RESPONSE_BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:.*//')

    # Print the API response
    if [ "$HTTP_STATUS" -eq 202 ]; then
        echo "Uploaded '$FILENAME' successfully."
        echo "API Response: $RESPONSE_BODY"
    else
        echo "Failed to upload '$FILENAME'. HTTP Status: $HTTP_STATUS"
        echo "Error Response: $RESPONSE_BODY"
    fi
done
