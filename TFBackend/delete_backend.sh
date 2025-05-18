#!/bin/bash

# ======= CONFIGURATION ========
REGION="us-east-1"
BUCKET_NAME="ttf-remote-backend-state-4286"
DYNAMO_TABLE="terraform-locks"
# ==============================

echo "🧹 Deleting all objects (including versions) in bucket: $BUCKET_NAME"
# Remove all object versions and delete markers (for versioned bucket)
VERSIONS=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" --output json)

# Delete versions
echo "$VERSIONS" | jq -c '.Versions[]?' | while read -r version; do
  KEY=$(echo "$version" | jq -r '.Key')
  VERSION_ID=$(echo "$version" | jq -r '.VersionId')
  echo "🗑️ Deleting object version: $KEY ($VERSION_ID)"
  aws s3api delete-object --bucket "$BUCKET_NAME" --key "$KEY" --version-id "$VERSION_ID" --region "$REGION"
done

# Delete delete markers
echo "$VERSIONS" | jq -c '.DeleteMarkers[]?' | while read -r marker; do
  KEY=$(echo "$marker" | jq -r '.Key')
  VERSION_ID=$(echo "$marker" | jq -r '.VersionId')
  echo "🗑️ Deleting delete marker: $KEY ($VERSION_ID)"
  aws s3api delete-object --bucket "$BUCKET_NAME" --key "$KEY" --version-id "$VERSION_ID" --region "$REGION"
done

# Delete the S3 bucket
echo "🚮 Deleting bucket: $BUCKET_NAME"
aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION"

# Delete the DynamoDB table
echo "🗑️ Deleting DynamoDB table: $DYNAMO_TABLE"
aws dynamodb delete-table --table-name "$DYNAMO_TABLE" --region "$REGION"

echo "✅ Cleanup complete!"
