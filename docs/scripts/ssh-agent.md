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

Writes a shell init snippet that starts ssh-agent (if not already running)
and loads SSH keys on every new shell session.

By default, all private keys found in ~/.ssh are added. Use --key to add
only specific keys. Running this script again overwrites the previous config.

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
