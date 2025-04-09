#!/bin/bash

set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

POLKAVM_CRATES_ROOT="$(pwd)/proxy-crates"
POLKDOT_SDK_COMMIT=e9393a9afc3b33cc2d01b7820a8f186434196758

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
SUBSTRATE_RUNTIME_TARGET=riscv \
SUBSTRATE_ENABLE_POLKAVM=1 \
cargo build \
    --config "patch.crates-io.polkavm013.path='$POLKAVM_CRATES_ROOT/polkavm013'" --config "patch.crates-io.polkavm013.package='polkavm'" \
    --config "patch.crates-io.polkavm-derive014.path='$POLKAVM_CRATES_ROOT/polkavm-derive014'" --config "patch.crates-io.polkavm-derive014.package='polkavm-derive'" \
    --config "patch.crates-io.polkavm-linker014.path='$POLKAVM_CRATES_ROOT/polkavm-linker014'" --config "patch.crates-io.polkavm-linker014.package='polkavm-linker'" \
    --release -p staging-node-cli

echo "Running Node in background..."
PALLET_REVIVE_FIXTURES_RUSTUP_TOOLCHAIN=nightly-2024-11-01-x86_64-unknown-linux-gnu \
PALLET_REVIVE_FIXTURES_STRIP=0 \
PALLET_REVIVE_FIXTURES_OPTIMIZE=1 \
SUBSTRATE_RUNTIME_TARGET=riscv \
SUBSTRATE_ENABLE_POLKAVM=1 \
cargo run \
    --config "patch.crates-io.polkavm013.path='$POLKAVM_CRATES_ROOT/polkavm013'" --config "patch.crates-io.polkavm013.package='polkavm'" \
    --config "patch.crates-io.polkavm-derive014.path='$POLKAVM_CRATES_ROOT/polkavm-derive014'" --config "patch.crates-io.polkavm-derive014.package='polkavm-derive'" \
    --config "patch.crates-io.polkavm-linker014.path='$POLKAVM_CRATES_ROOT/polkavm-linker014'" --config "patch.crates-io.polkavm-linker014.package='polkavm-linker'" \
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
