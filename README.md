# ShellChain

SSH + su command execution for non-interactive shells.

ShellChain runs commands as a different user on a remote host by chaining SSH and `su` in a single command. It uses `expect` to handle the interactive password prompts that normally require a TTY, making it work in environments where standard approaches fail -- automation frameworks, MCP servers, CI/CD pipelines, cron jobs, and scripts.

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

## Installation

```bash
git clone https://github.com/SkyzFallin/ShellChain.git
cd ShellChain
chmod +x shellchain.sh

# System-wide install
sudo cp shellchain.sh /usr/local/bin/shellchain
```

### Dependencies

- `expect` -- handles the interactive prompts
- `ssh` -- you already have this

```bash
# Debian / Ubuntu / Kali
sudo apt install expect

# RHEL / CentOS / Fedora
sudo yum install expect

# Arch
sudo pacman -S expect
```

## Usage

```
shellchain <target> <ssh_user> <ssh_pass> <su_user> <su_pass> "<command>" [timeout]
```

| Argument   | Description                                 |
|------------|---------------------------------------------|
| target     | Target IP or hostname                       |
| ssh_user   | SSH login username                          |
| ssh_pass   | SSH password (ignored if SSH_KEY is set)    |
| su_user    | User to su to on the remote host            |
| su_pass    | Password for the su target user             |
| command    | Command to run as the su target user        |
| timeout    | Optional. Seconds before timeout. Default 30|

## Examples

Run a command as another user:

```bash
shellchain 10.10.10.162 alice 'alicepass' bob 'bobpass' "id"
```

Chain multiple commands:

```bash
shellchain 10.10.10.162 alice 'alicepass' bob 'bobpass' "whoami && cat /etc/hostname && uptime"
```

Longer timeout for slow commands:

```bash
shellchain 10.10.10.162 alice 'alicepass' bob 'bobpass' "find / -perm -4000 2>/dev/null" 60
```

SSH key authentication:

```bash
SSH_KEY=/path/to/private_key shellchain 10.10.10.79 alice '' bob 'bobpass' "whoami"
```

Same user (skips su, runs directly over SSH):

```bash
shellchain 10.10.10.162 alice 'alicepass' alice 'alicepass' "sudo -l"
```

## How It Works

```
 Attacker             Remote Host
+------------+  SSH  +------------+  su   +------------+
| shellchain |------>|  ssh_user  |------>|  su_user   |
|            |       |            |       | > command  |
|   stdout  <|-------|   stdout  <|-------|            |
+------------+       +------------+       +------------+
```

1. Opens SSH connection to target. Handles password or key auth.
2. Runs `su - <su_user>` and sends the password at the prompt.
3. Executes the command. Output passes through to stdout.
4. Exits both shells cleanly.

Step 2 is skipped when ssh_user and su_user are the same.

## Errors

| Message                          | Cause                           |
|----------------------------------|---------------------------------|
| ERROR: SSH auth failed           | Bad SSH credentials             |
| ERROR: Cannot reach <target>     | Host down or unreachable        |
| ERROR: SSH connection refused    | No SSH service on target        |
| ERROR: su authentication failed  | Bad su password                 |
| ERROR: Timed out...              | Operation exceeded timeout      |

## Notes

- Output includes the command echo and a trailing prompt. Pipe through `sed '1d;/^\$ $/d'` to strip them when scripting.
- Passwords with special characters should be wrapped in single quotes. Escape inner single quotes with `'\''`.
- For commands that produce massive output, redirect to a file on the target and retrieve separately.
- Interactive commands (vim, top, less) are not supported. Commands must produce output and exit.
- Supports one level of su. For double user-hops, chain two shellchain calls.

## License

MIT
