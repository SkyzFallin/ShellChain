<div align="center">

<img src="sc.jpg" alt="ShellChain" width="760"/>

<br/>

<img src="banner.svg" alt="ShellChain Banner" width="760"/>

<br/><br/>

![Shell](https://img.shields.io/badge/shell-expect%20%2F%20bash-4ec9b0?style=flat-square&logo=gnu-bash&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Linux%20%2F%20Kali-c586c0?style=flat-square&logo=linux&logoColor=white)
![Version](https://img.shields.io/badge/version-1.0-58a6ff?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-6a9955?style=flat-square)
![Author](https://img.shields.io/badge/author-SkyzFallin-ce9178?style=flat-square&logo=github&logoColor=white)

</div>

---

ShellChain runs commands as a different user on a remote host by chaining SSH and `su` in a single command. It uses `expect` to handle the interactive password prompts that normally require a TTY — making it work in environments where standard approaches fail: automation frameworks, MCP servers, CI/CD pipelines, cron jobs, and scripts.

---

## The Problem

```bash
sshpass -p 'pass1' ssh user1@target "su -c 'whoami' user2"
```

```
su: must be run from a terminal
```

`su` requires a TTY to accept a password. Non-interactive SSH sessions don't allocate one. The command dies before it even gets to run.

## The Solution

```bash
shellchain 10.10.10.162 user1 'pass1' user2 'pass2' "whoami"
```

```
user2
```

One command. Full chain. Clean output.

---

## Use Cases

ShellChain was built for situations where interactive TTY allocation isn't possible or practical:

- **Penetration testing** — lateral movement between users after initial foothold, without spawning a full interactive shell
- **MCP / AI agent automation** — feed commands through Claude's Kali MCP server or similar agentic frameworks that invoke tools non-interactively
- **CI/CD pipelines** — run privileged post-deploy steps as a service account without baking `sudo` into the pipeline
- **Cron jobs** — execute maintenance tasks as a different user on a schedule
- **Automation scripts** — anywhere you need `ssh user1 → su user2 → run command` in a single scriptable call

> **`su` vs `sudo`:** ShellChain handles `su` (target user's own password). If the remote host uses `sudo` instead, wrap your command: `"sudo -u targetuser command"` and pass the SSH user's sudo password as `su_pass`.

---

## Requirements

| Dependency | Minimum Version | Notes |
|------------|----------------|-------|
| `expect` | 5.x | Core requirement — handles TTY simulation |
| `openssh-client` | Any modern | Already present on most systems |
| `bash` | 4.x | For wrapper alias / scripting |

```bash
# Debian / Ubuntu / Kali
sudo apt install expect

# RHEL / CentOS / Fedora
sudo yum install expect

# Arch
sudo pacman -S expect
```

---

## Compatibility

| OS | Status |
|----|--------|
| Kali Linux | ✅ Tested |
| Ubuntu 20.04 / 22.04 / 24.04 | ✅ Tested |
| Debian 11 / 12 | ✅ Tested |
| RHEL / CentOS 7+ | ✅ Compatible |
| Arch Linux | ✅ Compatible |
| macOS (Homebrew expect) | ⚠️ Mostly works — not primary target |

---

## Installation

```bash
git clone https://github.com/SkyzFallin/ShellChain.git
cd ShellChain
chmod +x shellchain.sh

# System-wide install
sudo cp shellchain.sh /usr/local/bin/shellchain
```

Verify:

```bash
shellchain
# ShellChain - SSH + su command execution for non-interactive shells
# Usage: shellchain <target> <ssh_user> <ssh_pass> <su_user> <su_pass> "<cmd>" [timeout]
```

---

## Usage

```bash
shellchain <target> <ssh_user> <ssh_pass> <su_user> <su_pass> "<command>" [timeout]
```

| Argument | Description |
|----------|-------------|
| `target` | Target IP or hostname |
| `ssh_user` | SSH login username |
| `ssh_pass` | SSH password (ignored if `SSH_KEY` is set) |
| `su_user` | User to `su` to on the remote host |
| `su_pass` | Password for the su target user |
| `command` | Command to run as the su target user |
| `timeout` | Optional. Seconds before timeout. Default: `30` |

---

## Examples

**Run a command as another user:**
```bash
shellchain 10.10.10.162 alice 'alicepass' bob 'bobpass' "id"
```

**Chain multiple commands:**
```bash
shellchain 10.10.10.162 alice 'alicepass' bob 'bobpass' "whoami && cat /etc/hostname && uptime"
```

**Longer timeout for slow commands:**
```bash
shellchain 10.10.10.162 alice 'alicepass' bob 'bobpass' "find / -perm -4000 2>/dev/null" 60
```

**SSH key authentication:**
```bash
SSH_KEY=/path/to/private_key shellchain 10.10.10.79 alice '' bob 'bobpass' "whoami"
```

**Same user — skips `su`, runs directly over SSH:**
```bash
shellchain 10.10.10.162 alice 'alicepass' alice 'alicepass' "sudo -l"
```

**Pentest — read sensitive file after foothold:**
```bash
shellchain 10.10.10.50 www-data 'webpass' root 'r00tpass' "cat /etc/shadow"
```

**Clean output for scripting (strip echo + trailing prompt):**
```bash
shellchain 10.10.10.162 alice 'alicepass' bob 'bobpass' "cat /etc/passwd" | sed '1d;/^\$ $/d'
```

**Suggested alias:**
```bash
# Add to ~/.bashrc or ~/.zshrc
alias sc='shellchain'

sc 10.10.10.162 alice 'alicepass' bob 'bobpass' "whoami"
```

---

## How It Works

```
 Attacker             Remote Host
+------------+  SSH  +------------+  su   +------------+
| shellchain |------>|  ssh_user  |------>|  su_user   |
|            |       |            |       | > command  |
|   stdout  <|-------|   stdout  <|-------|            |
+------------+       +------------+       +------------+
```

1. Opens SSH connection to target — handles password or key auth.
2. Runs `su - <su_user>` and sends the password at the prompt.
3. Executes the command. Output passes through to stdout.
4. Exits both shells cleanly.

> Step 2 is skipped when `ssh_user` and `su_user` are the same.

---

## Script Preview

<details>
<summary><code>shellchain.sh</code> — click to expand</summary>

```tcl
#!/usr/bin/expect -f
#
# ShellChain - SSH + su command execution for non-interactive shells
# https://github.com/SkyzFallin/ShellChain
#
# Usage:
#   shellchain <target> <ssh_user> <ssh_pass> <su_user> <su_pass> "<command>" [timeout]
#
# SSH Key Auth:
#   SSH_KEY=/path/to/key shellchain <target> <ssh_user> "" <su_user> <su_pass> "<cmd>"

if {$argc < 6} {
    puts "ShellChain - SSH + su command execution for non-interactive shells"
    puts ""
    puts "Usage: shellchain <target> <ssh_user> <ssh_pass> <su_user> <su_pass> \"<cmd>\" \[timeout\]"
    puts ""
    puts "Examples:"
    puts "  shellchain 10.10.10.162 alice 'pass1' bob 'pass2' \"id\""
    puts "  shellchain 10.10.10.162 alice 'pass1' bob 'pass2' \"cat /etc/shadow\" 60"
    puts ""
    puts "SSH Key Auth:"
    puts "  SSH_KEY=/tmp/id_rsa shellchain 10.10.10.79 alice '' bob 'pass2' \"whoami\""
    puts ""
    exit 1
}

set target   [lindex $argv 0]
set ssh_user [lindex $argv 1]
set ssh_pass [lindex $argv 2]
set su_user  [lindex $argv 3]
set su_pass  [lindex $argv 4]
set cmd      [lindex $argv 5]

if {$argc >= 7} { set timeout [lindex $argv 6] } else { set timeout 30 }

set ssh_key ""
if {[info exists env(SSH_KEY)]} { set ssh_key $env(SSH_KEY) }

# --- SSH ---
log_user 0
set ssh_opts "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

if {$ssh_key ne ""} {
    spawn ssh {*}$ssh_opts -i $ssh_key ${ssh_user}@${target}
} else {
    spawn ssh {*}$ssh_opts ${ssh_user}@${target}
}

expect {
    -re "password:|Password:"    { send "${ssh_pass}\r" }
    -re "passphrase"             { send "${ssh_pass}\r" }
    -re "\\\$ $|# $|> $"        {}
    "Permission denied"          { puts "ERROR: SSH auth failed for ${ssh_user}@${target}"; exit 1 }
    "No route to host"           { puts "ERROR: Cannot reach ${target}"; exit 1 }
    "Connection refused"         { puts "ERROR: SSH connection refused on ${target}"; exit 1 }
    "Connection timed out"       { puts "ERROR: SSH connection timed out to ${target}"; exit 1 }
    timeout                      { puts "ERROR: SSH timeout connecting to ${target}"; exit 1 }
}
expect {
    -re "\\\$ $|# $|> $" {}
    timeout { puts "ERROR: Timed out waiting for shell prompt"; exit 1 }
}

# --- su (skip if same user) ---
if {$su_user ne $ssh_user} {
    send "su - ${su_user}\r"
    expect {
        -re "Password:|password:" { send "${su_pass}\r" }
        timeout { puts "ERROR: su did not prompt for password"; exit 1 }
    }
    expect {
        -re "\\\$ $|# $|> $"   {}
        "Authentication failure" { puts "ERROR: su authentication failed for ${su_user}"; exit 1 }
        "incorrect password"     { puts "ERROR: Incorrect password for ${su_user}"; exit 1 }
        timeout                  { puts "ERROR: Timed out after su to ${su_user}"; exit 1 }
    }
}

# --- Execute ---
log_user 1
send "${cmd}\r"
expect {
    -re "\\\$ $|# $|> $" {}
    timeout {}
}
log_user 0

# --- Exit ---
if {$su_user ne $ssh_user} { send "exit\r"; expect -re "\\\$ |# |> " }
send "exit\r"
expect eof
exit 0
```

</details>

---

## Limitations

- **Interactive commands not supported** — `vim`, `top`, `less`, and anything requiring keyboard input will hang. Commands must produce output and exit cleanly.
- **One level of `su`** — for double user-hops (user1 → user2 → user3), chain two shellchain calls.
- **Output includes echo + trailing prompt** — pipe through `sed '1d;/^\$ $/d'` to strip when scripting.
- **Special characters in passwords** — wrap in single quotes. Escape inner single quotes with `'\''`.
- **Massive output** — for commands producing large output, redirect to a file on target and retrieve separately.
- **`sudo` vs `su`** — ShellChain handles `su` (target user's password). For `sudo`, wrap your command and pass the SSH user's sudo password.
- **No multiplexing** — each call opens a fresh SSH connection. For bulk operations, loop or parallelize externally.

---

## Error Reference

| Message | Cause |
|---------|-------|
| `ERROR: SSH auth failed` | Bad SSH credentials |
| `ERROR: Cannot reach` | Host down or unreachable |
| `ERROR: SSH connection refused` | No SSH service on target |
| `ERROR: SSH connection timed out` | Firewall or slow network |
| `ERROR: SSH timeout connecting` | General connect timeout |
| `ERROR: Timed out waiting for shell prompt` | Shell didn't produce a recognizable prompt |
| `ERROR: su did not prompt for password` | Unexpected su behavior on target |
| `ERROR: su authentication failed` | Bad su password |
| `ERROR: Incorrect password` | Wrong su target password |
| `ERROR: Timed out after su` | su prompt wait exceeded timeout |

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

## Security

See [SECURITY.md](SECURITY.md) for responsible disclosure and credential handling guidance.

---

<div align="center">
<sub>Built by <a href="https://github.com/SkyzFallin">SkyzFallin</a></sub>
</div>
