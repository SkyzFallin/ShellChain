#!/usr/bin/expect -f
#
# ShellChain - SSH + su command execution for non-interactive shells
# https://github.com/SkyzFallin/ShellChain
#
# Chains SSH and su in a single command for environments
# where su fails due to missing TTY.
#
# Usage:
#   shellchain <target> <ssh_user> <ssh_pass> <su_user> <su_pass> "<command>" [timeout]
#
# SSH Key Auth:
#   SSH_KEY=/path/to/key shellchain <target> <ssh_user> "" <su_user> <su_pass> "<cmd>"
#
# License: MIT

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

set target [lindex $argv 0]; set ssh_user [lindex $argv 1]; set ssh_pass [lindex $argv 2]
set su_user [lindex $argv 3]; set su_pass [lindex $argv 4]; set cmd [lindex $argv 5]
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
    -re "password:|Password:" { send "${ssh_pass}\r" }
    -re "passphrase" { send "${ssh_pass}\r" }
    -re "\\\$ $|# $|> $" {}
    "Permission denied" { puts "ERROR: SSH auth failed for ${ssh_user}@${target}"; exit 1 }
    "No route to host" { puts "ERROR: Cannot reach ${target}"; exit 1 }
    "Connection refused" { puts "ERROR: SSH connection refused on ${target}"; exit 1 }
    "Connection timed out" { puts "ERROR: SSH connection timed out to ${target}"; exit 1 }
    timeout { puts "ERROR: SSH timeout connecting to ${target}"; exit 1 }
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
        -re "\\\$ $|# $|> $" {}
        "Authentication failure" { puts "ERROR: su authentication failed for ${su_user}"; exit 1 }
        "incorrect password" { puts "ERROR: Incorrect password for ${su_user}"; exit 1 }
        timeout { puts "ERROR: Timed out after su to ${su_user}"; exit 1 }
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
send "exit\r"; expect eof; exit 0
