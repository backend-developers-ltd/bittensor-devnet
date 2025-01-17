ARG BASE_IMAGE=ubuntu:24.04

FROM $BASE_IMAGE AS builder
SHELL ["/bin/bash", "-exc"]

# Set noninteractive mode for apt-get
ARG DEBIAN_FRONTEND=noninteractive

# Set up Rust environment
ENV RUST_BACKTRACE=1
RUN apt-get update && \
  apt-get install -y curl build-essential protobuf-compiler clang git pkg-config libssl-dev && \
  rm -rf /var/lib/apt/lists/*

RUN set -o pipefail && curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup update stable
RUN rustup target add wasm32-unknown-unknown --toolchain stable

# Clone subtensor repository
ARG SUBTENSOR_REPO_REF=main
RUN git clone https://github.com/opentensor/subtensor.git /subtensor \
    --depth 1 \
    --branch "$SUBTENSOR_REPO_REF"
WORKDIR /subtensor

# Build the project
RUN cargo build -p node-subtensor --profile release --features="runtime-benchmarks metadata-hash pow-faucet" --locked

# Verify the binary was produced
RUN test -e /subtensor/target/release/node-subtensor



FROM $BASE_IMAGE AS subtensor

RUN apt-get update && apt-get install -y ca-certificates

# Expose rpc port of the alice node
EXPOSE 9944

# Copy final binary
COPY --from=builder /subtensor/target/release/node-subtensor /subtensor/target/release/node-subtensor

# Copy localnet script runner
COPY --from=builder /subtensor/scripts/localnet.sh /subtensor/scripts/localnet.sh

# Hack localnet.sh to allow external traffic
RUN sed -i 's/--alice/--alice --unsafe-rpc-external/' /subtensor/scripts/localnet.sh

# Set env values for localnet.sh
ENV BUILD_BINARY=0

# run subtensor
CMD ["bash", "/subtensor/scripts/localnet.sh", "--no-purge"]
