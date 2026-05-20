# agent-sandbox

Run AI coding agents (Claude Code, OpenCode, Pi, Codex) in a sandboxed Docker container.

AI agents run as your OS user. Even with built-in permission prompts, the process still
has access to your SSH keys, credentials, and secrets. This project sandboxes them in a
container so they only see what you explicitly give them.

Two directories are mounted into the container:

| Host                    | Container     | Description                         |
| ----------------------- | ------------- | ----------------------------------- |
| `$PWD`                  | `/workspace`  | Your current project                |
| `~/.agent-sandbox/home` | `/home/agent` | Sandbox home, persisted across runs |

## Installation

```sh
# Clone into ~/.agent-sandbox
git clone git@github.com:danroc/agent-sandbox.git ~/.agent-sandbox

# Symlink the launcher onto your PATH
ln -s ~/.agent-sandbox/agent ~/.local/bin/agent

# Build the image
agent update

# Set git identity inside the sandbox (persists across runs)
agent bash git config --global user.name  "Your Name"
agent bash git config --global user.email "you@example.com"
```

## Usage

```sh
agent                  # Interactive bash shell
agent claude           # Claude Code
agent opencode         # opencode
agent pi               # pi
agent codex            # codex
agent versions         # Print tool versions
agent update           # Rebuild the image
```

Arguments after the command are forwarded: `agent claude -p "explain repo"`.

### Flags

Flags go before the command name and can be repeated:

| Flag                   | Description                                                                     |
| ---------------------- | ------------------------------------------------------------------------------- |
| `-p, --publish SPEC`   | Publish a port. Bare number maps 1-to-1; full docker `-p` syntax works too.     |
| `-e, --env SPEC`       | Set or forward an env var (`-e DEBUG` passes the host value; `-e K=V` sets it). |
| `-v, --volume SPEC`    | Mount a host path (`-v /host:/container[:ro]`).                                 |
| `-D, --docker-arg ARG` | Pass a raw argument to `docker run` (e.g. `-D --memory=4g`).                    |

```sh
agent -p 5173 claude               # Expose a dev server port
agent -e NODE_ENV=development bash # Set an env var
agent -e DEBUG codex               # Forward a host env var
agent -v "$PWD/scratch:/scratch" bash  # Extra volume mount
agent -D --memory=4g claude        # Cap container memory
```

## Reaching host services

Inside the sandbox, `localhost` resolves to the container, not your machine. To reach a
service running on the host (e.g. a local API or database), use `host.docker.internal`
instead.

Note that the host service needs to listen on `0.0.0.0`, not `127.0.0.1`. Loopback
addresses are not reachable from inside the container.

## Customizing the sandbox

Copy the example config and edit it:

```sh
cp ~/.agent-sandbox/config.sh.example ~/.agent-sandbox/config.sh
```

The config exposes four arrays:

| Array          | When applied   | Description                                             |
| -------------- | -------------- | ------------------------------------------------------- |
| `APT_PACKAGES` | `agent update` | Extra Debian packages baked into the image.             |
| `NPM_PACKAGES` | `agent update` | Extra global npm packages baked into the image.         |
| `MOUNTS`       | Every run      | Extra volume mounts, in `-v SOURCE:TARGET[:ro]` syntax. |
| `DOCKER_ARGS`  | Every run      | Raw arguments passed to `docker run`.                   |

`MOUNTS` and `DOCKER_ARGS` take effect on the next run without a rebuild. Changes to
`APT_PACKAGES` or `NPM_PACKAGES` require running `agent update` to rebuild the image.
