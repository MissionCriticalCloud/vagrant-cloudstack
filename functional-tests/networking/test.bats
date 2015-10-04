#!/usr/bin/env bats

vagrant_up() {
  bundle exec vagrant up
}

vagrant_destroy() {
  bundle exec vagrant destroy -f
}

teardown() {
  run vagrant_destroy
}

@test "create and destroy vm" {
  run vagrant_up
  [ $status = 0 ]

  run vagrant_destroy
  [ $status = 0 ]
}

