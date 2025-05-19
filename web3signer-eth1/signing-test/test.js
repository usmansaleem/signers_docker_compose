const axios = require("axios");
const {
  computeAddress,
  keccak256,
  recoverAddress,
  Signature
} = require("ethers");

async function getFirstPublicKey() {
  const { data: publicKeys } = await axios.get("http://localhost:9000/api/v1/eth1/publicKeys");
  if (!publicKeys?.length) {
    throw new Error("No public keys found");
  }
  return publicKeys[0];
}

async function verifySignature() {
  const publicKey = await getFirstPublicKey();
  const expectedAddress = computeAddress(publicKey);

  // 1️⃣ Don’t hash here. Send the raw bytes to Web3Signer:
  const dataToSign = "0x3432";
  const signUrl   = `http://localhost:9000/api/v1/eth1/sign/${publicKey}`;

  let { data: sigHex } = await axios.post(signUrl, { data: dataToSign });
  sigHex = sigHex.trim().replace(/^0x?/, "0x");

  // 2️⃣ Parse r, s, v out of the 65-byte blob
  const signature = Signature.from(sigHex);

  // 3️⃣ Now hash the original payload for ECDSA recovery
  const digest    = keccak256(dataToSign);
  const recovered = recoverAddress(digest, signature);

  console.log({ expectedAddress, recovered });
  console.log("Valid?", recovered.toLowerCase() === expectedAddress.toLowerCase());
}

verifySignature().catch(console.error);
