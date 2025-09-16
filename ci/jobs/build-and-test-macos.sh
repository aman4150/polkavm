#!/bin/bash

set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
cd ../..

rustup target add x86_64-apple-darwin

# echo ">> cargo run (examples, interpreter, x86_64-apple-darwin)"
# POLKAVM_TRACE_EXECUTION=1 POLKAVM_ALLOW_INSECURE=1 POLKAVM_BACKEND=interpreter cargo run --target=x86_64-apple-darwin -p hello-world-host

# echo ">> cargo run (examples, compiler, generic, x86_64-apple-darwin)"
# POLKAVM_TRACE_EXECUTION=1 POLKAVM_ALLOW_INSECURE=1 POLKAVM_BACKEND=compiler POLKAVM_SANDBOX=generic cargo run --target=x86_64-apple-darwin -p hello-world-host

# echo ">> cargo run (examples, interpreter, aarch64-apple-darwin)"
# POLKAVM_TRACE_EXECUTION=1 POLKAVM_ALLOW_INSECURE=1 POLKAVM_BACKEND=interpreter cargo run --target=aarch64-apple-darwin -p hello-world-host

echo ">> cargo test (generic-sandbox)"
RUST_LOG=trace cargo test --features generic-sandbox -p polkavm --target=x86_64-apple-darwin -- \
    tests::compiler_generic_dynamic_jump_to_null --nocapture
    # tests::compiler_generic_ \
    # --skip tests::compiler_generic_dynamic_jump_to_null \
    # --skip tests::compiler_generic_jump_indirect_simple \
    # --test-threads 1

    # 466 out of 639 tests passed
    # tests::compiler_generic_riscv_ \
    # tests::compiler_generic_optimized_ \
    # 4 passed 19 failed
    # tests::compiler_generic_dynamic_paging \

# 639 - 360 - 106 =