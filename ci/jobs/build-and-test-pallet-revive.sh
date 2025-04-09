#!/bin/bash

set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

POLKAVM_CRATES_ROOT="$(pwd)/proxy-crates"
POLKDOT_SDK_COMMIT=2700dbf2dda8b7f593447c939e1a26dacdb8ce45

LOG_FILE="output.log"
TARGET_DIR=target/run-pallet-revive-node
NODE_RUN_DURATION=100
NODE_BLOCKS_THRESHOLD=10

rustup toolchain install --component=rust-src nightly-2024-11-01-x86_64-unknown-linux-gnu

cd ../..

mkdir -p $TARGET_DIR
cd $TARGET_DIR

if [ ! -d "polkadot-sdk" ]; then
    git clone --depth 1 "https://github.com/paritytech/polkadot-sdk.git"
fi

cd polkadot-sdk
git fetch --depth=1 origin $POLKDOT_SDK_COMMIT
git checkout $POLKDOT_SDK_COMMIT

echo '[toolchain]' > rust-toolchain.toml
echo 'channel = "nightly-2024-11-01"' >> rust-toolchain.toml

PALLET_REVIVE_FIXTURES_RUSTUP_TOOLCHAIN=nightly-2024-11-01-x86_64-unknown-linux-gnu \
PALLET_REVIVE_FIXTURES_STRIP=0 \
PALLET_REVIVE_FIXTURES_OPTIMIZE=1 \
cargo build \
    --release -p staging-node-cli

echo "Running Node in background..."
PALLET_REVIVE_FIXTURES_RUSTUP_TOOLCHAIN=nightly-2024-11-01-x86_64-unknown-linux-gnu \
PALLET_REVIVE_FIXTURES_STRIP=0 \
PALLET_REVIVE_FIXTURES_OPTIMIZE=1 \
cargo run \
    --release -p staging-node-cli -- --dev --tmp > "$LOG_FILE" 2>&1 &

CARGO_PID=$!
sleep $NODE_RUN_DURATION

echo "Stopping the cargo process after $NODE_RUN_DURATION seconds..."
kill $CARGO_PID 2>/dev/null || true
wait $CARGO_PID 2>/dev/null || true

if ! grep -qi "Initializing Genesis block" "$LOG_FILE"; then
    echo "Node initialization failed. Please check logs at $LOG_FILE."
    exit 1
fi

GENERATED_BLOCK_COUNT=$(grep -ic "Pre-sealed block for proposal at" "$LOG_FILE" || true)

if [ $GENERATED_BLOCK_COUNT -lt $NODE_BLOCKS_THRESHOLD ]; then
    echo "Expected at least $NODE_BLOCKS_THRESHOLD blocks, but only generated $GENERATED_BLOCK_COUNT blocks."
    echo "Please check logs at '$TARGET_DIR/polkadot-sdk/$LOG_FILE'."
    exit 1
fi
