#!/bin/bash

JSONPATH="'{range .items[*]}
  {.metadata.name}{\"\\t\"} \
  {.status.nodeInfo.kubeletVersion}{\"\\t\"} \
  {.status.nodeInfo.osImage}{\"\\t\"} \
  {.status.nodeInfo.architecture}{\"\\t\"} \
  {.status.conditions[?(@.status==\"True\")].type}{\"\\n\"} \
{end}'"

notReady() {
  # Get the list of nodes and their statuses  
  NODES="$(kubectl get nodes -o jsonpath="$JSONPATH")"
  # Example output:
  # master-node   Ready
  # worker-node   Ready MemoryPressure
  # worker-node2  EtcVoter Ready
  # worker-node3  
  NOT_READY="$(echo "$NODES" | grep -v "Ready" | tr -d ["\t","\n"," ","'"] || true)"
  if [ -n "$NOT_READY" ]; then
    # Some nodes are not ready
    return 0
  else
    # All nodes are ready
    return 1
  fi
}

TIMEOUT=5 # 5 minutes
INTERVAL=10 # 10 seconds
START_TIME=$(date +%s)
END_TIME=$((start_time + TIMEOUT * 60))

while notReady; do
  if [[ $(date +%s) < $END_TIME ]]; then
    sleep $INTERVAL;
  else
    kubectl get nodes -o jsonpath="$JSONPATH" || true
    exit 1
  fi
done
exit 0
