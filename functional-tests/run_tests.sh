#! /bin/bash

if [ -z "$CLOUDSTACK_HOST" ]; then
  echo "Cloudstack host not set. Quitting"
  exit 1
fi

if [ -z "$CLOUDSTACK_API_KEY" ]; then
  echo "Cloudstack api key not set. Quitting"
  exit 1
fi

if [ -z "$CLOUDSTACK_SECRET_KEY" ]; then
  echo "Cloudstack secret key not set. Quitting"
  exit 1
fi

if [ -z "$PUBLIC_SOURCE_NAT_IP" ]; then
  echo "Public source NAT IP not set. Quitting"
  exit 1
fi

if [ -z "$PUBLIC_SSH_PORT" ]; then
  echo "Public SSH port not set. Quitting"
  exit 1
fi

if [ -z "$ZONE_NAME" ]; then
  echo "Zone name not set. Quitting"
  exit 1
fi

if [ -z "$NETWORK_NAME" ]; then
  echo "Network name not set. Quitting"
  exit 1
fi

if [ -z "$SERVICE_OFFERING_NAME" ]; then
  echo "Service offering name not set. Quitting"
  exit 1
fi

if [ -z "$TEMPLATE_NAME" ]; then
  echo "Template name not set. Quitting"
  exit 1
fi

test_dirs=$(find . -type d -mindepth 1 -maxdepth 1 | grep -v ".vagrant")

for test_dir in $test_dirs; do
  test_dir_name=$(basename $test_dir)
  echo "::::>> Testing $test_dir_name"
  vagrant_files=$(find $test_dir -type f -iname 'Vagrantfile.*')
  for vagrantfile in $vagrant_files; do
    echo "  ::::>> Testing with $(basename $vagrantfile)"
    export TEST_NAME="vagrant_cloudstack_functional_test-${test_dir_name}"
    VAGRANT_VAGRANTFILE=$vagrantfile bats $test_dir
  done
done
