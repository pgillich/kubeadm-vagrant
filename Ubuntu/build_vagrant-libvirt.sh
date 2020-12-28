#!/bin/bash

VAGRANT_VERSION=2.2.14
VAGRANT_LIBVIRT_VERSION=0.3.0
IMAGE_TAG=vagrant-libvirt:latest

rm -rf /tmp/vagrant-libvirt

git clone https://github.com/vagrant-libvirt/vagrant-libvirt.git /tmp/vagrant-libvirt
cd /tmp/vagrant-libvirt
git checkout tags/${VAGRANT_LIBVIRT_VERSION}

sed -i -e '/RUN vagrant plugin install/i\' -e "RUN vagrant plugin install vagrant-mutate\nRUN vagrant plugin install vagrant-hostmanager" Dockerfile
echo -e '\nENV VAGRANT_DEFAULT_PROVIDER=libvirt' >>Dockerfile

DOCKER_BUILDKIT=1 docker build -t ${IMAGE_TAG} --build-arg VAGRANT_VERSION=${VAGRANT_VERSION} .
