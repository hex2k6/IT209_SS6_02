#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")"
echo '=== EXERCISE_BEGIN ==='
set -x
sudo --version | head -n 1
ps -p 1 -o comm=
test -x /usr/bin/systemctl
sudo systemctl cat cron.service
sudo groupadd devops-admin
sudo adduser --disabled-password --gecos '' deployer
sudo usermod -aG devops-admin deployer
id deployer
# Use a root-owned editor helper to load the reviewed rule into visudo's temp file.
# visudo performs the syntax check and saves the actual sudoers include.
sudo install -m 600 devops-admin.sudoers /root/ex2-rule
printf '#!/bin/sh\nfor target do :; done\ncat /root/ex2-rule > "$target"\n' | sudo tee /root/ex2-editor >/dev/null
sudo chmod 700 /root/ex2-editor
sudo env EDITOR=/root/ex2-editor VISUAL=/root/ex2-editor /usr/sbin/visudo -f /etc/sudoers.d/devops-admin
sudo chmod 440 /etc/sudoers.d/devops-admin
sudo /usr/sbin/visudo -c
sudo cat /etc/sudoers.d/devops-admin
sudo su - deployer -c 'bash -s' <<'DEPLOYER'
set -euo pipefail
export LC_ALL=C
echo '=== DEPLOYER_SESSION_BEGIN ==='
whoami
id
echo '$ sudo -l'
sudo -l
echo '$ sudo -n systemctl restart cron'
sudo -k
sudo -n systemctl restart cron
echo 'restart exit code: 0 (no password prompt)'
echo '$ sudo -n systemctl --no-pager status cron'
sudo -n systemctl --no-pager status cron
echo '$ systemctl is-active cron'
systemctl is-active cron
echo 'Checking disallowed commands (must fail):'
if sudo -n /usr/bin/id; then echo 'FAIL: unrestricted command'; exit 1; fi
if sudo -n systemctl daemon-reload; then echo 'FAIL: extra verb'; exit 1; fi
if sudo -n systemctl restart cron --no-block; then echo 'FAIL: extra option'; exit 1; fi
echo 'PASS: NOPASSWD restart works; unrelated commands and extra options denied.'
echo '=== DEPLOYER_SESSION_END ==='
DEPLOYER
set +x
echo '=== EXERCISE_END ==='
