#!/usr/bin/env bats

vagrant_up() {
  bundle exec vagrant up
}

vagrant_destroy() {
  bundle exec vagrant destroy -f
}

vagrant_ssh_list_rsync_dir() {
  bundle exec vagrant ssh -c "ls /vagrant; echo;"
}

teardown() {
  run vagrant_destroy
}

@test "current directory is rsynced to VM" {
  run vagrant_up
  [ $status = 0 ]

  run vagrant_ssh_list_rsync_dir
  echo $output
  [ $status = 0 ]
  [[ "$output" =~ "run_tests.sh" ]]

  run vagrant_destroy
  [ $status = 0 ]
}

