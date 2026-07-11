FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Variable for default user `node` to be used in the following steps
ARG USERNAME=vscode

# Cache busting argument to force re-builds of following steps (all)
#ARG CACHE_BUST=1

# Ensure regional Ubuntu mirror (Germany) for faster apt package downloads
RUN sed -Ei 's/(\w+\.)?archive\.ubuntu\.com/de.archive.ubuntu.com/g' \
    /etc/apt/sources.list.d/ubuntu.sources

# Update apt cache and upgrade packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends

# Set locale to en_US.UTF-8
ENV LANG=en_US.UTF-8
RUN apt-get install -y --no-install-recommends locales \
    && sed -i -e "s/# $LANG.*/$LANG UTF-8/" /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=$LANG
    # locale-gen en_US.UTF-8

# Install essential packages for development, media processing, and general utilities.
RUN apt-get install -y --no-install-recommends \
        zsh vim emacs \
        git wget curl aria2 rsync gnupg ca-certificates \
        tmux htop btop glances \
        less bat multitail python3-pygments \
        ngrep lsof \
        fd-find \
        jq gawk parallel \
        unzip zip p7zip-full \
        python3-pip python3-venv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS (npm included) for modern package compatibility.
COPY root/etc/apt/sources.list.d/nodesource.sources /etc/apt/sources.list.d/nodesource.sources
RUN mkdir -p /etc/apt/keyrings \
        && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
            | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
        && apt-get update \
        && apt-get install -y --no-install-recommends nodejs npm \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# Install OpenVPN 3 client using new DEB sources format.
COPY root/etc/apt/sources.list.d/openvpn.sources /etc/apt/sources.list.d/openvpn.sources
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://packages.openvpn.net/packages-repo.gpg \
        -o /etc/apt/keyrings/openvpn.asc \
    && apt-get update \
    && apt-get install -y --no-install-recommends openvpn3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package and project manager).
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    && mv /root/.local/bin/uvx /usr/local/bin/uvx

# Install Miniconda for flexible Python environment management.
RUN ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
        amd64) MINICONDA_ARCH="x86_64" ;; \
        arm64) MINICONDA_ARCH="aarch64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${MINICONDA_ARCH}.sh" -o /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/miniconda \
    && rm -f /tmp/miniconda.sh \
    && /opt/miniconda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main \
    && /opt/miniconda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r \
    && /opt/miniconda/bin/conda config --system --set notify_outdated_conda false \
    && /opt/miniconda/bin/conda update -n base -c defaults conda -y \
    && /opt/miniconda/bin/conda create -y -n dev python=3.12 pip \
    && /opt/miniconda/bin/conda config --system --set auto_update_conda false \
    && /opt/miniconda/bin/conda clean -afy \
    && chown -R $USERNAME:$USERNAME /opt/miniconda

# Create workspace directory (required by devcontainer workspaceFolder setting)
RUN mkdir -p /workspace && chown ${USERNAME}:${USERNAME} /workspace

# Make zsh default shell
RUN chsh -s $(which zsh) $USERNAME

# Ensure user `$USERNAME` has full access to `sudo`
RUN mkdir -p /etc/sudoers.d \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# From now on continue as user `$USERNAME` in user's home directory
USER $USERNAME
WORKDIR /home/$USERNAME

# Cache busting argument to force re-builds of following steps (user level, e.g. most recent dotfiles)
ARG CACHE_BUST=1
# For this to be effictive set `"runArgs": ["--build-arg", "CACHE_BUST=$(date +%s)"]` in devcontainer.json

# Clone dotfiles to `/home/$USERNAME/dotfiles` and create all symlinks
RUN git clone https://github.com/cbaoth/dotfiles "$HOME/dotfiles" \
    && "$HOME/dotfiles/tools/link.sh"

# Start zsh one time to bootstrap the plugin manager (zinit) and install all
# plugins. ZINIT_TURBO=false forces synchronous loading so every plugin is
# installed during this build step (turbo/async would defer installs to the
# first real prompt, which never happens in `zsh -ic true`).
RUN ZINIT_TURBO=false zsh -ic true

# Auto-activate the default conda environment for interactive zsh/bash shells.
RUN /opt/miniconda/bin/conda init zsh bash \
    && printf '%s\n' \
    '# Auto-activate the default conda environment for interactive zsh/bash shells.' \
    'if ! command -v conda >/dev/null 2>&1 && [[ -f /opt/miniconda/etc/profile.d/conda.sh ]]; then' \
    '  . /opt/miniconda/etc/profile.d/conda.sh' \
    '  conda activate dev >/dev/null 2>&1 || true' \
    'fi' >> /home/$USERNAME/.bashrc \
    && printf '%s\n' \
    '# Auto-activate the default conda environment for interactive zsh/bash shells.' \
    'if ! command -v conda >/dev/null 2>&1 && [[ -f /opt/miniconda/etc/profile.d/conda.sh ]]; then' \
    '  . /opt/miniconda/etc/profile.d/conda.sh' \
    '  conda activate dev >/dev/null 2>&1 || true' \
    'fi' >> /home/$USERNAME/.zshrc

# Source custom /workspace/local/.common.extras from .bashrc/.zshrc if existing (for convenicene)
RUN printf '%s\n' \
    '# Source custom /workspace/local/.commonshrc.local from .bashrc/.zshrc if existing (for convenicene)' \
    'if [[ -f /workspace/local/.commonshrc.local ]]; then' \
    '  source /workspace/local/.commonshrc.local' \
    'fi' >> /home/$USERNAME/.bashrc \
    && printf '%s\n' \
    '# Source custom /workspace/local/.commonshrc.local from .bashrc/.zshrc if existing (for convenicene)' \
    'if [[ -f /workspace/local/.commonshrc.local ]]; then' \
    '  source /workspace/local/.commonshrc.local' \
    'fi' >> /home/$USERNAME/.zshrc

# Source custom /workspace/local/.(zshrc|bashrc).extras from .bashrc/.zshrc if existing (for convenicene)
RUN printf '%s\n' \
    '# Source custom /workspace/local/.(zshrc|bashrc).extras from .bashrc/.zshrc if existing (for convenicene)' \
    'if [[ -f /workspace/local/.bashrc.extras ]]; then' \
    '  source /workspace/local/.bashrc.extras' \
    'fi' >> /home/$USERNAME/.bashrc \
    && printf '%s\n' \
    '# Source custom /workspace/local/.(zshrc|bashrc).extras from .bashrc/.zshrc if existing (for convenicene)' \
    'if [[ -f /workspace/local/.zshrc.extras ]]; then' \
    '  source /workspace/local/.zshrc.extras' \
    'fi' >> /home/$USERNAME/.zshrc

ENV PATH="/workspace/node_modules/.bin/:/opt/miniconda/bin:${PATH}"

ARG CACHE_BUST=0
