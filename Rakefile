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
  functional_test_names = [
    'vmlifecycle',
    'rsync'
  ]

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
end
