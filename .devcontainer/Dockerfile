# DevPod / Dev Container image for Quadruped-PyMPC
# Based on installation/docker/nvidia/dockerfile, but adapted for development:
#   - Source code is mounted from the host, not cloned into the image
#   - The conda/mamba environment and acados are built in setup.sh after the
#     workspace is mounted (so changes to the source on the host are immediately
#     reflected inside the container)
#   - A non-root `vscode` user is created so the workspace files keep host
#     ownership

FROM nvidia/cuda:12.4.0-devel-ubuntu22.04

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ENV DEBIAN_FRONTEND=noninteractive \
    CONDA_DIR=/opt/conda \
    PATH=/opt/conda/bin:$PATH

# System packages: build tools, git, GUI/X11 libs, the python-tk + gedit pair
# the upstream dockerfile installs, plus a few X11 client utilities that are
# helpful when debugging GUI forwarding (xeyes / glxinfo).
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ca-certificates \
        wget \
        bzip2 \
        curl \
        git \
        sudo \
        gedit \
        python3-pip \
        python3-tk \
        libglib2.0-0 \
        libxext6 \
        libsm6 \
        libxrender1 \
        libgl1 \
        libegl1 \
        libxkbcommon-x11-0 \
        libxcb-icccm4 \
        libxcb-image0 \
        libxcb-keysyms1 \
        libxcb-randr0 \
        libxcb-render-util0 \
        libxcb-shape0 \
        libxcb-sync1 \
        libxcb-xfixes0 \
        libxcb-xinerama0 \
        libxcb-xkb1 \
        libdbus-1-3 \
        x11-apps \
        mesa-utils \
    && rm -rf /var/lib/apt/lists/*

# Create the `vscode` user with passwordless sudo
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# Install Miniforge (which bundles mamba). Per
# https://mamba.readthedocs.io/en/latest/installation/mamba-installation.html
# Miniforge is the recommended way to install mamba. We additionally run
# `conda install mamba` to guarantee a working `mamba` binary even on older
# Miniforge releases that do not bundle it.
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p ${CONDA_DIR} \
    && rm /tmp/miniforge.sh \
    && ${CONDA_DIR}/bin/conda install -n base -c conda-forge -y mamba \
    && ${CONDA_DIR}/bin/conda clean -afy \
    && chown -R ${USERNAME}:${USERNAME} ${CONDA_DIR}

# Initialize conda + mamba for both root (so `sudo` shells work) and vscode
RUN ${CONDA_DIR}/bin/conda init bash \
    && ${CONDA_DIR}/bin/mamba init bash \
    && su - ${USERNAME} -c "${CONDA_DIR}/bin/conda init bash && ${CONDA_DIR}/bin/mamba init bash"

USER ${USERNAME}
WORKDIR /home/${USERNAME}
