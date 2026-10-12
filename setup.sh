#!/bin/bash
set -Eeuo pipefail

LOG_FILE="/var/log/script.sh.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

trap 'status=$?; echo "Bootstrap failed (exit ${status}) at line ${BASH_LINENO[0]}"; exit "$status"' ERR

echo "Starting campaign-site bootstrap: $(date -Is)"

REPO_URL="https://github.com/Varun7687/assignment-3.git"
BRANCH="assignment-3"

# Amazon Linux 2023 provides dnf. curl-minimal supplies the curl command.
dnf install -y httpd git curl-minimal python3

WORK_DIR="$(mktemp -d /tmp/campaign-site.XXXXXX)"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORK_DIR/repo"

# Support the documented project path as well as common repo-root layouts.
if [[ -d "$WORK_DIR/repo/assignment-3-campaign-site/site" ]]; then
    SITE_DIR="$WORK_DIR/repo/assignment-3-campaign-site/site"
elif [[ -d "$WORK_DIR/repo/site" ]]; then
    SITE_DIR="$WORK_DIR/repo/site"
else
    echo "Could not find the website directory. Expected assignment-3-campaign-site/site or site in the repository."
    exit 1
fi

if [[ ! -f "$SITE_DIR/index.html" ]]; then
    echo "No index.html found in $SITE_DIR"
    exit 1
fi

mkdir -p /var/www/html
find /var/www/html -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
cp -a "$SITE_DIR"/. /var/www/html/

# Use IMDSv2 to fetch instance details for the page footer.
IMDS_TOKEN="$(curl -fsS --connect-timeout 2 --max-time 5 --retry 2 \
    -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)"

INSTANCE_ID="unknown"
AZ="unknown"
if [[ -n "$IMDS_TOKEN" ]]; then
    INSTANCE_ID="$(curl -fsS --connect-timeout 2 --max-time 5 \
        -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
        http://169.254.169.254/latest/meta-data/instance-id || true)"
    AZ="$(curl -fsS --connect-timeout 2 --max-time 5 \
        -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
        http://169.254.169.254/latest/meta-data/placement/availability-zone || true)"
fi
INSTANCE_ID="${INSTANCE_ID:-unknown}"
AZ="${AZ:-unknown}"

export INSTANCE_ID AZ
python3 - /var/www/html/index.html <<'PY'
import html
import os
import re
import sys
from pathlib import Path

index_path = Path(sys.argv[1])
page = index_path.read_text(encoding="utf-8")
instance_id = html.escape(os.environ.get("INSTANCE_ID", "unknown"))
az = html.escape(os.environ.get("AZ", "unknown"))
footer = f'<footer class="instance-info">Served by instance {instance_id} in {az}</footer>'

if re.search(r"</body\s*>", page, flags=re.IGNORECASE):
    page = re.sub(r"</body\s*>", footer + "\n</body>", page, count=1, flags=re.IGNORECASE)
else:
    page += "\n" + footer + "\n"

index_path.write_text(page, encoding="utf-8")
PY

# The target group health check should request /health and receive HTTP 200.
printf 'OK\n' > /var/www/html/health
chown -R apache:apache /var/www/html
systemctl enable --now httpd

curl --fail --silent --show-error http://localhost/health
echo "Campaign-site bootstrap completed: $(date -Is)"
