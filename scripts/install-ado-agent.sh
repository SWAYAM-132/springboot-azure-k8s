#!/usr/bin/env bash
set -euo pipefail

# Run on the VM as the non-root agent account.
# Device-code registration avoids storing a PAT or client secret on the VM.
: "${ADO_ORG_URL:?Set ADO_ORG_URL}"
: "${ADO_AGENT_POOL:?Set ADO_AGENT_POOL}"
: "${ADO_AGENT_NAME:=$(hostname)}"
: "${ADO_AGENT_VERSION:=5.281.1}"

AGENT_HOME="${AGENT_HOME:-/opt/ado-agent}"
sudo apt-get update
sudo apt-get install -y curl jq tar ca-certificates

sudo mkdir -p "${AGENT_HOME}"
sudo chown "$(id -u):$(id -g)" "${AGENT_HOME}"
cd "${AGENT_HOME}"

curl -fsSLO "https://vstsagentpackage.azureedge.net/agent/${ADO_AGENT_VERSION}/vsts-agent-linux-x64-${ADO_AGENT_VERSION}.tar.gz"
tar -xzf "vsts-agent-linux-x64-${ADO_AGENT_VERSION}.tar.gz"
rm -f "vsts-agent-linux-x64-${ADO_AGENT_VERSION}.tar.gz"

./config.sh \
  --url "${ADO_ORG_URL}" \
  --auth AAD \
  --pool "${ADO_AGENT_POOL}" \
  --agent "${ADO_AGENT_NAME}" \
  --work "_work" \
  --replace \
  --acceptTeeEula

sudo ./svc.sh install "$(whoami)"
sudo ./svc.sh start
