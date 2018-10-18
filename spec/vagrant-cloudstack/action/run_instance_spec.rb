require 'spec_helper'
require 'vagrant-cloudstack/action/run_instance'
require 'vagrant-cloudstack/config'

require 'vagrant'
require 'fog'

describe VagrantPlugins::Cloudstack::Action::RunInstance do
  let(:action) { VagrantPlugins::Cloudstack::Action::RunInstance.new(app, env) }

  let(:create_servers_parameters) do
    {
      :display_name => DISPLAY_NAME,
      :group => nil,
      :zone_id => ZONE_ID,
      :flavor_id => SERVICE_OFFERING_ID,
      :image_id => TEMPLATE_ID,
      'network_ids' => NETWORK_ID
    }
  end

  let(:fake_job_result) do
    {
      'queryasyncjobresultresponse' => {
        'jobstatus' => 1,
        'jobresult' => {
          'portforwardingrule' => {
            'id' => PORT_FORWARDING_RULE_ID
          },
          'networkacl' => {
            'id' => ACL_ID
          },
          'virtualmachine' => {
            'password' => GENERATED_PASSWORD
          }
        }
      }
    }
  end

  let(:list_public_ip_addresses_response) do
    {
      'listpublicipaddressesresponse' => {
        'count' => 1,
        'publicipaddress' =>
        [
          {
            'id' => PF_IP_ADDRESS_ID,
            'ipaddress' => PF_IP_ADDRESS,
            'associatednetworkid' => NETWORK_ID,
            'associatednetworkname' => NETWORK_NAME,
            'vpcid' => VPC_ID
          }
        ]
      }
    }
  end

  let(:network_type) { NETWORK_TYPE_ADVANCED }
  let(:security_groups_enabled) { SECURITY_GROUPS_DISABLED }
  let(:list_zones_response) do
    {
      'listzonesresponse' => {
        'count' => 1,
        'zone' =>
        [
          {
            'tags' => [],
            'id' => ZONE_ID,
            'name' => ZONE_NAME,
            'networktype' => network_type,
            'securitygroupsenabled' => security_groups_enabled
          }
        ]
      }
    }
  end

  let(:list_service_offerings_response) do
    {
      'listserviceofferingsresponse' => {
        'count' => 1,
        'serviceoffering' => [
          {
            'id' => SERVICE_OFFERING_ID,
            'name' => SERVICE_OFFERING_NAME,
            'displaytext' => "Display version of #{SERVICE_OFFERING_NAME}"
          }
        ]
      }
    }
  end

  let(:list_templates_response) do
    {
      'listtemplatesresponse' => {
        'count' => 1,
        'template' => [
          {
            'id' => TEMPLATE_ID,
            'name' => TEMPLATE_NAME
          }
        ]
      }
    }
  end

  let(:list_networks_response) do
    {
      'listnetworksresponse' => {
        'count' => 1,
        'network' => [
          {
            'id' => NETWORK_ID,
            'name' => NETWORK_NAME,
            'vpcid' => VPC_ID,
            'aclid' => ACL_ID
          }
        ]
      }
    }
  end

  let(:list_network_acl_lists_response) do
    {
      'listnetworkacllistsresponse' => {
        'count' => 3,
        'networkacllist' => [
          {
            'id' => ACL_ID,
            'name' => NETWORK_NAME,
            'vpcid' => VPC_ID
          },
          {
            'id' => '13fa8945-9248-13e5-4afa-525405b8977a', 'name' => 'default_allow',
            'description' => 'Default Network ACL Allow All'
          },
          {
            'id' => '13fa283b-9248-13e5-4afa-525405b8977a', 'name' => 'default_deny',
            'description' => 'Default Network ACL Deny All'
          }
        ]
      }
    }
  end
  let(:list_disk_offerings_response) do
    {
      'listdiskofferingsresponse' => {
        'count' => 1,
        'diskoffering' => [
          {
            'id' => DISK_OFFERING_ID,
            'name' => DISK_OFFERING_NAME
          }
        ]
      }
    }
  end

  let(:create_port_forwarding_rule_parameters) do
    {
      networkid: NETWORK_ID,
      ipaddressid: PF_IP_ADDRESS_ID,
      publicport: 49_152,
      privateport: GUEST_PORT_SSH,
      protocol: 'tcp',
      virtualmachineid: SERVER_ID
    }
  end

  let(:create_port_forwarding_rule_respones) do
    {
      'createportforwardingruleresponse' => {
        'id' => PORT_FORWARDING_RULE_ID,
        'jobid' => JOB_ID
      }
    }
  end

  let(:create_network_acl_request) do
    {
      command: 'createNetworkACL',
      aclid: ACL_ID,
      action: 'Allow',
      protocol: 'tcp',
      cidrlist: PF_TRUSTED_NETWORKS,
      startport: GUEST_PORT_SSH,
      endport: GUEST_PORT_SSH,
      icmpcode: nil,
      icmptype: nil,
      traffictype: 'Ingress'
    }
  end

  let(:createNetworkACL_response) do
    {
      'createnetworkaclresponse' => {
        'id' => '5dcb96b5-7785-463d-9a11-d8388c98e4ee',
        'jobid' => JOB_ID
      }
    }
  end

  let(:create_ssh_key_pair_response) do
    {
      'createsshkeypairresponse' => {
        'keypair' => {
          'privatekey' => "#{SSH_GENERATED_PRIVATE_KEY}\n",
          'name' => SSH_GENERATED_KEY_NAME
        }
      }
    }
  end

  describe 'run_instance' do
    subject { action.call(env) }
    let(:app) { double('Vagrant::Action::Warden') }
    let(:ssh_key) { '/some/path' }

    let(:template_name) { TEMPLATE_NAME }
    let(:machine) { double('Vagrant::Machine') }
    let(:data_dir) { double('Pathname') }
    let(:a_path) { double('Pathname') }
    let(:file) { double('File') }
    let(:communicator) { double('VagrantPlugins::CommunicatorSSH::Communicator') }
    let(:communicator_config) { double('VagrantPlugins::...::...Config') }
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

    let(:cloudstack_zone) do
      instance_double('Fog::Compute::Cloudstack::Zone',
                      id: ZONE_ID,
                      name: ZONE_NAME,
                      network_type: network_type,
                      security_groups_enabled: security_groups_enabled)
    end

    before(:each) do
      allow(app).to receive(:call).and_return(true)
      allow(ui).to receive(:info)
      allow(ui).to receive(:detail)

      allow(machine).to receive(:data_dir).and_return(data_dir)
      allow(data_dir).to receive(:join).and_return(a_path)
      allow(a_path).to receive(:open).and_yield(file)

      allow(machine).to receive(:communicate).and_return(communicator)
      allow(machine).to receive_message_chain(:communicate, :ready?).and_return(true)

      allow(machine).to receive(:provider_config).and_return(provider_config)
      expect(server).to receive(:wait_for).and_return(ready = true)
      allow(server).to receive(:password_enabled).and_return(true)
      allow(server).to receive(:job_id).and_return(JOB_ID)
      
      expect(file).to receive(:write).with(GENERATED_PASSWORD)
      allow(cloudstack_compute).to receive(:query_async_job_result).with(jobid: JOB_ID).and_return(fake_job_result)
      expect(cloudstack_compute).to receive(:servers).and_return(servers)
      allow(cloudstack_compute).to receive(:send).with(:list_zones, available: true).and_return(list_zones_response)
      allow(cloudstack_compute).to receive(:send).with(:list_service_offerings, listall: true)
        .and_return(list_service_offerings_response)
      allow(cloudstack_compute).to receive(:send)
        .with(:list_templates, zoneid: ZONE_ID, templatefilter: 'executable', listall: true)
        .and_return(list_templates_response)
      allow(cloudstack_compute).to receive(:zones).and_return([cloudstack_zone])
      allow(servers).to receive(:create).with(create_servers_parameters).and_return(server)
      expect(server).to receive(:id).and_return(SERVER_ID)
      expect(machine).to receive(:id=).with(SERVER_ID)

      allow(cloudstack_compute).to receive(:volumes).and_return([])
    end

    context 'in basic zone' do
      let(:security_groups) { [] }
      let(:network_name) { nil }
      let(:provider_config) do
        config = VagrantPlugins::Cloudstack::Config.new
        config.domain_config :cloudstack do |cfg|
          cfg.zone_name = ZONE_NAME
          cfg.service_offering_name = SERVICE_OFFERING_NAME
          cfg.template_name = template_name
          cfg.display_name = DISPLAY_NAME
          cfg.ssh_key = ssh_key
          cfg.security_groups = security_groups
          cfg.network_name = network_name
          cfg.vm_password = GENERATED_PASSWORD
        end
        config.finalize!
        config.get_domain_config(:cloudstack)
      end
      let(:network_type) { NETWORK_TYPE_BASIC }
      let(:security_groups_enabled) { SECURITY_GROUPS_ENABLED }

      let(:create_servers_parameters) do
        {
          display_name: DISPLAY_NAME,
          group: nil,
          zone_id: ZONE_ID,
          flavor_id: SERVICE_OFFERING_ID,
          image_id: TEMPLATE_ID
        }
      end

      context 'a basic configuration' do
        it 'starts a vm' do
          should eq true
        end
      end

      context 'with inline security groups' do
        let(:sg_rule) { { protocol: 'TCP', startport: 23, endport: 23, cidrlist: '0.0.0.0/0' } }

        let(:create_servers_parameters) { super().merge('security_group_ids' => SECURITY_GROUP_ID) }
        let(:security_groups) do
          [
            {
              name: SECURITY_GROUP_NAME, description: SECURITY_GROUP_DESC,
              rules: [sg_rule.merge(type: 'ingress')]
            }
          ]
        end

        before(:each) do
          allow(cloudstack_compute).to receive(:create_security_group)
            .with(name: SECURITY_GROUP_NAME, description: SECURITY_GROUP_DESC)
            .and_return('createsecuritygroupresponse' => { 'securitygroup' => { 'id' => SECURITY_GROUP_ID } })

          allow(cloudstack_compute).to receive(:send).with(:authorize_security_group_ingress,
                                                           { securityGroupId: SECURITY_GROUP_ID }.merge(sg_rule))
            .and_return(
              'authorizesecuritygroupingressresponse' => { 'jobid' => '0b6c2c41-f0c8-43b5-be1d-9d5957873cf9' }
            )
          expect(file).to receive(:write).with("#{SECURITY_GROUP_ID}\n")
        end

        it 'starts a vm' do
          should eq true
        end
      end

      context 'with advanced zone parameters give warnings' do
        let(:network_name) { NETWORK_NAME }

        before(:each) do
          expect(ui).to receive(:warn).with("Network name or id defined but zone Zone Name is of network type 'Basic'"\
            "\nNetwork name or id will be ignored")
        end
        it 'starts a vm' do
          should eq true
        end
      end
    end  
      
    context 'in advanced zone' do
      let(:pf_ip_address) { nil }
      let(:pf_trusted_networks) { nil }
      let(:pf_public_port_randomrange) { { start: 49_152, end: 65_535 } }
      let(:pf_open_firewall) { true }
      let(:disk_offering_name) { nil }

      let(:provider_config) do
        config = VagrantPlugins::Cloudstack::Config.new
        config.domain_config :cloudstack do |cfg|
          cfg.zone_name = ZONE_NAME
          cfg.network_name = NETWORK_NAME
          cfg.service_offering_name = SERVICE_OFFERING_NAME
          cfg.template_name = template_name
          cfg.display_name = DISPLAY_NAME
          cfg.pf_ip_address = pf_ip_address
          cfg.pf_trusted_networks = pf_trusted_networks
          cfg.pf_public_port_randomrange = pf_public_port_randomrange
          cfg.pf_open_firewall = pf_open_firewall
          cfg.ssh_key = ssh_key
          cfg.disk_offering_name = disk_offering_name
          cfg.vm_password = GENERATED_PASSWORD
        end
        config.finalize!
        config.get_domain_config(:cloudstack)
      end

      let(:winrm_config) { double('VagrantPlugins::VagrantWinRM::WinRMConfig') }

      before(:each) do
        allow(cloudstack_compute).to receive(:send).with(:list_networks, {}).and_return(list_networks_response)
      end

      context 'a basic configuration' do
        it 'starts a vm' do
          should eq true
        end
      end

      context 'with template specified from Vagrant(file)' do
        let(:template_name) { nil }

        before(:each) do
          expect(machine).to receive_message_chain(:config, :vm, :box).and_return(TEMPLATE_NAME)
        end
        it 'starts a vm' do
          should eq true
        end
      end

      context 'with additional data disk' do
        let(:disk_offering_name) { DISK_OFFERING_NAME }
        let(:create_servers_parameters) { super().merge('disk_offering_id' => DISK_OFFERING_ID) }
        let(:volume) { double('Fog::Compute::Cloudstack::Volume') }

        before(:each) do
          allow(cloudstack_compute).to receive(:send).with(:list_disk_offerings, listall: true)
            .and_return(list_disk_offerings_response)
          expect(cloudstack_compute).to receive(:volumes).and_return([volume])
          allow(volume).to receive(:server_id).and_return(SERVER_ID)
          allow(volume).to receive(:type).and_return('DATADISK')
          allow(volume).to receive(:id).and_return(VOLUME_ID)
          expect(file).to receive(:write).with("#{VOLUME_ID}\n")
          allow(server).to receive(:id).and_return(SERVER_ID)
        end
        it 'starts a vm' do
          should eq true
        end
      end

      context 'with static password' do
        before(:each) do
          expect(server).to receive(:password_enabled).and_return(false)
        end

        it 'starts a vm' do
          should eq true
        end
      end

      context 'with SSH key generation' do
        let(:ssh_key) { nil }
        let(:create_servers_parameters) { super().merge('key_name' => SSH_GENERATED_KEY_NAME) }

        before(:each) do
          expect(ui).to receive(:warn)
            .with('No keypair or ssh_key specified to launch your instance with.' \
                    "\n" + 'Generating a temporary keypair for this instance...')
          expect(cloudstack_compute).to receive(:create_ssh_key_pair).with(/vagacs_#{DISPLAY_NAME}/, nil, nil, nil)
            .and_return(create_ssh_key_pair_response)
          expect(file).to receive(:write).with("#{SSH_GENERATED_PRIVATE_KEY}\n")
          expect(file).to receive(:write).with(SSH_GENERATED_KEY_NAME)
        end

        it 'starts a vm' do
          should eq true
        end
      end

      context 'with autogenerated firewall and port forward' do
        let(:pf_ip_address) { PF_IP_ADDRESS }
        let(:pf_trusted_networks) { PF_TRUSTED_NETWORKS }
        let(:pf_public_port_randomrange) { { start: PF_RANDOM_START, end: PF_RANDOM_START + 1 } }
        let(:pf_open_firewall) { false }

        before(:each) do
          allow(cloudstack_compute).to receive(:send).with(:list_public_ip_addresses, {})
            .and_return(list_public_ip_addresses_response)
          expect(communicator_config).to receive(:port).and_return(nil)
          expect(communicator_config).to receive(:guest_port).and_return(nil)

          allow(machine).to receive_message_chain(:config, :vm, :rdp, :port).and_return(3389)
          allow(machine).to receive_message_chain(:config, :vm, :guest).and_return(nil)
          allow(machine).to receive(:id).and_return(SERVER_ID)

          allow(cloudstack_compute).to receive(:send).with(:list_public_ip_addresses, 'id' => PF_IP_ADDRESS_ID)
            .and_return(list_public_ip_addresses_response)
          allow(cloudstack_compute).to receive(:list_network_acl_lists).with(id: nil)
            .and_return(list_network_acl_lists_response)

          expect(file).to receive(:write).with(PORT_FORWARDING_RULE_ID + "\n")
          expect(file).to receive(:write).with(PF_RANDOM_START.to_s)
          expect(file).to receive(:write).with("#{ACL_ID},networkacl\n")
        end

        context 'for the SSH communicator' do
          before(:each) do
            allow(communicator).to receive_message_chain(:class, :name).and_return(COMMUNICATOR_SSH)
            expect(machine).to receive_message_chain(:config, :ssh).and_return(communicator_config)

            allow(communicator_config).to receive_message_chain(:default, :port).and_return(GUEST_PORT_SSH)
            expect(cloudstack_compute).to receive(:create_port_forwarding_rule)
              .with(create_port_forwarding_rule_parameters)
              .and_return(create_port_forwarding_rule_respones)
            expect(cloudstack_compute).to receive(:request)
              .with(create_network_acl_request)
              .and_return(createNetworkACL_response)
          end
          it 'starts a vm' do
            should eq true
          end

          context 'with a port conflict' do
            let(:pf_public_port_randomrange) { { start: PF_RANDOM_START - 1, end: PF_RANDOM_START + 1 } }

            before(:each) do
              allow(Kernel).to receive(:rand).with((PF_RANDOM_START - 1)...(PF_RANDOM_START + 1))
                .and_return(PF_RANDOM_START - 1, PF_RANDOM_START)
              expect(cloudstack_compute).to receive(:create_port_forwarding_rule)
                .with(create_port_forwarding_rule_parameters.merge(publicport: PF_RANDOM_START - 1))
                .and_raise(
                  Fog::Compute::Cloudstack::Error,
                  'The range specified, CONFLICTINGRANGE, conflicts with rule SOMERULE which has THESAME'
                )
            end

            it 'starts a vm' do
              should eq true
            end
          end
        end

        context 'for the WinRM (and RDP) communicator' do
          PF_RDP_RULE_ID = 'UUID RDP port forwarding rule'.freeze
          PF_RDP_JOB_ID = 'UUID RDP Port Forward Job'.freeze
          FW_RDP_JOB_ID = 'UUID RDP Port Firewall Job'.freeze
          FW_RDP_ACL_ID = 'UUID of RDP ACL'.freeze

          let(:pf_public_port_randomrange) { { start: PF_RANDOM_START, end: PF_RANDOM_START + 2 } }

          let(:create_port_forwarding_rule_parameters) { super().merge(privateport: GUEST_PORT_WINRM) }
          let(:create_port_forwarding_rule_rdp_parameters) do
            create_port_forwarding_rule_parameters.merge(privateport: GUEST_PORT_RDP, publicport: PF_RANDOM_START + 1)
          end

          let(:create_network_acl_winrm_request) do
            create_network_acl_request.merge(startport: GUEST_PORT_WINRM, endport: GUEST_PORT_WINRM)
          end
          let(:create_network_acl_rdp_request) do
            create_network_acl_request.merge(startport: GUEST_PORT_RDP, endport: GUEST_PORT_RDP)
          end

          before(:each) do
            allow(Kernel).to receive(:rand).with(PF_RANDOM_START...(PF_RANDOM_START + 2))
              .and_return(PF_RANDOM_START, PF_RANDOM_START + 1)

            allow(communicator).to receive_message_chain(:class, :name).and_return(COMMUNICATOR_WINRM)
            expect(machine).to receive_message_chain(:config, :winrm).and_return(communicator_config)

            allow(communicator_config).to receive_message_chain(:default, :port).and_return(GUEST_PORT_WINRM)

            expect(cloudstack_compute).to receive(:create_port_forwarding_rule)
              .with(create_port_forwarding_rule_parameters)
              .and_return(create_port_forwarding_rule_respones)

            expect(cloudstack_compute).to receive(:create_port_forwarding_rule)
              .with(create_port_forwarding_rule_rdp_parameters).and_return(
                'createportforwardingruleresponse' =>
                {
                  'id' => PF_RDP_RULE_ID,
                  'jobid' => PF_RDP_JOB_ID
                }
              )
            allow(cloudstack_compute).to receive(:query_async_job_result).with(jobid: PF_RDP_JOB_ID)
              .and_return(fake_job_result.merge(
                            'queryasyncjobresultresponse' => {
                              'jobresult' => {
                                'portforwardingrule' => {
                                  'id' => PF_RDP_RULE_ID
                                }
                              }
                            }
              ))
            expect(file).to receive(:write).with(PF_RDP_RULE_ID + "\n")
            expect(file).to receive(:write).with((PF_RANDOM_START + 1).to_s)
            expect(cloudstack_compute).to receive(:request).with(create_network_acl_winrm_request)
              .and_return(createNetworkACL_response)

            expect(cloudstack_compute).to receive(:request).with(create_network_acl_rdp_request)
              .and_return(
                'createnetworkaclresponse' => {
                  'id' => '5dcb96b5-7785-463d-9a11-d8388c98e4ee',
                  'jobid' => FW_RDP_JOB_ID
                }
              )
            allow(cloudstack_compute).to receive(:query_async_job_result).with(jobid: FW_RDP_JOB_ID)
              .and_return(
                fake_job_result.merge(
                  'queryasyncjobresultresponse' => {
                    'jobstatus' => 1,
                    'jobresult' => {
                      'networkacl' => {
                        'id' => FW_RDP_ACL_ID
                      }
                    }
                  }
                )
              )
            expect(file).to receive(:write).with("#{FW_RDP_ACL_ID},networkacl\n")
          end
          it 'starts a vm' do
            should eq true
          end
        end
      end
    end
  end
end