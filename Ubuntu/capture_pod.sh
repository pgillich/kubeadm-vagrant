#!/bin/bash

POD_NAMESPACE=$1
POD_NAME=$2

POD_NODE=$(kubectl get pod ${POD_NAME} --no-headers -o custom-columns=NODE:.spec.nodeName)

ssh -F ssh-config ${POD_NODE} 'POD_ID=`sudo crictl pods --namespace '${POD_NAMESPACE}' --name '${POD_NAME}' -q`;
CONTAINER_ID=`sudo crictl ps --pod $POD_ID -q`;
CONTAINER_PID=`sudo docker inspect --format '{{.State.Pid}}' ${CONTAINER_ID}`;
sudo nsenter -t ${CONTAINER_PID} -n /bin/bash -xec "tcpdump -i eth0 -s 0 -w -"' | wireshark -k -i -
