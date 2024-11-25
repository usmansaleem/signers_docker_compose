# syntax=docker/dockerfile:1

# Define the build target version as a build argument
ARG BUILD_TARGET=master

# Build Stage - Build Web3Signer and JRE distribution
FROM gradle:8-jdk21 AS build

# Use the build argument
ARG BUILD_TARGET

# Update CA certificates
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

# Checkout Web3Signer with submodules and build distribution without tests
RUN git clone --recurse-submodules -j8 https://github.com/Consensys/web3signer.git --branch ${BUILD_TARGET} --single-branch && \
    cd web3signer && \
    ./gradlew --no-daemon distTar

# Create a custom Java runtime
RUN JAVA_TOOL_OPTIONS="-Djdk.lang.Process.launchMechanism=vfork" $JAVA_HOME/bin/jlink \
         --add-modules ALL-MODULE-PATH \
         --strip-debug \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output /javaruntime

# Main stage
FROM ubuntu:latest
ENV JAVA_HOME "/opt/java/openjdk"
ENV PATH "${JAVA_HOME}/bin:${PATH}"

# Copy the custom Java runtime that will be used by Web3Signer
COPY --from=build /javaruntime $JAVA_HOME

# Install required packages and update CA certificates
RUN apt-get -y update && apt-get -y install ca-certificates && update-ca-certificates && apt-get -y install adduser libc-bin libc6 curl iputils-ping net-tools tar && rm -rf /var/lib/apt/lists/*
# Add Web3Signer user and set permissions
RUN adduser --disabled-password --gecos "" --home /opt/web3signer web3signer && \
    chown web3signer:web3signer /opt/web3signer && chmod 755 /opt/web3signer

# Use the build argument
ARG BUILD_TARGET

# Copy and extract the tar file
COPY --from=build /home/gradle/web3signer/build/distributions/web3signer-*.tar.gz /opt/web3signer/
RUN tar -xzf /opt/web3signer/web3signer-*.tar.gz -C /opt/web3signer && \
    mv /opt/web3signer/web3signer-*/* /opt/web3signer/ && \
    rm -rf /opt/web3signer/web3signer-* /opt/web3signer/web3signer-*.tar.gz

# Set environment variables
ENV WEB3SIGNER_HTTP_LISTEN_HOST "0.0.0.0"
ENV WEB3SIGNER_METRICS_HOST "0.0.0.0"

# List Exposed Ports
# Metrics, Rest API
EXPOSE 9001 9000 9000/udp

# Change ownership of /opt/web3signer recursively
RUN chown -R web3signer:web3signer /opt/web3signer

# Set the working directory
WORKDIR /opt/web3signer

# Set the user
USER web3signer

# Command to run Web3Signer
ENTRYPOINT ["./bin/web3signer"]