require 'spec_helper'
require 'vagrant-cloudstack/action/terminate_instance'
require 'vagrant-cloudstack/config'

require 'vagrant'
require 'fog'

describe VagrantPlugins::Cloudstack::Action::TerminateInstance do
  let(:action) { VagrantPlugins::Cloudstack::Action::TerminateInstance.new(app, env) }

  let(:destroy_server_response) { { id: JOB_ID } }

  let(:cs_job) { double('Fog::Compute::Cloudstack::Job') }

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

  describe '#terminate_instance in advanced zone' do
    subject { action.call(env) }
    let(:app) { double('Vagrant::Action::Warden') }
    let(:ssh_key) { '/some/path' }

    let(:template_name) { TEMPLATE_NAME }

    let(:pf_ip_address) { nil }
    let(:pf_trusted_networks) { nil }
    let(:pf_public_port_randomrange) { nil }
    let(:pf_open_firewall) { nil }
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
      end
      config.finalize!
      config.get_domain_config(:cloudstack)
    end

    let(:machine) { double('Vagrant::Machine') }
    let(:data_dir) { double('Pathname') }
    let(:a_path) { double('Pathname') }
    let(:file) { double('File') }
    let(:communicator) { double('VagrantPlugins::CommunicatorSSH::Communicator') }
    let(:communicator_config) { double('VagrantPlugins::...::...Config') }
    let(:winrm_config) { double('VagrantPlugins::VagrantWinRM::WinRMConfig') }

    let(:cloudstack_zone) do
      instance_double('Fog::Compute::Cloudstack::Zone',
                      id: ZONE_ID,
                      name: ZONE_NAME,
                      network_type: NETWORK_TYPE,
                      security_groups_enabled: SECURITY_GROUPS_ENABLED)
    end
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
      expect(ui).not_to receive(:warn)
      allow(ui).to receive(:detail)

      allow(machine).to receive(:provider_config).and_return(provider_config)
      allow(machine).to receive(:data_dir).and_return(data_dir)

      allow(data_dir).to receive(:join).and_return(a_path)
      allow(a_path).to receive(:file?).and_return(false)

      expect(cloudstack_compute).to receive(:servers).and_return(servers)
      expect(servers).to receive(:get).with(SERVER_ID).and_return(server)
      expect(server).to receive(:destroy).with('expunge' => false).and_return(cs_job)
      expect(cs_job).to receive(:id).and_return(JOB_ID)

      allow(cloudstack_compute).to receive(:query_async_job_result).with(jobid: JOB_ID).and_return(fake_job_result)
      allow(machine).to receive(:id).and_return(SERVER_ID)
      expect(machine).to receive(:id=).with(nil)
    end

    context 'destroys a simple VM' do
      it 'destroys a vm' do
        should eq true
      end

      context 'with firewall rules removal' do
        let(:firewall_path) { double('Pathname') }
        let(:file_content) { double }
        let(:firewall_rule) { 'UUID of Firewall rule' }
        let(:network_acl) { 'UUID of ACL' }

        before(:each) do
          expect(data_dir).to receive(:join).with('firewall').and_return(firewall_path)
          expect(firewall_path).to receive(:file?).and_return(true)
          # A VM will never belong to both a VPC and regular router, but allowed for this test
          allow(File).to receive(:read).and_return("#{network_acl},networkacl\n" + "#{firewall_rule},firewallrule\n")

          expect(cloudstack_compute).to receive(:request)
            .with(command: 'deleteNetworkACL', id: network_acl)
            .and_return('deletenetworkaclresponse' => { 'jobid' => JOB_ID })

          expect(cloudstack_compute).to receive(:request)
            .with(command: 'deleteFirewallRule', id: 'UUID of Firewall rule')
            .and_return('deletefirewallruleresponse' => { 'jobid' => JOB_ID })

          expect(firewall_path).to receive(:delete).and_return(true)
        end

        it 'destroys a vm' do
          should eq true
        end
      end

      context 'with port forwarding removal' do
        let(:port_forwarding_path) { double('Pathname') }

        before(:each) do
          expect(data_dir).to receive(:join).with('port_forwarding').and_return(port_forwarding_path)
          expect(port_forwarding_path).to receive(:file?).and_return(true)
          allow(File).to receive(:read)
            .and_return("#{PORT_FORWARDING_RULE_ID}\n#{PORT_FORWARDING_RULE_ID}_2\n#{PORT_FORWARDING_RULE_ID}_3")

          [PORT_FORWARDING_RULE_ID, "#{PORT_FORWARDING_RULE_ID}_2", "#{PORT_FORWARDING_RULE_ID}_3"]
            .each do |port_forwarding_rule_id|

            expect(cloudstack_compute).to receive(:delete_port_forwarding_rule)
              .with(id: port_forwarding_rule_id)
              .and_return('deleteportforwardingruleresponse' => { 'jobid' => JOB_ID })
          end
          expect(port_forwarding_path).to receive(:delete).and_return(true)
        end

        it 'destroys a vm' do
          should eq true
        end
      end

      context 'with volume removal' do
        let(:volumes_path) { double('Pathname') }

        before(:each) do
          expect(data_dir).to receive(:join).with('volumes').and_return(volumes_path)
          expect(volumes_path).to receive(:file?).and_return(true)
          allow(File).to receive(:read)
            .and_return("#{VOLUME_ID}\n#{VOLUME_ID}_2\n#{VOLUME_ID}_3")

          [VOLUME_ID, "#{VOLUME_ID}_2", "#{VOLUME_ID}_3"]
            .each do |volume_id|

            expect(cloudstack_compute).to receive(:detach_volume)
              .with(id: volume_id)
              .and_return('detachvolumeresponse' => { 'jobid' => JOB_ID })
            expect(cloudstack_compute).to receive(:delete_volume)
              .with(id: volume_id)
              .and_return('deletevolumeresponse' => { 'success' => 'true' })
          end
          expect(volumes_path).to receive(:delete).and_return(true)
        end

        it 'destroys a vm' do
          should eq true
        end
      end

      context 'with credentials file removal' do
        let(:credentials_path) { double('Pathname') }

        before(:each) do
          expect(data_dir).to receive(:join).with('vmcredentials').and_return(credentials_path)
          expect(credentials_path).to receive(:file?).and_return(true)
          expect(credentials_path).to receive(:delete).and_return(true)
        end

        it 'destroys a vm' do
          should eq true
        end
      end

      context 'with generated SSH key removal' do
        let(:ssh_key__path) { double('Pathname') }

        before(:each) do
          expect(data_dir).to receive(:join).with('sshkeyname').and_return(ssh_key__path)
          expect(ssh_key__path).to receive(:file?).and_return(true)
          allow(File).to receive(:read)
            .and_return("#{SSH_GENERATED_KEY_NAME}\n")

          expect(cloudstack_compute).to receive(:delete_ssh_key_pair)
            .with(name: SSH_GENERATED_KEY_NAME)
            .and_return('deletesshkeypairresponse' => { 'success' => 'true' })

          expect(ssh_key__path).to receive(:delete).and_return(true)
        end

        it 'destroys a vm' do
          should eq true
        end
      end
    end
  end
end
