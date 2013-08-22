source "https://rubygems.org"

gem 'nokogiri', "= 1.5.10"
gem 'fog', '= 1.15.0'
gemspec

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  gem "vagrant", :git => "git://github.com/mitchellh/vagrant.git"
end
