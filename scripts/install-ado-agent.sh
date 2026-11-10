#!/usr/bin/env bash
set -euo pipefail

# Run on the VM as the non-root agent account after securely obtaining a
# one-time Azure DevOps PAT with Agent Pools (read, manage) scope.
# Never commit the PAT or pass it as a command-line argument.
: "${ADO_ORG_URL:?Set ADO_ORG_URL}"
: "${ADO_AGENT_POOL:?Set ADO_AGENT_POOL}"
: "${ADO_AGENT_NAME:=$(hostname)}"
: "${ADO_AGENT_VERSION:=4.255.0}"

AGENT_HOME="${AGENT_HOME:-/opt/ado-agent}"
sudo apt-get update
sudo apt-get install -y curl jq tar ca-certificates

sudo mkdir -p "${AGENT_HOME}"
sudo chown "$(id -u):$(id -g)" "${AGENT_HOME}"
cd "${AGENT_HOME}"

curl -fsSLO "https://vstsagentpackage.azureedge.net/agent/${ADO_AGENT_VERSION}/vsts-agent-linux-x64-${ADO_AGENT_VERSION}.tar.gz"
tar -xzf "vsts-agent-linux-x64-${ADO_AGENT_VERSION}.tar.gz"
rm -f "vsts-agent-linux-x64-${ADO_AGENT_VERSION}.tar.gz"

read -rsp "Azure DevOps agent registration PAT: " ADO_AGENT_PAT
echo
export ADO_AGENT_PAT
./config.sh --unattended \
  --url "${ADO_ORG_URL}" \
  --auth pat \
  --token "${ADO_AGENT_PAT}" \
  --pool "${ADO_AGENT_POOL}" \
  --agent "${ADO_AGENT_NAME}" \
  --work "_work" \
  --replace \
  --acceptTeeEula
unset ADO_AGENT_PAT

sudo ./svc.sh install "$(whoami)"
sudo ./svc.sh start
