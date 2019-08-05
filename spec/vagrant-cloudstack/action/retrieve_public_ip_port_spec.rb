require 'spec_helper'
require 'vagrant-cloudstack/action/read_transport_info'
require 'vagrant-cloudstack/config'
require 'fog/cloudstack'

describe VagrantPlugins::Cloudstack::Action::ReadTransportInfo do
  let(:action) {VagrantPlugins::Cloudstack::Action::ReadTransportInfo.new }

  describe '#retrieve_public_ip_port' do
    subject { action.retrieve_public_ip_port(cloudstack_compute, domain_config, machine) }

    let(:cloudstack_compute) { double('Fog::Compute::Cloudstack') }
    let(:machine) { double('Vagrant::Machine')}

    let(:data_dir) { double('Pathname') }
    let(:pf_public_port_file) { double('Pathname') }

    let(:pf_ip_address) { 'ip_address_in_config' }
    let(:pf_ip_address_from_server) { 'ip_address_from_server' }
    let(:pf_ip_address_id) { 'ID of ip_address_in_config' }
    let(:pf_public_port) { 'public_port_in_config' }
    let(:pf_public_port_from_file) { 'public_port_from_file' }

    let(:domain_config) do
      config = VagrantPlugins::Cloudstack::Config.new
      config.domain_config :cloudstack do |cfg|
        cfg.pf_ip_address = pf_ip_address
        cfg.pf_public_port = pf_public_port
        cfg.pf_ip_address_id = pf_ip_address_id
      end
      config.finalize!
      config.get_domain_config(:cloudstack)
    end

    context 'without both ip address and port in config' do
      it 'retrieves those configured values' do
        should eq [pf_ip_address, pf_public_port]
      end
    end

    context 'port not configured' do
      let(:pf_public_port) { nil }

      it 'retrieves the active port stored on filesystem' do
        expect(machine).to receive(:data_dir).and_return(data_dir)
        expect(data_dir).to receive(:join).and_return(pf_public_port_file)
        expect(pf_public_port_file).to receive(:file?).and_return(true)
        expect(File).to receive(:read).and_return(pf_public_port_from_file)

        expect(subject).to eq [pf_ip_address, pf_public_port_from_file]
      end
    end

    context 'only ID of ip address specified (and public port)' do
      let(:pf_ip_address) { nil }

      it 'resolves, and returns, the ip address from the ID' do
        response = {
          'listpublicipaddressesresponse' => {
            'count' =>1,
            'publicipaddress' =>[{
              'id' => pf_ip_address_id,
              'ipaddress' => pf_ip_address_from_server,
              'allocated' => '2016-05-06T13:58:04+0200',
              'zoneid' => 'UUID',
              'zonename' => 'Name',
              'issourcenat' =>false,
              'account' => 'Name',
              'domainid' => 'UUID',
              'domain' => 'Name',
              'forvirtualnetwork' =>true,
              'isstaticnat' =>false,
              'issystem' =>false,
              'associatednetworkid' => 'UUID',
              'associatednetworkname' => 'Name',
              'networkid' => 'UUID',
              'aclid' => 'UUID',
              'state' => 'Allocated',
              'physicalnetworkid' => 'UUID',
              'vpcid' => 'UUID',
              'tags' =>[],
              'isportable' =>false
            }]
          }
        }
        expect(cloudstack_compute).to receive(:list_public_ip_addresses)
          .with(:id => pf_ip_address_id)
          .and_return(response)

        expect(subject).to eq [pf_ip_address_from_server, pf_public_port]
      end
    end
  end
end
