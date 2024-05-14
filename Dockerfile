ARG BASE_IMAGE=ubuntu:20.04

FROM $BASE_IMAGE as builder
LABEL builder=true
SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse 
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# Necessary libraries for Rust execution
RUN apt-get update && \
    apt-get install --assume-yes make build-essential git clang curl libssl-dev llvm libudev-dev protobuf-compiler && \
    rm -rf /var/lib/apt/lists/*


# Install cargo and Rust
RUN set -o pipefail && curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Do this instead of ./scripts/init.sh for better docker caching
RUN rustup update nightly
RUN rustup update stable
RUN rustup target add wasm32-unknown-unknown --toolchain nightly
RUN rustup target add wasm32-unknown-unknown --toolchain stable

# build subtensor
RUN git clone --depth 1 https://github.com/opentensor/subtensor.git /subtensor
WORKDIR /subtensor
RUN cargo build --release --features pow-faucet


FROM $BASE_IMAGE AS subtensor

# alice ports
EXPOSE 30334
EXPOSE 9946
EXPOSE 9934

WORKDIR /subtensor/

COPY localnet.sh ./scripts/localnet.sh 
COPY --from=builder /subtensor/target/release/node-subtensor ./target/release/

# run subtensor
CMD ["bash", "./scripts/localnet.sh"]
