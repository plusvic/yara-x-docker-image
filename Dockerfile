#
# STAGE 1: Build the YARA-X library using a temporary image.
#
FROM ubuntu:24.04 AS build-environment

# Install tools and dependencies.
RUN apt-get install -y \
  gcc \
  libmagic-dev \
  libssl-dev \
  wget

WORKDIR /home
COPY . .

# Install Rust
#
# This was taken with some minor modifications from:
# https://github.com/rust-lang/docker-rust/blob/efd052fcbfc328aaa162d4b97eae2fad4cee1cd3/Dockerfile-debian.template
#
ENV RUSTUP_HOME=/usr/local/rustup \
  CARGO_HOME=/usr/local/cargo \
  PATH=/usr/local/cargo/bin:$PATH \
  OPENSSL_INCLUDE_DIR=/usr/include/openssl \
  OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu \
  RUSTUP_VERSION=1.26.0 \
  RUST_VERSION=1.78.0 \
  CARGOC_VERSION=0.9.32

RUN set -eux; \
  url="https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/x86_64-unknown-linux-gnu/rustup-init"; \
  wget "$url"; \
  chmod +x rustup-init; \
  ./rustup-init -y --profile minimal --default-toolchain $RUST_VERSION; \
  rm rustup-init; \
  chmod -R a+w $RUSTUP_HOME $CARGO_HOME; \
  rustup --version;

RUN cargo install cargo-c@$CARGOC_VERSION

# Build YARA-X
ENV YRX_EXTRA_PROTOS_BASE_PATH=/home/vt-protos/protos
ENV YRX_EXTRA_PROTOS="analysis.proto filetypes.proto relationships.proto sandbox.proto sigma.proto submitter.proto titan.proto tools/net_analysis.proto tools/snort.proto tools/suricata.proto tools/tshark.proto vtnet.proto"

RUN cargo cinstall \
  --manifest-path yara-x/Cargo.toml \
  --package yara-x-capi \
  --features=magic-module \
  --prefix=/usr

RUN ls /usr/lib
RUN ls /usr/include
RUN ls /usr/lib/pkgconfig

#
# STAGE 2: Copy the library binaries and header files to the final image.
#
FROM ubuntu:24.04

RUN apt-get update && apt-get upgrade -y
RUN rm -rf /var/lib/apt/lists/*

COPY --from=build-environment /usr/include/yara_x.h /usr/include
COPY --from=build-environment /usr/lib/libyara_x_capi.* /usr/lib
COPY --from=build-environment /usr/lib/pkgconfig/yara_x_capi.pc /usr/lib/pkgconfig
