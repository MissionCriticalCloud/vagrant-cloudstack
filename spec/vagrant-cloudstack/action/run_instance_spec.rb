require 'spec_helper'
require 'vagrant-cloudstack/action/run_instance'
require 'vagrant-cloudstack/config'
require 'vagrant-cloudstack/provider'

require 'vagrant'
require 'fog'


ZONE_NAME = 'Zone Name'
ZONE_ID = 'Zone UUID'
SERVICE_OFFERING_NAME = 'Service Offering Name'
SERVICE_OFFERING_ID = 'Service Offering UUID'
TEMPLATE_NAME = 'Template Name'
TEMPLATE_ID = 'Template UUID'
NETWORK_NAME = 'Network Name'
NETWORK_ID = 'Network UUID'
DISPLAY_NAME = 'Display Name'

SERVER_ID = 'Server UUID'
NETWORK_TYPE = 'Advanced'
SECURITY_GROUPS_ENABLED = false


describe VagrantPlugins::Cloudstack::Action::RunInstance do
  let(:action) { VagrantPlugins::Cloudstack::Action::RunInstance.new(app, env) }


  describe '#run_instance in advanced zone' do
    subject { action.call(env) }
    let(:app) { double('Vagrant::Action::Warden')}

    let(:provider_config) do
      config = VagrantPlugins::Cloudstack::Config.new
      config.domain_config :cloudstack do |cfg|
        cfg.zone_name = ZONE_NAME
        cfg.network_name = NETWORK_NAME
        cfg.service_offering_name = SERVICE_OFFERING_NAME
        cfg.template_name = TEMPLATE_NAME
        cfg.ssh_key = '/path/to/ssh/key/file'
        cfg.display_name = DISPLAY_NAME
      end
      config.finalize!
      config.get_domain_config(:cloudstack)
    end

    let(:machine) { double('Vagrant::Machine') }

    let(:cloudstack_zone) {
      instance_double('Fog::Compute::Cloudstack::Zone',
                      id: ZONE_ID,
                      name: ZONE_NAME,
                      network_type: NETWORK_TYPE,
                      security_groups_enabled: SECURITY_GROUPS_ENABLED)
    }
    let(:cloudstack_compute) { double('Fog::Compute::Cloudstack') }
    let(:servers) { double('Fog::Compute::Cloudstack::Servers') }
    let(:server) { double('Fog::Compute::Cloudstack::Server') }
    let(:ui) { double('Vagrant::UI::Prefixed') }
    let(:root_path) { double('Pathname') }
    let(:env) do
      {
          root_path: root_path,
          ui: ui,
          machine: machine,
          cloudstack_compute: cloudstack_compute
      }
    end

    before(:each) do
      allow(app).to receive(:call).and_return(true)

      allow(ui).to receive(:info)
      allow(ui).to receive(:warn)
      allow(ui).to receive(:detail)

      allow(machine).to receive(:provider_config).and_return(provider_config)
      allow(machine).to receive(:id=).with(SERVER_ID)
      allow(machine).to receive(:communicate).and_return('')
      allow(machine).to receive_message_chain(:communicate, :ready?).and_return(true)
      allow(machine).to receive_message_chain(:config, :vm, :box).and_return(TEMPLATE_NAME)

      allow(cloudstack_compute).to receive(:servers).and_return(servers)
      allow(cloudstack_compute).to receive(:volumes).and_return([])

      allow(server).to receive(:id).and_return(SERVER_ID)
      allow(server).to receive(:wait_for).and_return(ready = true)
      allow(server).to receive(:password_enabled).and_return(false)

      list_zones_response = {
        "listzonesresponse"=>{
          "count"=>1,
          "zone"=>[
            {
              "tags"=>[],
              "id"=>ZONE_ID,
              "name"=>ZONE_NAME,
              "networktype"=>NETWORK_TYPE,
              "securitygroupsenabled"=>SECURITY_GROUPS_ENABLED
            }
          ]
        }
      }
      allow(cloudstack_compute).to receive(:send).with(:list_zones, :available => true ).and_return(list_zones_response)

      list_service_offerings_response = {
        "listserviceofferingsresponse"=>{
          "count"=>1,
          "serviceoffering"=>[
            {
              "id"=>SERVICE_OFFERING_ID,
              "name"=>SERVICE_OFFERING_NAME,
              "displaytext"=>"Display version of #{SERVICE_OFFERING_NAME}",
            }
          ]
        }
      }
      allow(cloudstack_compute).to receive(:send).with(:list_service_offerings, listall: true)
        .and_return(list_service_offerings_response)

      list_templates_response = {
        "listtemplatesresponse"=>{
          "count"=>1,
          "template"=>[
            {
              "id"=>TEMPLATE_ID,
              "name"=>TEMPLATE_NAME
            }
          ]
        }
      }
      allow(cloudstack_compute).to receive(:send)
        .with(:list_templates, zoneid: ZONE_ID, templatefilter: 'executable', listall: true)
        .and_return(list_templates_response)

      allow(cloudstack_compute).to receive(:zones).and_return([cloudstack_zone])

      list_networks = {
        "listnetworksresponse"=>{
          "count"=>1,
          "network"=>[
            {
              "id"=>NETWORK_ID,
              "name"=>NETWORK_NAME,
            }
          ]
        }
      }
      allow(cloudstack_compute).to receive(:send)
                                       .with(:list_networks, {})
                                       .and_return(list_networks)

      create_servers_parameters = {
          :display_name=>DISPLAY_NAME,
          :group=>nil,
          :zone_id=>ZONE_ID,
          :flavor_id=>SERVICE_OFFERING_ID,
          :image_id=>TEMPLATE_ID,
          "network_ids"=>NETWORK_ID
      }
      allow(servers).to receive(:create).with(create_servers_parameters).and_return(server)
    end

    context 'start a simple VM' do
      it 'starts a vm' do
        should eq true
      end
    end
  end
end
