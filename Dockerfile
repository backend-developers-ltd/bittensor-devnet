ARG BASE_IMAGE=ubuntu:20.04

FROM $BASE_IMAGE as builder
LABEL builder=true
SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse 
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# Necessary libraries for Rust execution
RUN apt-get update && \
    apt-get install -y curl build-essential protobuf-compiler clang git && \
    rm -rf /var/lib/apt/lists/*

# Install cargo and Rust
RUN set -o pipefail && curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Do this instead of ./scripts/init.sh for better docker caching
RUN rustup update nightly-2023-03-01
RUN rustup target add wasm32-unknown-unknown --toolchain nightly-2023-03-01

# build subtensor
RUN git clone --depth 1 --branch main https://github.com/opentensor/subtensor.git /subtensor
WORKDIR /subtensor
RUN cargo build --release --features pow-faucet


FROM $BASE_IMAGE AS subtensor

# alice ports
EXPOSE 30334
EXPOSE 9946
EXPOSE 9934

WORKDIR /subtensor/

# install bittensor
RUN apt-get update && \
    apt-get install -y python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*
ENV PATH=/root/.local/bin:$PATH
RUN pip3 install --no-cache-dir -U pip
RUN pip3 install --user --no-cache-dir bittensor==6.7.2

COPY --from=builder /subtensor/target/release/node-subtensor ./target/release/
# COPY --from=builder /subtensor/scripts ./scripts
COPY localnet.sh ./scripts/localnet.sh 

# Enable non-local ws client interfaces
#RUN sed -i -e 's/--discover-local/--discover-local --unsafe-ws-external/' ./scripts/localnet.sh

# Disable purging the chain
#RUN sed -i -e '/purge-chain/d' ./scripts/localnet.sh

# run subtensor
CMD ["env", "BUILD_BINARY=0", "bash", "./scripts/localnet.sh"]
