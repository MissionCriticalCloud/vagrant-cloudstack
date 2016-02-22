require 'rubygems'
require 'bundler/setup'
require 'rspec/core/rake_task'

# Immediately sync all stdout so that tools like buildbot can
# immediately load in the output.
$stdout.sync = true
$stderr.sync = true

# Change to the directory of this file.
Dir.chdir(File.expand_path("../", __FILE__))

# This installs the tasks that help with gem creation and
# publishing.
Bundler::GemHelper.install_tasks

# Install the `spec` task so that we can run tests.
RSpec::Core::RakeTask.new

# Default task is to run the unit tests
task :default => "spec"


namespace :functional_tests do
  desc "Check for required enviroment variables for functional testing"
  task :check_environment do
    [
      'CLOUDSTACK_API_KEY',
      'CLOUDSTACK_SECRET_KEY',
      'CLOUDSTACK_HOST',
      'PUBLIC_SOURCE_NAT_IP',
      'NETWORK_NAME',
      'SERVICE_OFFERING_NAME',
      'ZONE_NAME',
      'PUBLIC_WINRM_PORT',
      'PRIVATE_WINRM_PORT',
      'PUBLIC_SSH_PORT',
      'PRIVATE_SSH_PORT',
      'SOURCE_CIDR',
      'LINUX_TEMPLATE_NAME',
      'WINDOWS_TEMPLATE_NAME'
    ].each do |var|
      if ENV[var].nil?
        puts "#{var} not set. Quitting"
        exit 1
      end
    end
  end

  desc "Run all functional tests"
  task :all => [ :check_environment ] do
    Rake::Task['functional_tests:vmlifecycle'].invoke
    Rake::Task['functional_tests:rsync'].invoke
  end

  desc "Run functional test: VM Life cycle"
  task :vmlifecycle => [ :check_environment ] do
    Dir.chdir(File.expand_path("../", __FILE__))
    test_dir_name='vmlifecycle'
    Dir.chdir("functional-tests/#{test_dir_name}/")
    Dir.glob("Vagrantfile*", File::FNM_CASEFOLD).each do |vagrant_file|
      puts ""
      puts "Testing #{test_dir_name}"
      puts ""
      ENV['TEST_NAME'] = "vagrant_cloudstack_functional_test-#{test_dir_name}"
      ENV['VAGRANT_VAGRANTFILE'] = vagrant_file
      sh %{ vagrant up }
      sh %{ vagrant destroy -f }
    end
    Dir.chdir(File.expand_path("../", __FILE__))
  end

  desc "Run functional test: RSync"
  task :rsync => [ :check_environment ] do
    Dir.chdir(File.expand_path("../", __FILE__))
    test_dir_name='rsync'
    Dir.chdir("functional-tests/#{test_dir_name}/")
    Dir.glob("Vagrantfile*", File::FNM_CASEFOLD).each do |vagrant_file|
      puts ""
      puts "Testing #{test_dir_name}"
      puts ""
      ENV['TEST_NAME'] = "vagrant_cloudstack_functional_test-#{test_dir_name}"
      ENV['VAGRANT_VAGRANTFILE'] = vagrant_file
      sh %{ vagrant up }
      sh %{ vagrant ssh -c "ls /vagrant; echo;" }
      sh %{ vagrant destroy -f }
    end
    Dir.chdir(File.expand_path("../", __FILE__))
  end
end
