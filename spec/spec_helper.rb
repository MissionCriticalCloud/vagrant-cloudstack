require 'simplecov'
require 'coveralls'
require 'rspec/its'

Dir["#{__dir__}/vagrant-cloudstack/support/**/*.rb"].each { |f| require f }

SimpleCov.start
Coveralls.wear!
