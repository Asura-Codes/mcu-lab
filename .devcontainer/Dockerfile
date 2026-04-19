FROM ubuntu:24.04


# This Dockerfile sets up a development environment for ESP-IDF, STM32, Raspberry Pi Pico development and Arduino IDE support.
# It is based on the official Ubuntu image and includes all necessary tools and SDKs for embedded development.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Use bash as the default shell for RUN steps early in the build. This
# avoids BuildKit attempting to exec /bin/sh if the environment changes
# during multi-stage operations.
SHELL ["/bin/bash","-lc"]


# Switch to root for installations
USER root


# Install necessary packages for development and toolchain support
# This includes compilers, build tools, and libraries required for ESP-IDF, STM32, and Raspberry Pi Pico development.
# We also install git and git-lfs for version control and handling large files in repositories.
RUN : \
  && apt-get update \
  && apt-get install -y \
  apt-utils \
  bash \
  bison \
  bzip2 \
  ca-certificates \
  ccache \
  check \
  curl \
  flex \
  git \
  git-lfs \
  gperf \
  lcov \
  libbsd-dev \
  libffi-dev \
  libglib2.0-0 \
  libncurses-dev \
  # libpixman-1-0 \
  # libsdl2-2.0-0 \
  # libslirp0 \
  libusb-1.0-0-dev \
  pkg-config \
  libudev-dev \
  make \
  ninja-build \
  python3 \
  python3-venv \
  python3-pip \
  ruby \
  unzip \
  wget \
  xz-utils \
  zip \
  gcc-arm-none-eabi \
  libnewlib-arm-none-eabi \
  libstdc++-arm-none-eabi-newlib \
  gdb-multiarch \
  cmake \
  sudo \
  build-essential \
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3 10 \
  && :


# Create or update non-root user (may already exist in base image)
RUN groupadd --gid ${USER_GID} ${USERNAME} 2>/dev/null || groupmod -n ${USERNAME} $(getent group ${USER_GID} | cut -d: -f1) 2>/dev/null || true \
  && useradd -m --uid ${USER_UID} --gid ${USER_GID} -s /bin/bash ${USERNAME} 2>/dev/null || usermod -l ${USERNAME} -d /home/${USERNAME} -m $(getent passwd ${USER_UID} | cut -d: -f1) 2>/dev/null || true \
  && mkdir -p /home/${USERNAME} \
  && chown -R ${USER_UID}:${USER_GID} /home/${USERNAME} \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
  && chmod 0440 /etc/sudoers.d/${USERNAME}


# Install Raspberry Pi Pico SDK (Pico 1 and Pico 2)
# Using SDK 2.2.0 for compatibility with latest tools and RP2350 support
ARG PICO_SDK_VERSION=2.2.0
# Pin picotool to the same version as the Pico SDK to avoid API mismatches
ARG PICOTOOL_VERSION=${PICO_SDK_VERSION}

RUN git clone --depth 1 --shallow-submodules -b ${PICO_SDK_VERSION} https://github.com/raspberrypi/pico-sdk.git /opt/pico-sdk \
  && cd /opt/pico-sdk \
  && git submodule update --init --recursive

# Install picotool for Pico development
# Must use cmake --install (not just copy binary) so pico-sdk find_package(picotool) works
RUN git clone --depth 1 --shallow-submodules -b ${PICOTOOL_VERSION} https://github.com/raspberrypi/picotool.git /tmp/picotool \
  && cd /tmp/picotool \
  && mkdir build && cd build \
  && cmake -DCMAKE_BUILD_TYPE=Release -DPICO_SDK_PATH=/opt/pico-sdk -DCMAKE_INSTALL_PREFIX=/usr/local .. \
  && make -j$(nproc) \
  && make install \
  && cd / \
  && rm -rf /tmp/picotool


# To build the image for a branch or a tag of IDF, pass --build-arg IDF_CLONE_BRANCH_OR_TAG=name.
# To build the image with a specific commit ID of IDF, pass --build-arg IDF_CHECKOUT_REF=commit-id.
# It is possible to combine both, e.g.:
#   IDF_CLONE_BRANCH_OR_TAG=release/v6.0
#   IDF_CHECKOUT_REF=<some commit on release/vX.Y branch>.
# Use IDF_CLONE_SHALLOW=1 to perform shallow clone (i.e. --depth=1 --shallow-submodules)
# Use IDF_CLONE_SHALLOW_DEPTH=X to define the depth if IDF_CLONE_SHALLOW is used (i.e. --depth=X)
# Use IDF_INSTALL_TARGETS to install tools only for selected chip targets (CSV)

