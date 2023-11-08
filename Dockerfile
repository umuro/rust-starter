FROM rust:1.73.0 as builder-dependencies

RUN rustup component add llvm-tools
ENV RUSTUPBIN=/usr/local/rustup/toolchains/1.68.0-x86_64-unknown-linux-gnu/lib/rustlib/x86_64-unknown-linux-gnu/bin
RUN cargo install cargo-binutils
RUN cargo install rustfilt
ENV RUSTFILT=/usr/local/cargo/bin/rustfilt
RUN apt update && apt-get install -y clang protobuf-compiler

WORKDIR /usr/src
RUN cargo new myapp
COPY Cargo.toml Cargo.lock /usr/src/myapp/
WORKDIR /usr/src/myapp
RUN cargo fetch

# LAYER builder
# This layer is for the use of the developer
FROM builder-dependencies as builder
ENV MYAPPNAME=my-app
ENV RUSTFLAGS="-C instrument-coverage"
ENV LLVM_PROFILE_FILE="local-coverage/my-app.profraw"
COPY . .

# Following layers make sure that there are no test failures and that the code compiles before the release
# LAYER checker
FROM builder as checker
RUN cargo check

# LAYER test
FROM checker as test
RUN cargo test

# LAYER dev-builder
FROM test as dev-builder
RUN cargo build

# # This layer is for deploying debugable version but I think it's not necessary.
# FROM debian:buster-slim as dev
# # RUN apt-get update && apt-get install -y extra-runtime-dependencies && rm -rf /var/lib/apt/lists/*
# RUN apt-get update && rm -rf /var/lib/apt/lists/*
# COPY --from=dev-builder /usr/src/myapp/target/debug/my-app /usr/local/bin/my-app
# CMD ["my-app"]

# LAYER release-builder
FROM test as release-builder
# ARG VERSION
# ARG COMMIT_NUMBER
# ARG BUILD_DATE

# ENV VERSION=$VERSION
# ENV COMMIT_NUMBER=$COMMIT_NUMBER
# ENV BUILD_DATE=$BUILD_DATE

ARG BUILD_RUSTFLAGS
ENV RUSTFLAGS=$BUILD_RUSTFLAGS

RUN echo RUSTFLAGS=$RUSTFLAGS

RUN cargo build --release

# LAYER release
FROM debian:bullseye-slim as release
COPY --from=release-builder /usr/src/myapp/target/release/my-app /usr/local/bin/my-app
# Replace this with actual app startup
CMD ["bash"] 