source 'https://rubygems.org'

gemspec

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  gem 'vagrant', git: 'git://github.com/mitchellh/vagrant.git'
  gem 'coveralls', require: false
  gem 'simplecov', require: false
  gem 'rspec-core'
  gem 'rspec-collection_matchers'
  gem 'rspec-expectations'
  gem 'rspec-its'
  gem 'rspec-mocks'
  gem 'pry-byebug'
end

group :plugins do
  gem 'vagrant-cloudstack', path: '.'
end
