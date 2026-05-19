FROM node:26-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        # Used by Claude Code for sandboxing
        bubblewrap \
        socat \
        # Improved terminal support
        ncurses-term \
        # Common utilities
        curl \
        fd-find \
        git \
        jq \
        ripgrep \
        # Python and related tools
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
    @anthropic-ai/claude-code@latest \
    @earendil-works/pi-coding-agent@latest \
    @openai/codex@latest \
    opencode-ai@latest

# Show the project name and working directory in the shell prompt.
RUN printf '\nPS1='\''(${AGENT_PROJECT_NAME:-sandbox}) \w\$ '\''\n' >> /etc/bash.bashrc

WORKDIR /workspace

CMD ["bash"]
