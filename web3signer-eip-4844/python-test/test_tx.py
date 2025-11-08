#!/usr/bin/env python3
"""
Simple Ethereum transaction test using web3.py
Sends a transaction using eth_sendTransaction RPC call
"""

from web3 import Web3

# Configuration
RPC_HOST = "localhost"
RPC_PORT = 9000
FROM_ACCOUNT = "0xafF0CA253b97e54440965855cec0A8a2E2399896"

def test_send_transaction():
    # Connect to the local Ethereum node
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

    # Prepare transaction
    # Sending a small amount to self as a test
    tx = {
        'from': from_address,
        'to': from_address,  # Sending to self
        'value': web3.to_wei(0.001, 'ether'),  # Small test amount
        'gas': 21000,
        'gasPrice': web3.eth.gas_price
    }

    print(f"\n[INFO] Sending transaction...")
    print(f"   From: {tx['from']}")
    print(f"   To: {tx['to']}")
    print(f"   Value: {web3.from_wei(tx['value'], 'ether')} ETH")
    print(f"   Gas: {tx['gas']}")
    print(f"   Gas Price: {web3.from_wei(tx['gasPrice'], 'gwei')} Gwei")

    try:
        # Send transaction using eth_sendTransaction
        # Note: This requires the account to be unlocked on the node
        tx_hash = web3.eth.send_transaction(tx)
        print(f"\n[SUCCESS] Transaction sent!")
        print(f"   Tx Hash: {tx_hash.hex()}")

        # Wait for transaction receipt
        print(f"\n[INFO] Waiting for transaction to be mined...")
        receipt = web3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)

        print(f"\n[SUCCESS] Transaction mined!")
        print(f"   Block number: {receipt['blockNumber']}")
        print(f"   Gas used: {receipt['gasUsed']}")
        print(f"   Status: {'Success' if receipt['status'] == 1 else 'Failed'}")

        return True

    except Exception as e:
        print(f"\n[ERROR] Error sending transaction: {e}")
        print(f"\n[NOTE] Make sure:")
        print(f"   1. The account {FROM_ACCOUNT} is unlocked on the node")
        print(f"   2. The account has sufficient balance")
        print(f"   3. The node is running in dev/test mode with unlocked accounts")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("Ethereum Transaction Test")
    print("=" * 60)
    success = test_send_transaction()
    print("\n" + "=" * 60)
    if success:
        print("[SUCCESS] Test completed successfully")
    else:
        print("[FAILED] Test failed")
    print("=" * 60)