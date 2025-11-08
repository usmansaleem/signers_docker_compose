#!/usr/bin/env python3
"""
EIP-4844 Blob Transaction Test using eth_sendTransaction
Tests Web3Signer's support for EIP-4844 blob transactions

This uses eth_sendTransaction (not eth_sendRawTransaction), which means
Web3Signer handles the signing automatically.
"""

from web3 import Web3

# Configuration
RPC_HOST = "localhost"
RPC_PORT = 9000
FROM_ACCOUNT = "0xafF0CA253b97e54440965855cec0A8a2E2399896"

# Blob configuration
BYTES_PER_FIELD_ELEMENT = 32
FIELD_ELEMENTS_PER_BLOB = 4096
BLOB_SIZE = BYTES_PER_FIELD_ELEMENT * FIELD_ELEMENTS_PER_BLOB  # 131,072 bytes


def create_blob_data(message: str) -> bytes:
    """
    Create properly formatted blob data.
    Each blob must be exactly 131,072 bytes (4096 field elements * 32 bytes).
    """
    # Convert message to bytes
    message_bytes = message.encode('utf-8')

    if len(message_bytes) > BLOB_SIZE:
        raise ValueError(f"Message too large. Max size: {BLOB_SIZE} bytes")

    # Pad with zeros to reach exact blob size
    blob = message_bytes + b'\x00' * (BLOB_SIZE - len(message_bytes))

    return blob


def create_blob_versioned_hash(blob_data: bytes) -> bytes:
    """
    Create a versioned hash for the blob.
    For testing, we'll create a simple hash. In production, this would be
    the KZG commitment hash with version prefix.
    """
    from eth_utils import keccak

    # Hash the blob data
    blob_hash = keccak(blob_data)

    # Add version byte 0x01 for EIP-4844
    versioned_hash = b'\x01' + blob_hash[1:]

    return versioned_hash


