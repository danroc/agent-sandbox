# agent-sandbox

Run AI coding CLIs (Claude Code, opencode, pi, codex) inside a sandboxed Docker
container with an isolated `$HOME`. The current directory is mounted as `/workspace`;
the sandbox home lives at `~/.agent-sandbox/home`.

## Bootstrap

```sh
# 1. Clone into ~/.agent-sandbox so the home mount lives alongside the repo
git clone git@github.com:danroc/agent-sandbox.git ~/.agent-sandbox

# 2. Symlink the launcher onto your PATH
ln -s ~/.agent-sandbox/agent ~/.local/bin/agent

# 3. Build the image
agent update

# 4. Set git identity inside the sandbox home (persists across runs)
agent bash git config --global user.name  "Your Name"
agent bash git config --global user.email "you@example.com"
```

## Usage

```sh
agent                  # Interactive bash shell
agent claude           # Start Claude Code
agent opencode         # Start opencode
agent pi               # Start pi
agent codex            # Start codex
agent versions         # Print tool versions
agent update           # Rebuild the image
```

Arguments after the command are forwarded, e.g. `agent claude -p "explain repo"`.

## Reaching host services

From inside the sandbox, `localhost` is the container itself. To reach a server running
on the host, use `host.docker.internal`. The host service must also be bound to a
non-loopback address (e.g. `0.0.0.0`) for the container to connect.