ARG IDF_CLONE_URL=https://github.com/espressif/esp-idf.git
ARG IDF_CLONE_BRANCH_OR_TAG=release/v6.0
# ARG IDF_CHECKOUT_REF=
ARG IDF_CLONE_SHALLOW=1
ARG IDF_CLONE_SHALLOW_DEPTH=1
ARG IDF_INSTALL_TARGETS=esp32,esp32s2,esp32s3,esp32c3,esp32c6
ARG IDF_GITHUB_ASSETS=

ENV IDF_PATH=/opt/esp/idf
ENV IDF_TOOLS_PATH=/opt/esp
ENV IDF_GITHUB_ASSETS=${IDF_GITHUB_ASSETS}

RUN echo IDF_CHECKOUT_REF=$IDF_CHECKOUT_REF IDF_CLONE_BRANCH_OR_TAG=$IDF_CLONE_BRANCH_OR_TAG && \
  git clone --recursive \
  ${IDF_CLONE_SHALLOW:+--depth=${IDF_CLONE_SHALLOW_DEPTH} --shallow-submodules} \
  ${IDF_CLONE_BRANCH_OR_TAG:+-b $IDF_CLONE_BRANCH_OR_TAG} \
  $IDF_CLONE_URL $IDF_PATH && \
  git config --system --add safe.directory $IDF_PATH

# && \
# if [ -n "$IDF_CHECKOUT_REF" ]; then \
# cd $IDF_PATH && \
# if [ -n "$IDF_CLONE_SHALLOW" ]; then \
# git fetch origin --depth=${IDF_CLONE_SHALLOW_DEPTH} --recurse-submodules ${IDF_CHECKOUT_REF}; \
# fi && \
# git checkout $IDF_CHECKOUT_REF && \
# git submodule update --init --recursive; \
# fi


# Install all the required tools
RUN : \
  && update-ca-certificates --fresh \
  && $IDF_PATH/tools/idf_tools.py --non-interactive install required --targets=${IDF_INSTALL_TARGETS} \
  && $IDF_PATH/tools/idf_tools.py --non-interactive install-python-env \
  && rm -rf $IDF_TOOLS_PATH/dist \
  && :

# Symlink ESP toolchain binaries (gdb, nm, objdump) into /usr/bin/.
# The VS Code extension host is not a login shell and never sources export.sh,
# so these tools are invisible unless they appear on the default PATH.
# Cortex-Debug uses nm/objdump for symbol classification and gdb for debugging.
RUN find "${IDF_TOOLS_PATH}/tools" -type f \
  | grep -E -- '-(elf|eabi)-(gdb|nm|objdump)$' \
  | while IFS= read -r bin; do \
  ln -sf "$bin" "/usr/bin/$(basename "$bin")"; \
  done

# && $IDF_PATH/tools/idf_tools.py --non-interactive install cmake \
# QEMU allows developers to run code, test bootloader, or debug firmware without flashing a board.
# $IDF_PATH/tools/idf_tools.py --non-interactive install qemu-esp32,qemu-esp32s2,qemu-esp32s3,qemu-esp32c3,qemu-esp32c6

# Pin exact Arduino CLI version (1.4.x)
ARG ARDUINO_CLI_VERSION=1.4.1

# Arduino directories (no root pollution)
ENV ARDUINO_DIRECTORIES_DATA=/opt/arduino \
  ARDUINO_DIRECTORIES_DOWNLOADS=/opt/arduino/staging

# ---- Install Arduino CLI (pinned, no script) ----
# ---- Base system + user + Arduino CLI ----
# Install Arduino CLI 1.4.1 (pinned)
RUN mkdir -p /tmp/arduino-cli \
  && curl -fsSL https://downloads.arduino.cc/arduino-cli/arduino-cli_${ARDUINO_CLI_VERSION}_Linux_64bit.tar.gz \
  | tar -xz -C /tmp/arduino-cli \
  && mv /tmp/arduino-cli/arduino-cli /usr/local/bin/arduino-cli \
  && rm -rf /tmp/arduino-cli \
  \
  # Prepare directories
  && mkdir -p ${ARDUINO_DIRECTORIES_DATA} \
  && chown -R ${USER_UID}:${USER_GID} ${ARDUINO_DIRECTORIES_DATA} /home/${USERNAME} \
  \
  # Init + configure Arduino
  && arduino-cli config init \
  && arduino-cli config set board_manager.additional_urls \
  https://arduino.esp8266.com/stable/package_esp8266com_index.json