def test_send_blob_transaction():
    # Connect to Web3Signer (which forwards to Besu)
    rpc_url = f"http://{RPC_HOST}:{RPC_PORT}"
    web3 = Web3(Web3.HTTPProvider(rpc_url))

    # Check connection
    if not web3.is_connected():
        print(f"[ERROR] Failed to connect to {rpc_url}")
        return False

    print(f"[INFO] Connected to Ethereum node at {rpc_url}")
    print(f"   Chain ID: {web3.eth.chain_id}")
    print(f"   Block number: {web3.eth.block_number}")

    # Check account balance
    from_address = web3.to_checksum_address(FROM_ACCOUNT)
    balance = web3.eth.get_balance(from_address)
    balance_eth = web3.from_wei(balance, 'ether')
    print(f"   Account balance: {balance_eth} ETH")

    if balance == 0:
        print("[WARNING] Account has zero balance")

    # Create blob data
    message = "Hello EIP-4844! This is a test blob transaction via Web3Signer."
    blob_data = create_blob_data(message)

    print(f"\n[INFO] Created blob data")
    print(f"   Size: {len(blob_data)} bytes")
    print(f"   Message: {message}")

    # Create blob versioned hash
    versioned_hash = create_blob_versioned_hash(blob_data)
    print(f"   Versioned hash: {versioned_hash.hex()}")

    # Get gas pricing
    latest_block = web3.eth.get_block('latest')
    base_fee = latest_block.get('baseFeePerGas', web3.eth.gas_price)

    # Prepare EIP-4844 transaction using eth_sendTransaction
    # Web3Signer will handle the signing
    tx = {
        'from': from_address,
        'to': from_address,  # Sending to self for testing
        'value': web3.to_wei(0.001, 'ether'),
        'gas': 21000,
        'maxFeePerGas': base_fee + web3.to_wei(2, 'gwei'),
        'maxPriorityFeePerGas': web3.to_wei(1, 'gwei'),
        # EIP-4844 specific fields
        'maxFeePerBlobGas': web3.to_wei(10, 'gwei'),
        'blobVersionedHashes': [versioned_hash.hex()],  # Web3Signer expects hex strings
        'blobs': [blob_data.hex()],  # Web3Signer expects hex string
    }

    print(f"\n[INFO] Sending EIP-4844 blob transaction...")
    print(f"   From: {tx['from']}")
    print(f"   To: {tx['to']}")
    print(f"   Value: {web3.from_wei(tx['value'], 'ether')} ETH")
    print(f"   Gas: {tx['gas']}")
    print(f"   Max Fee Per Gas: {web3.from_wei(tx['maxFeePerGas'], 'gwei')} Gwei")
    print(f"   Max Fee Per Blob Gas: {web3.from_wei(tx['maxFeePerBlobGas'], 'gwei')} Gwei")
    print(f"   Number of blobs: {len(tx['blobs'])}")
    print(f"   Number of blob hashes: {len(tx['blobVersionedHashes'])}")

    try:
        # Send transaction using eth_sendTransaction
        # Web3Signer will sign it and forward to Besu
        tx_hash = web3.eth.send_transaction(tx)
        print(f"\n[SUCCESS] Blob transaction sent!")
        print(f"   Tx Hash: {tx_hash.hex()}")

        # Wait for transaction receipt
        print(f"\n[INFO] Waiting for transaction to be mined...")
        receipt = web3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)

        print(f"\n[SUCCESS] Blob transaction mined!")
        print(f"   Block number: {receipt['blockNumber']}")
        print(f"   Gas used: {receipt['gasUsed']}")
        print(f"   Status: {'Success' if receipt['status'] == 1 else 'Failed'}")

        # Display EIP-4844 specific fields in receipt
        if 'blobGasUsed' in receipt:
            print(f"   Blob gas used: {receipt['blobGasUsed']}")

        if 'blobGasPrice' in receipt:
            blob_gas_price = web3.from_wei(receipt['blobGasPrice'], 'gwei')
            print(f"   Blob gas price: {blob_gas_price} Gwei")

        # Calculate total costs
        gas_cost = receipt['gasUsed'] * receipt['effectiveGasPrice']
        gas_cost_eth = web3.from_wei(gas_cost, 'ether')
        print(f"   Total gas cost: {gas_cost_eth} ETH")

        if 'blobGasUsed' in receipt and 'blobGasPrice' in receipt:
            blob_gas_cost = receipt['blobGasUsed'] * receipt['blobGasPrice']
            blob_gas_cost_eth = web3.from_wei(blob_gas_cost, 'ether')
            print(f"   Total blob gas cost: {blob_gas_cost_eth} ETH")

            total_cost = gas_cost + blob_gas_cost
            total_cost_eth = web3.from_wei(total_cost, 'ether')
            print(f"   Total transaction cost: {total_cost_eth} ETH")

        return True

    except Exception as e:
        print(f"\n[ERROR] Error sending blob transaction: {e}")
        print(f"\n[NOTE] Make sure:")
        print(f"   1. Web3Signer supports EIP-4844 (maxFeePerBlobGas, blobVersionedHashes, blobs)")
        print(f"   2. Web3Signer is configured to forward to Besu")
        print(f"   3. Besu supports EIP-4844 (Cancun upgrade enabled)")
        print(f"   4. Account {FROM_ACCOUNT} is loaded in Web3Signer")
        print(f"   5. Account has sufficient balance for gas + blob gas")

        import traceback
        print(f"\n[DEBUG] Full traceback:")
        traceback.print_exc()

        return False


if __name__ == "__main__":
    print("=" * 70)
    print("EIP-4844 Blob Transaction Test (via Web3Signer)")
    print("=" * 70)
    success = test_send_blob_transaction()
    print("\n" + "=" * 70)
    if success:
        print("[SUCCESS] Test completed successfully")
    else:
        print("[FAILED] Test failed")
    print("=" * 70)