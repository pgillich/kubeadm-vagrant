#!/bin/bash -x

POD_NAMESPACE=$1
POD_NAME=$2
CONTAINER=$3

TCPDUMP_DIR=/tmp/tcpdump

TCPDUMP=4.99.0
LIBPCAP=1.10.0

if [ ! -f "${TCPDUMP_DIR}/tcpdump" ]; then
    sudo apt -y install gcc flex byacc bison

    mkdir -p ${TCPDUMP_DIR}
    cd ${TCPDUMP_DIR}

    wget http://www.tcpdump.org/release/libpcap-${LIBPCAP}.tar.gz
    tar zxvf libpcap-${LIBPCAP}.tar.gz
    cd libpcap-${LIBPCAP}
    ./configure --with-pcap=linux
    make
    cd ..

    wget http://www.tcpdump.org/release/tcpdump-${TCPDUMP}.tar.gz
    tar zxvf tcpdump-${TCPDUMP}.tar.gz
    cd tcpdump-${TCPDUMP}
    export ac_cv_linux_vers=2
    export CFLAGS=-static
    export CPPFLAGS=-static
    export LDFLAGS=-static
    ./configure
    make
    cp tcpdump ..
    cd ..
fi

if [ -n "${CONTAINER}" ]; then
    CONTAINER_OPT="-c ${CONTAINER}"
fi

kubectl cp -n ${POD_NAMESPACE} ${CONTAINER_OPT} ${TCPDUMP_DIR}/tcpdump ${POD_NAME}:/tmp/
kubectl exec -t -n ${POD_NAMESPACE} ${CONTAINER_OPT} ${POD_NAME} -- /tmp/tcpdump -i eth0 -s 0 -w - | wireshark -k -i -
