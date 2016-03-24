#!/bin/bash
VERSION=1.3.0
mkdir -p /tmp/vagrant-cloudstack-build_rpm.$$/vagrant-cloudstack-$VERSION
cp -r . /tmp/vagrant-cloudstack-build_rpm.$$/vagrant-cloudstack-$VERSION/
tar -C /tmp/vagrant-cloudstack-build_rpm.$$/ -czf ~/rpmbuild/SOURCES/vagrant-cloudstack-$VERSION.tar.gz vagrant-cloudstack-$VERSION
rpmbuild --define "gemver $VERSION" -bb vagrant-cloudstack.spec
rm -rf /tmp/vagrant-cloudstack-build_rpm.$$
