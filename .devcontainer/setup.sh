#!/usr/bin/env bash
# Post-create setup for the Quadruped-PyMPC DevPod / Dev Container.
#
# DevPod runs this once after the container is created. The host workspace is
# already mounted at $WORKSPACE_DIR by the time this runs, so we initialize
# submodules, create the conda/mamba environment, build acados, and install the
# Quadruped-PyMPC package in editable mode here (rather than baking these into
# the image, which would prevent the source from being editable from the host).

set -eo pipefail
# NOTE: `set -u` is intentionally omitted. Conda's activate scripts (and the
# ROS humble activate hooks shipped via robostack) reference unbound variables
# such as $CONDA_BUILD, which would otherwise crash this script with
# "unbound variable" the moment we `conda activate` the env.

# devcontainers mount the workspace at /workspaces/<repo>; fall back to PWD if
# the variable isn't set (e.g. when running this script outside DevPod).
WORKSPACE_DIR="${CONTAINER_WORKSPACE_FOLDER:-$(pwd)}"
if [ ! -f "${WORKSPACE_DIR}/pyproject.toml" ]; then
    # Search /workspaces for a directory containing this repo's pyproject.toml.
    for candidate in /workspaces/*/; do
        if [ -f "${candidate}pyproject.toml" ] && grep -q '"quadruped_pympc"' "${candidate}pyproject.toml" 2>/dev/null; then
            WORKSPACE_DIR="${candidate%/}"
            break
        fi
    done
fi

echo "=== Quadruped-PyMPC DevPod setup ==="
echo "Workspace: ${WORKSPACE_DIR}"

cd "${WORKSPACE_DIR}"

# ---------------------------------------------------------------------------
# Conda / mamba bootstrap
# ---------------------------------------------------------------------------
export PATH="/opt/conda/bin:${PATH}"
# shellcheck source=/dev/null
source /opt/conda/etc/profile.d/conda.sh
if [ -f /opt/conda/etc/profile.d/mamba.sh ]; then
    # shellcheck source=/dev/null
    source /opt/conda/etc/profile.d/mamba.sh
fi

ENV_NAME="quadruped_pympc_ros2_humble_env"
ENV_FILE="${WORKSPACE_DIR}/installation/mamba/nvidia_cuda/mamba_environment_ros2_humble.yml"

# ---------------------------------------------------------------------------
# Git submodules (acados et al.)
# ---------------------------------------------------------------------------
if [ -f "${WORKSPACE_DIR}/.gitmodules" ]; then
    echo "--- Initializing git submodules ---"
    git -C "${WORKSPACE_DIR}" submodule update --init --recursive
fi

# ---------------------------------------------------------------------------
# Create / update the mamba environment
# ---------------------------------------------------------------------------
if conda env list | awk '{print $1}' | grep -qx "${ENV_NAME}"; then
    echo "--- Conda env '${ENV_NAME}' already exists; skipping create ---"
else
    echo "--- Creating conda env '${ENV_NAME}' from ${ENV_FILE} ---"
    mamba env create -f "${ENV_FILE}"
fi

# Activate the environment for the remainder of this script
conda activate "${ENV_NAME}"

# ---------------------------------------------------------------------------
# Build acados
# ---------------------------------------------------------------------------
ACADOS_DIR="${WORKSPACE_DIR}/quadruped_pympc/acados"
if [ -d "${ACADOS_DIR}" ]; then
    echo "--- Building acados ---"
    mkdir -p "${ACADOS_DIR}/build"
    (
        cd "${ACADOS_DIR}/build"
        cmake -DACADOS_WITH_SYSTEM_BLASFEO:BOOL=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ..
        make install -j"$(nproc)"
    )
    pip install -e "${ACADOS_DIR}/interfaces/acados_template"
else
    echo "WARNING: acados submodule not found at ${ACADOS_DIR}; skipping build."
fi

# ---------------------------------------------------------------------------
# Install Quadruped-PyMPC itself in editable mode
# ---------------------------------------------------------------------------
echo "--- pip install -e . ---"
pip install -e "${WORKSPACE_DIR}"

# ---------------------------------------------------------------------------
# Developer tools: tmux + Claude Code
# ---------------------------------------------------------------------------
if ! command -v tmux >/dev/null 2>&1; then
    echo "--- Installing tmux ---"
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tmux
else
    echo "--- tmux already installed ---"
fi

if ! command -v claude >/dev/null 2>&1; then
    echo "--- Installing Claude Code ---"
    curl -fsSL https://claude.ai/install.sh | bash
else
    echo "--- Claude Code already installed ---"
fi
# Claude Code's native installer drops `claude` into ~/.local/bin; the PATH
# export is added below alongside the other persistent shell settings.

# ---------------------------------------------------------------------------
# Persistent shell configuration
# ---------------------------------------------------------------------------
BASHRC="${HOME}/.bashrc"
add_line() {
    local line="$1"
    grep -qxF "${line}" "${BASHRC}" 2>/dev/null || echo "${line}" >> "${BASHRC}"
}

add_line 'export PATH="$HOME/.local/bin:$PATH"'
add_line "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\"${ACADOS_DIR}/lib\""
add_line "export ACADOS_SOURCE_DIR=\"${ACADOS_DIR}\""
add_line "conda activate ${ENV_NAME}"

echo "=== Setup complete ==="
echo "Open a new shell (or 'source ~/.bashrc') to activate ${ENV_NAME} automatically."
