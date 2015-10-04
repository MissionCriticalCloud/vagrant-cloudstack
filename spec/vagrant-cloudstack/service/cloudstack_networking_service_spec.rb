require 'spec_helper'
require 'pathname'
require 'vagrant-cloudstack/model/cloudstack_resource'
require 'vagrant-cloudstack/service/cloudstack_networking_service'

include VagrantPlugins::Cloudstack::Model
include VagrantPlugins::Cloudstack::Service
include VagrantPlugins::Cloudstack::Exceptions

describe CloudstackNetworkingService do
  let(:cloudstack_compute) { double('Fog::Compute::Cloudstack') }
  let(:ui) { double('Vagrant::UI') }
  let(:machine) { machine = Mash.new({:id => 'machine_id', :data_dir => Pathname.new('dir')}) }
  let(:service) { CloudstackNetworkingService.new(cloudstack_compute, ui, machine) }
  let(:ip) { ip = CloudstackResource.new('some ip address id', 'name', 'public_ip') }

  before do
    allow(ui).to receive(:info)
    allow(ui).to receive(:debug)
  end

  context 'when the API call succeeds' do
    describe '#enable_static_nat' do
      it 'enables static nat' do
        snat_command = {
          :command          => 'enableStaticNat',
          :ipaddressid      => 'some ip address id',
          :virtualmachineid => 'machine_id'
        }
        snat_response = {
          'enablestaticnatresponse' => {
            'success' => 'true'
          }
        }
        allow(cloudstack_compute).to receive(:request).with(snat_command).and_return(snat_response)

        expect(service).to receive(:save_ip_address_to_data_dir)
        service.enable_static_nat(ip)
      end
    end

    describe '#create_port_forwarding_rule' do
      it 'creates a port forwarding rule' do
        pf_job_id = '1'
        create_pf_response = { 'createportforwardingruleresponse' => { 'jobid' => pf_job_id } }
        async_pf_job_reponse = {
          'queryasyncjobresultresponse' => {
            'jobstatus' => 1,
            'jobresult' => {
              'portforwardingrule' => {
                'id' => 'pf_rule_id'
              }
            }
          }
        }
        allow(cloudstack_compute).to receive(:create_port_forwarding_rule).and_return(create_pf_response)
        allow(cloudstack_compute).to receive(:query_async_job_result).with({ :jobid => pf_job_id }).and_return(async_pf_job_reponse)
        rule = {
          :publicport   => 1,
          :privateport  => 2,
          :protocol     => 'tcp',
          :openfirewall => true
        }

        expect(service).to receive(:save_port_forwarding_to_data_dir)
        service.create_port_forwarding_rule(rule, ip)
      end
    end

    describe '#create_firewall_rule' do
      it 'creates a firewall rule' do
        fw_command = {
          :command     => 'createFirewallRule',
          :ipaddressid => 'some ip address id',
          :protocol    => 'tcp',
          :cidrlist    => 'a cidr list',
          :startport   => 1,
          :endport     => 2,
          :icmpcode    => 'icmp code',
          :icmptype    => 'icmp type'
        }
        fw_job_id = '2'
        create_fw_response = { 'createfirewallruleresponse' => { 'jobid' => fw_job_id }}
        async_fw_job_reponse = {
          'queryasyncjobresultresponse' => {
            'jobstatus' => 1,
            'jobresult' => {
              'firewallrule' => {
                'id' => 'fw_rule_id'
              }
            }
          }
        }
        allow(cloudstack_compute).to receive(:request).with(fw_command).and_return(create_fw_response)
        allow(cloudstack_compute).to receive(:query_async_job_result).with({ :jobid => fw_job_id }).and_return(async_fw_job_reponse)
        rule = {
          :ipaddressid => 'some ip address id',
          :protocol    => 'tcp',
          :cidrlist    => 'a cidr list',
          :startport   => 1,
          :endport     => 2,
          :icmpcode    => 'icmp code',
          :icmptype    => 'icmp type'
        }

        expect(service).to receive(:save_firewall_rule_to_data_dir)
        service.create_firewall_rule(rule, ip)
      end
    end
  end

  context 'when the API call does not succeed' do
    before do
      command = {
        :command          => 'enableStaticNat',
        :ipaddressid      => 'id',
        :virtualmachineid => 'machine_id'
      }
      response = {
        'enablestaticnatresponse' => {
          'success'   => 'false',
          'errortext' => 'some error message'
        }
      }
      allow(cloudstack_compute).to receive(:request).with(command).and_return(response)
    end

    describe '#enable_static_nat' do
      it 'raises an API failure error' do
        ip = CloudstackResource.new('id', 'name', 'public_ip')

        expect { service.enable_static_nat(ip) }.to raise_exception(ApiCommandFailed, 'some error message')
      end
    end
  end
end
