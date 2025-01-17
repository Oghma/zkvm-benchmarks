#!/bin/bash
set -e
echo "Running $1, $2, $3, $4, $5"

# Get program directory name as $1 and append "-$2" to it if $1 is "tendermint"
# or "reth"
if [ "$1" = "tendermint" ] || [ "$1" = "reth" ]; then
    program_directory="${1}-$2"
else
    program_directory="$1"
fi

echo "Building program"

# cd to program directory computed above
cd "benchmarks/$program_directory"

# If the prover is risc0, then build the program.
if [ "$2" == "risc0" ]; then
    echo "Building Risc0"
    # Use the risc0 toolchain.
    RUSTFLAGS="-C passes=loweratomic -C link-arg=-Ttext=0x00200800 -C panic=abort" \
        RUSTUP_TOOLCHAIN=risc0 \
        CARGO_BUILD_TARGET=riscv32im-risc0-zkvm-elf \
        cargo build --release --ignore-rust-version --features $2
fi

cd ../../

echo "Running eval script"

# Detect whether we're on an instance with a GPU.
if nvidia-smi > /dev/null 2>&1; then
  GPU_EXISTS=true
else
  GPU_EXISTS=false
fi

# Check for AVX-512 support
if lscpu | grep -q avx512; then
  # If AVX-512 is supported, add the specific features to RUSTFLAGS
  export RUSTFLAGS="-C target-cpu=native -C target-feature=+avx512ifma,+avx512vl"
else
  # If AVX-512 is not supported, just set target-cpu=native
  export RUSTFLAGS="-C target-cpu=native"
fi

# Set the logging level.
export RUST_LOG=info

# Determine the features based on GPU existence.
if [ "$GPU_EXISTS" = true ]; then
  FEATURES="$2, cuda"
else
  FEATURES="$2"
fi

# Run the benchmark.
cargo run \
    -p zkvm-benchmarks-eval \
    --release \
    --no-default-features \
    --features "$FEATURES" \
    -- \
    --program "$1" \
    --prover "$2" \
    --hashfn "$3" \
    --shard-size "$4" \
    --filename "$5" \
     ${6:+$([[ "$1" == "fibonacci" ]] && echo "--fibonacci-input" || echo "--block-number") $6}
