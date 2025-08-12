#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# The absolute or relative path to your service account's JSON key
SERVICE_ACCOUNT_KEY_PATH=./google-credentials-pubsub.json
echo "$GOOGLE_CREDENTIALS_BASE64_JSON" | base64 --decode > "$SERVICE_ACCOUNT_KEY_PATH"
echo Generated "$SERVICE_ACCOUNT_KEY_PATH"

# --- Configuration ---
# The package name of your app
PACKAGE_NAME="com.sjsoft.alarm_flutter"


# The path to your listings JSON file
LISTINGS_FILE_PATH="./playstore/listings.json"


# --- Script Body ---

echo "Authenticating with Google..."

# 1. Activate the service account
gcloud auth activate-service-account --key-file="$SERVICE_ACCOUNT_KEY_PATH"

# 2. Get a short-lived access token
ACCESS_TOKEN=$(gcloud auth print-access-token)

echo "Starting a new edit on the Play Store..."

# 3. Start a new edit request to get an editId
EDIT_ID=$(curl -s -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE_NAME/edits" \
  | jq -r .id)

if [ -z "$EDIT_ID" ] || [ "$EDIT_ID" == "null" ]; then
  echo "Failed to start a new edit. Check your credentials and permissions."
  exit 1
fi

echo "Successfully started edit with ID: $EDIT_ID"
echo "--------------------------------------------------"

# 4. Loop through each language in the JSON file and update the listing
for lang in $(jq -r 'keys[]' "$LISTINGS_FILE_PATH"); do
  echo "Updating language: $lang"

  # Extract descriptions using jq
  SHORT_DESC=$(jq -r --arg lang "$lang" '.[$lang].short_description' "$LISTINGS_FILE_PATH")
  FULL_DESC=$(jq -r --arg lang "$lang" '.[$lang].full_description' "$LISTINGS_FILE_PATH")

  # Construct the JSON payload for the API
  JSON_PAYLOAD=$(jq -n --arg short "$SHORT_DESC" --arg full "$FULL_DESC" \
    '{shortDescription: $short, fullDescription: $full}')

  # 5. Send the PUT request to update the listing for the language
  curl -s -X PUT \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE_NAME/edits/$EDIT_ID/listings/$lang"

  echo " -> Successfully uploaded listing for $lang"
done

echo "--------------------------------------------------"
echo "All languages updated. Committing changes..."

# 6. Commit the edit to make all changes live
curl -s -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE_NAME/edits/$EDIT_ID:commit"

echo "✅ Done. Your new store listings are now live on Google Play!"