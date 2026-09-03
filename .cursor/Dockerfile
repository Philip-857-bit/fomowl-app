# Cloud Agent development image for the Owllet (fomowl_wallet) Flutter + Rust app.
#
# Provides the toolchains the CI pipelines rely on:
#   - Flutter 3.44.6 (stable)  -> matches .github/workflows/dart.yml & flutter_build.yml
#   - Rust (latest stable)     -> matches dtolnay/rust-toolchain@stable (needs edition2024)
#   - JDK 17                   -> matches actions/setup-java (zulu 17)
#   - Android SDK 37 / build-tools 37 / NDK 28.2.13676358 -> matches android/app/build.gradle.kts
#
# Stable toolchains live here; repo-specific bootstrap (pub get, native lib build)
# runs in .cursor/install.sh so it can see the checked-out source.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# System packages: build tooling for Rust/flutter_rust_bridge + Flutter host deps.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git unzip zip xz-utils \
        build-essential clang cmake ninja-build pkg-config \
        libssl-dev python3 python3-pip \
        openjdk-17-jdk-headless \
        libglu1-mesa \
        sudo \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 24.04 ships a non-root "ubuntu" user (uid 1000). Give it passwordless sudo.
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# ---- Flutter (pinned to the SDK version shipped to users by CI) ----
ENV FLUTTER_HOME=/opt/flutter
ENV FLUTTER_VERSION=3.44.6
RUN curl -fsSL -o /tmp/flutter.tar.xz \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory "${FLUTTER_HOME}"

# ---- Rust (latest stable; a transitive dep requires the edition2024 feature) ----
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal \
    && /usr/local/cargo/bin/rustup target add \
        aarch64-linux-android armv7-linux-androideabi \
        x86_64-linux-android i686-linux-android \
    && /usr/local/cargo/bin/cargo install cargo-ndk \
    && chmod -R a+rwX /usr/local/rustup /usr/local/cargo

# ---- Android SDK / NDK (versions from android/app/build.gradle.kts) ----
ENV ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk
RUN mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" \
    && curl -fsSL -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdt \
    && mv /tmp/cmdt/cmdline-tools "${ANDROID_SDK_ROOT}/cmdline-tools/latest" \
    && rm -rf /tmp/cmdline-tools.zip /tmp/cmdt \
    && yes | "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null \
    && "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager" \
        "platform-tools" \
        "platforms;android-37.0" \
        "build-tools;37.0.0" \
        "ndk;28.2.13676358" >/dev/null \
    && chmod -R a+rwX "${ANDROID_SDK_ROOT}"

ENV PATH="${FLUTTER_HOME}/bin:${CARGO_HOME}/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${JAVA_HOME}/bin:${PATH}"

# Warm the Flutter tool caches and point Flutter at the Android SDK + JDK.
RUN git config --global --add safe.directory '*' \
    && flutter config --no-analytics >/dev/null 2>&1 || true \
    && flutter config --android-sdk "${ANDROID_SDK_ROOT}" --jdk-dir "${JAVA_HOME}" >/dev/null 2>&1 || true \
    && flutter precache --android >/dev/null 2>&1 || true

USER ubuntu
