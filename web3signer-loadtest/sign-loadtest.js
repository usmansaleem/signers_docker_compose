import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    vus: 10, // Number of concurrent virtual users
    duration: '30s', // Test duration
};

export function setup() {
    // Fetch public keys before the test starts
    let res = http.get('http://localhost:9000/api/v1/eth2/publicKeys');
    let pubkeys = res.json();
    if (!Array.isArray(pubkeys) || pubkeys.length === 0) {
        throw new Error('No public keys found!');
    }
    return { pubkeys };
}

export default function (data) {
    // Pick a random public key for each iteration
    const pubkeys = data.pubkeys;
    const pubkey = pubkeys[Math.floor(Math.random() * pubkeys.length)];

    // Prepare the payload (customize slot as needed)
    const payload = JSON.stringify({
        type: "block",
        fork_info: {
            fork: {
                previous_version: "0x00000001",
                current_version: "0x00000001",
                epoch: "0"
            },
            genesis_validators_root: "0x270d43e74ce340de4bca2b1936beca0f4f5408d9e78aec4850920baf659d5b69"
        },
        block: {
            slot: "12345",
            proposer_index: "5",
            parent_root: "0xb2eedb01adbd02c828d5eec09b4c70cbba12ffffba525ebf48aca33028e8ad89",
            state_root: "0x2b530d6262576277f1cc0dbe341fd919f9f8c5c92fc9140dff6db4ef34edea0d",
            body: {
                randao_reveal: "0xa686652aed2617da83adebb8a0eceea24bb0d2ccec9cd691a902087f90db16aa5c7b03172a35e874e07e3b60c5b2435c0586b72b08dfe5aee0ed6e5a2922b956aa88ad0235b36dfaa4d2255dfeb7bed60578d982061a72c7549becab19b3c12f",
                eth1_data: {
                    deposit_root: "0x6a0f9d6cb0868daa22c365563bb113b05f7568ef9ee65fdfeb49a319eaf708cf",
                    deposit_count: "8",
                    block_hash: "0x4242424242424242424242424242424242424242424242424242424242424242"
                },
                graffiti: "0x74656b752f76302e31322e31302d6465762d6338316361363235000000000000",
                proposer_slashings: [],
                attester_slashings: [],
                attestations: [],
                deposits: [],
                voluntary_exits: []
            }
        }
    });

    // Send the sign request
    let res = http.post(`http://localhost:9000/api/v1/eth2/sign/${pubkey}`, payload, {
        headers: { 'Content-Type': 'application/json' },
    });

    check(res, {
        'status is 200': (r) => r.status === 200,
    });

    sleep(0.1); // Adjust sleep for desired request rate
}
