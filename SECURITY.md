# Security Policy

## Responsible Use

ShellChain is a penetration testing and automation tool. It is intended for use on systems you own or have explicit written authorization to test. Unauthorized use against systems you do not have permission to access is illegal and unethical.

## Credential Handling

ShellChain accepts passwords as command-line arguments. Be aware of the following risks:

- **Shell history** — passwords passed on the command line will appear in your shell history (`~/.bash_history`, `~/.zsh_history`). Clear history or use `HISTIGNORE` to exclude shellchain calls.
- **Process list** — arguments are briefly visible in `ps aux` output on the local machine. Avoid running on shared systems.
- **SSH key auth is preferred** — use `SSH_KEY=/path/to/key` to avoid passing SSH passwords entirely.
- **Logs** — ShellChain suppresses SSH verbosity (`LogLevel=ERROR`) and disables known_hosts logging. Remote host auth logs (e.g. `/var/log/auth.log`) will still record the connection.

**Mitigations:**

```bash
# Suppress from history (zsh/bash)
export HISTIGNORE="shellchain*"

# Or prefix with a space (bash with HISTCONTROL=ignorespace)
 shellchain 10.10.10.1 alice 'pass' bob 'pass' "id"

# Prefer key auth
SSH_KEY=~/.ssh/id_rsa shellchain 10.10.10.1 alice '' bob 'bobpass' "id"
```

## Reporting Vulnerabilities

If you discover a security vulnerability in ShellChain, please report it responsibly:

- Open a [GitHub Issue](https://github.com/SkyzFallin/ShellChain/issues) with the label `security`
- Or contact the author directly via GitHub: [@SkyzFallin](https://github.com/SkyzFallin)

Please do not publicly disclose vulnerabilities before they have been addressed.

## Disclaimer

This tool is provided as-is for authorized security testing and automation purposes. The author assumes no liability for misuse. Always obtain proper authorization before testing any system you do not own.
