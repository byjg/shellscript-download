---
# Auto-generated from public/scripts/ssh-agent.sh — Do not edit.
description: "Configure ssh-agent startup and SSH key loading in your shell"
---

# ssh-agent

Configure ssh-agent startup and SSH key loading in your shell

```bash
load.sh ssh-agent
```

## Usage

```text
load.sh ssh-agent -- [options]

Writes a shell init snippet that, on every new shell session, finds an
ssh-agent and loads the SSH keys that are not in it yet.

All shells share one agent: the one of the session when it answers, then the
one of systemd ($XDG_RUNTIME_DIR/openssh_agent), then one started on
~/.ssh/agent.sock. A key that is missing or cannot be added is warned about.

By default, all private keys found in ~/.ssh are added. Use --key to add
only specific keys; a key that does not exist is an error. Running this script
again overwrites the previous config.

Options:
  -h, --help       Show this help and exit
  --dry-run        Print actions without executing them
  --manifest       Print installation manifest and exit
  --key <path>     Add this key (can be repeated for multiple keys)

Examples:
  load.sh ssh-agent
  load.sh ssh-agent -- --key ~/.ssh/id_ed25519
  load.sh ssh-agent -- --key ~/.ssh/id_rsa --key ~/.ssh/work_key
  load.sh ssh-agent -- --dry-run
```

[Script page](https://shellscript.download/scripts/ssh-agent) · [Source](https://github.com/byjg/shellscript-download/blob/main/public/scripts/ssh-agent.sh)
