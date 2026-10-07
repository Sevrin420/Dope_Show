#!/usr/bin/env bash
# Creates a restricted `deploy` user for the Lunch Rush deploy workflow.
# Run once on the VPS as root (or via sudo). Idempotent.
# Usage: sudo bash setup-deploy-user.sh "<deploy public key line>"
#
# It does NOT touch root, your admin user, or their keys. Admin access stays
# as it was; the root-capable runner in vps-run.yml still works.
set -euo pipefail

PUBKEY="${1:?pass the deploy public key as the first argument}"
WEBROOT=/var/www/lunch-rush
USER_NAME=deploy

id "$USER_NAME" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$USER_NAME"

install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
printf '%s\n' "$PUBKEY" > "/home/$USER_NAME/.ssh/authorized_keys"
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.ssh/authorized_keys"
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"

# Only the Caddy reload is allowed as root. sudo resolves commands via secure_path,
# where /usr/bin comes before /bin, so the rule must name the resolved path.
SYSTEMCTL="$(readlink -f "$(command -v systemctl)")"
SUDOERS=/etc/sudoers.d/deploy-lunch-rush
printf '%s ALL=(root) NOPASSWD: %s reload caddy\n' "$USER_NAME" "$SYSTEMCTL" > "$SUDOERS"
chmod 440 "$SUDOERS"
visudo -cf "$SUDOERS"

# The deploy user owns the site files; Caddy only needs to read them.
install -d -m 755 -o "$USER_NAME" -g caddy "$WEBROOT"
chown -R "$USER_NAME:caddy" "$WEBROOT"

echo "deploy user ready. sudo rule uses $SYSTEMCTL. Check with: sudo -l -U $USER_NAME"