# ---- Core index + AVR (lightweight, cacheable) ----
RUN arduino-cli core update-index \
  && arduino-cli core install arduino:avr \
  && arduino-cli core install esp8266:esp8266

# ---- west (Zephyr meta-tool) ----
# For Ubuntu 24.04 in a container, --break-system-packages is safe.
RUN pip3 install --break-system-packages west cmake-format

# ---- Zephyr SDK (ARM toolchain for STM32 and nRF targets) ----
ARG ZEPHYR_SDK_VERSION=0.17.4

RUN ZEPHYR_SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64_minimal.tar.xz" \
  && wget -q "$ZEPHYR_SDK_URL" -O /tmp/zephyr-sdk.tar.xz \
  && tar -xf /tmp/zephyr-sdk.tar.xz -C /opt \
  && rm /tmp/zephyr-sdk.tar.xz \
  && /opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}/setup.sh -t arm-zephyr-eabi \
  && chown -R ${USER_UID}:${USER_GID} /opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}

ENV ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}

# Symlink Zephyr SDK toolchain binaries (gdb, nm, objdump) into /usr/bin
# so toolchain commands like arm-zephyr-eabi-gdb are on the default PATH.
RUN find "${ZEPHYR_SDK_INSTALL_DIR}" -type f \
  \( -name '*-gdb' -o -name '*-nm' -o -name '*-objdump' \) \
  | while IFS= read -r bin; do \
  ln -sf "$bin" "/usr/bin/$(basename "$bin")"; \
  done

# ---- Zephyr RTOS workspace (v4.2.2) ----
ARG ZEPHYR_VERSION=v4.2.2

RUN west init -m https://github.com/zephyrproject-rtos/zephyr \
  --mr ${ZEPHYR_VERSION} /opt/zephyrproject \
  && cd /opt/zephyrproject \
  && west update --narrow -o=--depth=1 \
  && pip3 install --break-system-packages \
  -r /opt/zephyrproject/zephyr/scripts/requirements-base.txt \
  && chown -R ${USER_UID}:${USER_GID} /opt/zephyrproject

ENV ZEPHYR_BASE=/opt/zephyrproject/zephyr

# Set proper permissions for Pico SDK
RUN chown -R ${USER_UID}:${USER_GID} /opt/pico-sdk

# Set proper permissions for Arduino directories
RUN chown -R ${USER_UID}:${USER_GID} /opt/arduino

# Set environment variables for Pico SDK
ENV PICO_SDK_PATH=/opt/pico-sdk

# Set environment variables for Arduino
ENV ARDUINO_CLI_PATH=/usr/local/bin/arduino-cli

# Set locale to fix ESP-IDF menuconfig and other locale-dependent tools
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8


# Add helpful aliases and tips to bashrc
# Use a heredoc so no shell-quoting gymnastics are needed inside the content.
RUN mkdir -p /home/${USERNAME} \
  && tee -a /home/${USERNAME}/.bashrc <<'BASHRC_EOF'

# Development Environment Aliases
alias get_idf=". $IDF_PATH/export.sh"
echo "🔧 Multi-Platform Embedded Environment Ready"
echo "  ESP32:       ESP-IDF v6.0     (run 'get_idf' to activate)"
echo "  ESP8266:     Arduino Core for ESP8266"
echo "  Arduino:     AVR Toolchain (Uno, Mega, etc.) $ARDUINO_CLI_PATH"
echo "  Pico:        SDK $PICO_SDK_PATH"
echo "  STM32/nRF52: Zephyr RTOS $ZEPHYR_BASE (SDK: $ZEPHYR_SDK_INSTALL_DIR)"
BASHRC_EOF

RUN chown ${USER_UID}:${USER_GID} /home/${USERNAME}/.bashrc



WORKDIR /workspace

USER ${USERNAME}
CMD [ "/bin/bash" ]
