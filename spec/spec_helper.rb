require 'simplecov'
require 'coveralls'
require 'rspec/its'
require 'i18n'

Dir["#{__dir__}/vagrant-cloudstack/support/**/*.rb"].each { |f| require f }

SimpleCov.start
Coveralls.wear!

ZONE_NAME = 'Zone Name'.freeze
ZONE_ID = 'Zone UUID'.freeze
SERVICE_OFFERING_NAME = 'Service Offering Name'.freeze
SERVICE_OFFERING_ID = 'Service Offering UUID'.freeze
TEMPLATE_NAME = 'Template Name'.freeze
TEMPLATE_ID = 'Template UUID'.freeze
NETWORK_NAME = 'Network Name'.freeze
NETWORK_ID = 'Network UUID'.freeze
VPC_ID = 'VPC UUID'.freeze
DISPLAY_NAME = 'Display Name'.freeze
DISK_OFFERING_NAME = 'Disk Offering Name'.freeze
DISK_OFFERING_ID = 'Disk Offering UUID'.freeze

SERVER_ID = 'Server UUID'.freeze
NETWORK_TYPE = 'Advanced'.freeze
SECURITY_GROUPS_ENABLED = false

PF_IP_ADDRESS = 'Public IP for port forwarding'.freeze
PF_IP_ADDRESS_ID = 'UUID of Public IP for port forwarding'.freeze
PF_TRUSTED_NETWORKS = 'IP Ranges to allow public access from'.freeze
PF_RANDOM_START = 49_152
GUEST_PORT_SSH = 22
GUEST_PORT_WINRM = 5985
GUEST_PORT_RDP = 3389

COMMUNICATOR_SSH = 'VagrantPlugins::CommunicatorSSH::Communicator'.freeze
COMMUNICATOR_WINRM = 'VagrantPlugins::CommunicatorWinRM::Communicator'.freeze

SSH_GENERATED_PRIVATE_KEY = '-----BEGIN RSA PRIVATE KEY-----\nMIICWwIBA==\n-----END RSA PRIVATE KEY-----'.freeze
SSH_GENERATED_KEY_NAME = 'SSH Generated Key Name'.freeze
JOB_ID = 'UUID of a Job'.freeze
PORT_FORWARDING_RULE_ID = 'UUID of port forwarding rule'.freeze
ACL_ID = 'UUID of an ACL'.freeze
GENERATED_PASSWORD = 'Generated password'.freeze
VOLUME_ID = 'UUID of volume'.freeze

I18n.load_path << File.expand_path('../../locales/en.yml', __FILE__)
I18n.reload!
