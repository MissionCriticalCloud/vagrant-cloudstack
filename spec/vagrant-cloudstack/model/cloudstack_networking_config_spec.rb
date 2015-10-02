require 'spec_helper'
require 'vagrant-cloudstack/model/cloudstack_networking_config'

include VagrantPlugins::Cloudstack::Model

class ConfigMock
  attr_accessor :static_nat,
                :pf_ip_address_id,
                :pf_ip_address,
                :pf_public_port,
                :pf_public_rdp_port,
                :pf_public_port_randomrange,
                :pf_private_port,
                :pf_private_rdp_port,
                :pf_open_firewall,
                :pf_trusted_networks,
                :port_forwarding_rules,
                :firewall_rules,
                :security_groups,
                :private_ip_address

  def initialize(values)
    values.each_pair do |key, value|
      send(:"#{key}=", value)
    end
  end
end

describe CloudstackNetworkingConfig do
  describe '#has_portforwarding?' do
    it 'returns true if pf_ip_address_id and pf_public_port are defined' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_ip_address_id' => 'some ip address id',
          'pf_public_port'   => 'some public port'
        }
      ))

      expect(config.has_portforwarding?).to eq(true)
    end

    it 'returns true if pf_ip_address_id and pf_public_port_randomrange are defined' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_ip_address_id'             => 'some ip address id',
          'pf_public_port_randomrange'   => { :start => 1, :end => 2 }
        }
      ))

      expect(config.has_portforwarding?).to eq(true)
    end

    it 'returns true if pf_ip_address and pf_public_port are defined' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_ip_address'    => 'some ip address',
          'pf_public_port'   => 'some public port'
        }
      ))

      expect(config.has_portforwarding?).to eq(true)
    end

    it 'returns true if pf_ip_address_id and pf_public_port_randomrange are defined' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_ip_address'                => 'some ip address',
          'pf_public_port_randomrange'   => { :start => 1, :end => 2 }
        }
      ))

      expect(config.has_portforwarding?).to eq(true)
    end
  end

  describe '#port_forwarding_rule' do
    it 'returns a SSH port forwarding rule for linux guests' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_ip_address_id' => 'some ip address id',
          'pf_ip_address'    => 'some ip address',
          'pf_public_port'   => 2222,
          'pf_private_port'  => 22,
          'pf_open_firewall' => true
        }
      ))

      expect(config.port_forwarding_rule(:linux)).to eq(
        {
          :ipaddressid  => 'some ip address id',
          :ipaddress    => 'some ip address',
          :protocol     => 'tcp',
          :publicport   => 2222,
          :privateport  => 22,
          :openfirewall => true
        }
      )
    end

    it 'returns a RDP port forwarding rule for linux guests' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_ip_address_id'     => 'some ip address id',
          'pf_ip_address'        => 'some ip address',
          'pf_open_firewall'     => true
        }
      ))
      config.pf_public_rdp_port  = 33890
      config.pf_private_rdp_port = 3389

      expect(config.port_forwarding_rule(:windows)).to eq(
        {
          :ipaddressid  => 'some ip address id',
          :ipaddress    => 'some ip address',
          :protocol     => 'tcp',
          :publicport   => 33890,
          :privateport  => 3389,
          :openfirewall => true
        }
      )
    end
  end

  describe '#portforwarding_port_range' do
    it 'returns a ruby range value' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_public_port_randomrange'   => { :start => 1, :end => 2 }
        }
      ))

      expect(config.portforwarding_port_range).to eq(1...2)
    end
  end

  describe '#should_open_firewall_to_trusted_networks?' do
    it 'returns true if pf_trusted_networks is not empty and pf_open_firewall is false' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_trusted_networks' => ['some network'],
          'pf_open_firewall' => false
        }
      ))

      expect(config.should_open_firewall_to_trusted_networks?).to eq(true)
    end

    it 'returns false if pf_trusted_networks is empyy' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new({}))

      expect(config.should_open_firewall_to_trusted_networks?).to eq(false)
    end

    it 'returns false if pf_open_firewall is true' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_open_firewall' => true
        }
      ))

      expect(config.should_open_firewall_to_trusted_networks?).to eq(false)
    end
  end

  describe '#firewall_rules' do
    it 'returns explicit firewall rules only' do
      rule1 = {
        :ipaddressid => 'some ip address id',
        :ipaddress   => 'some ip address',
        :cidrlist    => 'some cidrlist',
        :protocol    => 'tcp',
        :startport   => 1,
        :endport     => 2
      }
      rule2 = {
        :ipaddressid => 'some other ip address id',
        :ipaddress   => 'some other ip address',
        :cidrlist    => 'some other cidrlist',
        :protocol    => 'tcp',
        :startport   => 10,
        :endport     => 20
      }
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'firewall_rules' => [rule1, rule2]
        }
      ))

      actual = config.firewall_rules

      expect(actual).to have_exactly(2).items
      expect(actual).to contain_exactly(rule1, rule2)
    end

    it 'enhances rules with missing attributes' do
      rule1 = {
        :ipaddressid => 'some ip address id',
        :ipaddress   => 'some ip address',
        :cidrlist    => 'first trusted net,second trusted net',
        :protocol    => 'tcp',
        :startport   => 1,
        :endport     => 1
      }
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'firewall_rules'      => [{ :startport => 1 }],
          'pf_ip_address_id'    => 'some ip address id',
          'pf_ip_address'       => 'some ip address',
          'pf_trusted_networks' => ['first trusted net', 'second trusted net'],
          'pf_open_firewall'    => true
        }
      ))

      actual = config.firewall_rules

      expect(actual).to have_exactly(1).items
      expect(actual).to include(rule1)
    end

    it 'adds rules from portforwardings' do
      rule1 = {
        :ipaddressid => 'some ip address id',
        :ipaddress   => 'some ip address',
        :cidrlist    => 'first trusted net,second trusted net',
        :protocol    => 'tcp',
        :startport   => 1,
        :endport     => 1
      }
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_ip_address_id'    => 'some ip address id',
          'pf_ip_address'       => 'some ip address',
          'pf_public_port'      => 1,
          'pf_trusted_networks' => ['first trusted net', 'second trusted net'],
          'pf_open_firewall'    => false
        }
      ))

      actual = config.firewall_rules

      expect(actual).to have_exactly(1).items
      expect(actual).to include(rule1)
    end
  end

  describe '#port_forwarding_rules' do
    it 'returns the portforwarding rules' do
      rule1 = {
        :ipaddressid  => 'some ip address id',
        :ipaddress    => 'some ip address',
        :protocol     => 'tcp',
        :publicport   => 1,
        :privateport  => 2,
        :openfirewall => true
      }
      rule2 = {
        :ipaddressid  => 'some other ip address id',
        :ipaddress    => 'some other ip address',
        :protocol     => 'tcp',
        :publicport   => 10,
        :privateport  => 20,
        :openfirewall => false
      }
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'port_forwarding_rules' => [rule1, rule2]
        }
      ))

      actual = config.port_forwarding_rules(:linux)

      expect(actual).to have_exactly(2).items
      expect(actual).to include(rule1, rule2)
    end

    it 'enhances the portforwarding rules' do
      rule1 = {
        :ipaddressid  => 'some ip address id',
        :ipaddress    => 'some ip address',
        :protocol     => 'tcp',
        :publicport   => 1,
        :privateport  => 1,
        :openfirewall => true
      }
      rule2 = {
        :ipaddressid  => 'some ip address id',
        :ipaddress    => 'some ip address',
        :protocol     => 'tcp',
        :publicport   => 2,
        :privateport  => 2,
        :openfirewall => true
      }
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'port_forwarding_rules' => [{ :publicport => 1 }, { :privateport => 2 }],
          'pf_ip_address_id'      => 'some ip address id',
          'pf_ip_address'         => 'some ip address',
          'pf_open_firewall'      => true
        }
      ))

      actual = config.port_forwarding_rules(:linux)

      expect(actual).to have_exactly(2).items
      expect(actual).to include(rule1, rule2)
    end

    it 'introduces a default portforwarding rule' do
      rule1 = {
        :ipaddressid  => 'some ip address id',
        :ipaddress    => 'some ip address',
        :protocol     => 'tcp',
        :publicport   => 2222,
        :privateport  => 22,
        :openfirewall => true
      }
      config = CloudstackNetworkingConfig.new(ConfigMock.new(
        {
          'pf_ip_address_id' => 'some ip address id',
          'pf_ip_address'    => 'some ip address',
          'pf_public_port'   => 2222,
          'pf_private_port'  => 22,
          'pf_open_firewall' => true
        }
      ))

      actual = config.port_forwarding_rules(:linux)

      expect(actual).to have_exactly(1).items
      expect(actual).to include(rule1)
    end
  end

  describe '#udpate_public_port' do
    it 'updates the SSH public port' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new({}))

      config.udpate_public_port(:linux, 1)

      expect(config.pf_public_port).to eq(1)
    end

    it 'updates the RDP public port' do
      config = CloudstackNetworkingConfig.new(ConfigMock.new({}))

      config.udpate_public_port(:windows, 1)

      expect(config.pf_public_rdp_port).to eq(1)
    end
  end
end
