require 'rubygems'
require 'bundler/setup'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:functionaltest) do |t|
  t.pattern = "*_spec.rb"
  t.rspec_opts = "-fd"
end

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

  # Name must match folder beneath functional-tests/
  functional_test_names = %w(vmlifecycle networking rsync)
  separate_test_names   = %w(basic)

  desc "Check for required enviroment variables for functional testing"
  task :check_environment do
    missing_env=false
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
      'WINDOWS_TEMPLATE_NAME',
      'VPC_PUBLIC_IP',
      'VPC_TIER_NAME',
      'VR_PUBLIC_IP',
      'VR_NETWORK_NAME',
      'DISK_OFFERING_NAME'
    ].each do |var|
      if ENV[var].nil?
        puts "Please set environment variable #{var}."
        missing_env=true
      end
    end
    exit 1 if missing_env
  end

  desc "Run all functional tests"
  task :all => [ :check_environment ] do
    functional_test_names.each do |test_name|
      Rake::Task["functional_tests:#{test_name}"].invoke
    end
  end


  functional_test_names.each do |test_dir_name|
    desc "Run functional test: #{test_dir_name}"
    task test_dir_name => [ :check_environment ] do
      Dir.chdir("#{File.expand_path('../', __FILE__)}/functional-tests/#{test_dir_name}/")
      Dir.glob("Vagrantfile*", File::FNM_CASEFOLD).each do |vagrant_file|

        ENV['TEST_NAME'] = "vagrant_cloudstack_functional_test-#{test_dir_name}"
        ENV['VAGRANT_VAGRANTFILE'] = vagrant_file
        puts "Running RSpec tests in folder : #{test_dir_name}"
        puts "Using Vagrant file            : #{ENV['VAGRANT_VAGRANTFILE']}"
        Rake::Task[:functionaltest].execute
      end
    end
  end

  separate_test_names.each do |test_dir_name|
    desc "Run functional test: #{test_dir_name}"
    task test_dir_name => [ :check_environment ] do
      Dir.chdir("#{File.expand_path('../', __FILE__)}/functional-tests/#{test_dir_name}/")
      Dir.glob("Vagrantfile*", File::FNM_CASEFOLD).each do |vagrant_file|

        ENV['TEST_NAME'] = "vagrant_cloudstack_functional_test-#{test_dir_name}"
        ENV['VAGRANT_VAGRANTFILE'] = vagrant_file
        puts "Running RSpec tests in folder : #{test_dir_name}"
        puts "Using Vagrant file            : #{ENV['VAGRANT_VAGRANTFILE']}"
        Rake::Task[:functionaltest].execute
      end
    end
  end


end
