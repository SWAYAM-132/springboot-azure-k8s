#!/usr/bin/env bash
set -euo pipefail

# Register an agent without SSH/Bastion and without a PAT.
# Uses Azure VM Run Command to start Entra device-code registration in the
# background, then retrieves the one-time code from the VM's local log.

: "${VM_NAME:?Set VM_NAME}"
: "${AGENT_POOL:?Set AGENT_POOL}"
: "${RESOURCE_GROUP:=rg-todo-platform-ci}"
: "${AGENT_NAME:=${VM_NAME}}"
: "${ORG_URL:=https://dev.azure.com/swayam-cloud-lab}"

REMOTE_START=$(cat <<EOF
set -euo pipefail
sudo -u azureagent bash -lc '
  cd /opt/ado-agent
  if [[ ! -x ./config.sh ]]; then
    curl -fsSL https://vstsagentpackage.azureedge.net/agent/5.281.1/vsts-agent-linux-x64-5.281.1.tar.gz | tar -xz
  fi
  nohup ./config.sh --unattended \
    --url "$ORG_URL" --auth AAD --pool "$AGENT_POOL" \
    --agent "$AGENT_NAME" --work _work --replace --acceptTeeEula \
    > /tmp/ado-agent-config.log 2>&1 < /dev/null &
  echo \$! > /tmp/ado-agent-config.pid
'
EOF
)

az vm run-command invoke -g "$RESOURCE_GROUP" -n "$VM_NAME" \
  --command-id RunShellScript --scripts "$REMOTE_START" -o none

echo "Waiting for device-code output from $VM_NAME..."
DEVICE_LOG=""
for _ in $(seq 1 30); do
  DEVICE_LOG=$(az vm run-command invoke -g "$RESOURCE_GROUP" -n "$VM_NAME" \
    --command-id RunShellScript \
    --scripts "sudo cat /tmp/ado-agent-config.log 2>/dev/null || true" \
    --query "value[0].message" -o tsv 2>/dev/null || true)
  if grep -Eqi 'device|code|microsoft.com/devicelogin' <<<"$DEVICE_LOG"; then
    break
  fi
  sleep 5
done

if [[ -z "$DEVICE_LOG" ]]; then
  echo "No registration output received. Inspect the VM Run Command result and /tmp/ado-agent-config.log."
  exit 1
fi

echo "$DEVICE_LOG"
echo
echo "Complete the device login shown above using an Azure DevOps agent-pool administrator."
read -rp "After completing device login, press Enter to continue: "

for _ in $(seq 1 60); do
  STATUS=$(az vm run-command invoke -g "$RESOURCE_GROUP" -n "$VM_NAME" \
    --command-id RunShellScript \
    --scripts "sudo test -f /opt/ado-agent/.agent && echo REGISTERED || (sudo kill -0 \$(cat /tmp/ado-agent-config.pid) 2>/dev/null && echo WAITING || echo FAILED)" \
    --query "value[0].message" -o tsv 2>/dev/null || true)
  if grep -q REGISTERED <<<"$STATUS"; then
    break
  fi
  if grep -q FAILED <<<"$STATUS"; then
    echo "Agent registration failed. Inspect /tmp/ado-agent-config.log on the VM."
    exit 1
  fi
  sleep 5
done

az vm run-command invoke -g "$RESOURCE_GROUP" -n "$VM_NAME" \
  --command-id RunShellScript \
  --scripts "sudo /opt/ado-agent/svc.sh install azureagent && sudo /opt/ado-agent/svc.sh start" \
  -o none

echo "Agent registration and service installation completed for $VM_NAME."
