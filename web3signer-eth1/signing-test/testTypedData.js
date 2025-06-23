// testTypedData.js
// Call eth_signTypedData on Web3Signer
// Verify using ethers verifyTypedData

const axios = require("axios");
const { verifyTypedData } = require("ethers");

// JSON-RPC client
const rpc = axios.create({
  baseURL: "http://localhost:9000",
  headers: { "Content-Type": "application/json" }
});

async function jsonRpc(method, params = []) {
  const payload = { jsonrpc: "2.0", method, params, id: 1 };
  console.log("RPC → Web3Signer:", JSON.stringify(payload, null, 2));

  const { data } = await rpc.post("/", {
    jsonrpc: "2.0",
    method,
    params,
    id: 1
  });
  if (data.error) {
    console.error("RPC error:", data.error);
    throw new Error(data.error.message);
  }
  return data.result;
}

// EIP-712 domain parameters
const domain = {
  name: "Ether Mail",
  version: "1",
  chainId: 1,
  verifyingContract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
};

// your custom types (omit EIP712Domain here)
const customTypes = {
  Person: [
    { name: "name",   type: "string"  },
    { name: "wallet", type: "address" }
  ],
  Mail: [
    { name: "from",     type: "Person" },
    { name: "to",       type: "Person" },
    { name: "contents", type: "string" }
  ]
};

// the actual message to sign
const message = {
  from: {
    name: "Cow",
    wallet: "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
  },
  to: {
    name: "Bob",
    wallet: "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
  },
  contents: "Hello, Bob!"
};

async function main() {
  // 1. grab your signer address
  const [account] = await jsonRpc("eth_accounts");

  // 2. pack the full typedData object the way Web3Signer expects
  const typedData = {
    domain,
    types: {
      // include the domain definition here, as per JSON-RPC schema
      EIP712Domain: [
        { name: "name",    type: "string"  },
        { name: "version", type: "string"  },
        { name: "chainId", type: "uint256" },
        { name: "verifyingContract", type: "address" }
      ],
      ...customTypes
    },
    primaryType: "Mail",
    message
  };

  // 3. ask Web3Signer to sign it
  const signature = await jsonRpc("eth_signTypedData", [
    account,
    typedData
  ]);
  console.log("Signature:", signature);

  // 4. recover & verify
  //    ethers.verifyTypedData pulls domain fields out of `domain`
  //    and only needs your customTypes here
  const recovered = verifyTypedData(
    domain,
    customTypes,
    message,
    signature
  );

  console.log({
    expected: account,
    recovered,
    valid: account.toLowerCase() === recovered.toLowerCase()
  });
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
