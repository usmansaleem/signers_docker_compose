#!/usr/bin/env sh

set -o errexit

# See https://awscli.amazonaws.com/v2/documentation/api/latest/reference/kms/create-key.html
echo "Creating KMS keys ..."
# Create KMS keys

# Without tags
awslocal kms create-key --description "Web3Signer KMS key" \
 --key-spec ECC_SECG_P256K1 --key-usage SIGN_VERIFY \

awslocal kms create-key --description "Web3Signer KMS key" \
 --key-spec ECC_SECG_P256K1 --key-usage SIGN_VERIFY \

# To test TagKey=Org1
awslocal kms create-key --description "Web3Signer KMS key for Org1" \
 --key-spec ECC_SECG_P256K1 --key-usage SIGN_VERIFY \
 --tags TagKey="Org1",TagValue="US"

awslocal kms create-key --description "Web3Signer KMS key for Org1" \
 --key-spec ECC_SECG_P256K1 --key-usage SIGN_VERIFY \
 --tags TagKey="Org1",TagValue=

# To test TagKey=Org2
awslocal kms create-key --description "Web3Signer KMS key for Org2" \
 --key-spec ECC_SECG_P256K1 --key-usage SIGN_VERIFY \
 --tags TagKey="Org2",TagValue="AU"

awslocal kms create-key --description "Web3Signer KMS key for Org2" \
  --key-spec ECC_SECG_P256K1 --key-usage SIGN_VERIFY \
  --tags TagKey="Org2",TagValue=

# To Test TagValue = QA
awslocal kms create-key --description "Web3Signer KMS key for Section QA" \
  --key-spec ECC_SECG_P256K1 --key-usage SIGN_VERIFY \
  --tags TagKey="Section",TagValue="QA"

awslocal kms create-key --description "Web3Signer KMS key for Section QA" \
  --key-spec ECC_SECG_P256K1 --key-usage SIGN_VERIFY \
  --tags TagKey="Section",TagValue="QA"

echo "Listing existing keys ..."
awslocal kms list-keys