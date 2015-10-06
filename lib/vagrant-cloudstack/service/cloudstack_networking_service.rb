require 'vagrant-cloudstack/service/base_service'
require 'vagrant-cloudstack/exceptions/exceptions'
require 'fog'

module VagrantPlugins
  module Cloudstack
    module Service
      class CloudstackNetworkingService < BaseService
        include VagrantPlugins::Cloudstack::Exceptions

        def initialize(cloudstack_compute, ui, machine)
          super(cloudstack_compute, ui)
          @machine = machine
        end

        def enable_static_nat(ip_address)
          options = {
            :command          => 'enableStaticNat',
            :ipaddressid      => ip_address.id,
            :virtualmachineid => @machine.id
          }

          begin
            # TODO: use fog API to enable static nat
            #       https://github.com/fog/fog/blob/b2c6e0df30eae7fb9154ba6bd340f27c0c158855/lib/fog/cloudstack/requests/compute/enable_static_nat.rb
            resp = @cloudstack_compute.request(options)
            is_success = resp['enablestaticnatresponse']['success']

            if is_success != 'true'
              raise ApiCommandFailed, resp['enablestaticnatresponse']['errortext']
            end
            @ui.info('Static NAT enabled')
            save_ip_address_to_data_dir(ip_address.id)
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end
        end

        def create_port_forwarding_rule(rule, ip_address)
          options = {
              :networkid        => rule[:network].id,
              :ipaddressid      => ip_address.id,
              :publicport       => rule[:publicport],
              :privateport      => rule[:privateport],
              :protocol         => rule[:protocol],
              :openfirewall     => rule[:openfirewall],
              :virtualmachineid => @machine.id
          }

          begin
            resp   = @cloudstack_compute.create_port_forwarding_rule(options)
            job_id = resp['createportforwardingruleresponse']['jobid']

            raise ApiCommandFailed, resp['enablestaticnatresponse']['errortext'] if job_id.nil?

            # TODO: there should be a timeout or a max retry value
            # TODO: the code should handle a failed job result (or will that always throw a FOG exception?)
            while true
              response = @cloudstack_compute.query_async_job_result({ :jobid => job_id })
              if response['queryasyncjobresultresponse']['jobstatus'] != 0
                break
              else
                sleep 2
              end
            end
            @ui.info('Port forwarding rule created')
            port_forwarding_rule = response['queryasyncjobresultresponse']['jobresult']['portforwardingrule']
            save_port_forwarding_to_data_dir(port_forwarding_rule['id'])
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end
        end

        def create_network_acl(rule, network)
          options = {
              :aclid       => network.acl_id,
              :networkid   => network.id,
              :action      => 'Allow',
              :protocol    => rule[:protocol],
              :cidrlist    => rule[:cidrlist],
              :startport   => rule[:startport],
              :endport     => rule[:endport],
              :icmpcode    => rule[:icmpcode],
              :icmptype    => rule[:icmptype],
              :traffictype => 'Ingress'
          }
          begin
            resp = @cloudstack_compute.create_network_acl(options)
            job_id = resp['createnetworkaclresponse']['jobid']

            raise ApiCommandFailed, resp['createnetworkaclresponse']['errortext'] if job_id.nil?

            # TODO: there should be a timeout or a max retry value
            # TODO: the code should handle a failed job result (or will that always throw a FOG exception?)
            while true
              response = @cloudstack_compute.query_async_job_result({ :jobid => job_id })
              if response['queryasyncjobresultresponse']['jobstatus'] != 0
                break
              else
                sleep 2
              end
            end
            @ui.info('Network ACL created')
            network_acl = response['queryasyncjobresultresponse']['jobresult']['networkacl']
            save_network_acl_to_data_dir(network_acl['id'])
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end
        end

        def create_firewall_rule(rule, ip_address)
          options = {
              :command     => 'createFirewallRule',
              :ipaddressid => ip_address.id,
              :protocol    => rule[:protocol],
              :cidrlist    => rule[:cidrlist],
              :startport   => rule[:startport],
              :endport     => rule[:endport],
              :icmpcode    => rule[:icmpcode],
              :icmptype    => rule[:icmptype]
          }

          begin
            # TODO: use fog API to create firewall rule
            #       https://github.com/fog/fog/blob/b2c6e0df30eae7fb9154ba6bd340f27c0c158855/lib/fog/cloudstack/requests/compute/create_firewall_rule.rb
            resp = @cloudstack_compute.request(options)
            job_id = resp['createfirewallruleresponse']['jobid']

            raise ApiCommandFailed, resp['createfirewallruleresponse']['errortext'] if job_id.nil?

            # TODO: there should be a timeout or a max retry value
            # TODO: the code should handle a failed job result (or will that always throw a FOG exception?)
            while true
              response = @cloudstack_compute.query_async_job_result({ :jobid => job_id })
              if response['queryasyncjobresultresponse']['jobstatus'] != 0
                break
              else
                sleep 2
              end
            end
            @ui.info('Firewall rule created')
            firewall_rule = response['queryasyncjobresultresponse']['jobresult']['firewallrule']
            save_firewall_rule_to_data_dir(firewall_rule['id'])
          rescue Fog::Compute::Cloudstack::Error => e
            if e.message =~ /The range specified,.*conflicts with rule/
              @ui.warn("Failed to create firewall rule: #{e.message}")
            else
              raise Errors::FogError, :message => e.message
            end
          end
        end

        private

        def save_network_acl_to_data_dir(rule_id)
          save_element_to_data_dir('network_acl', rule_id)
        end

        def save_firewall_rule_to_data_dir(rule_id)
          save_element_to_data_dir('firewall', rule_id)
        end

        def save_port_forwarding_to_data_dir(rule_id)
          save_element_to_data_dir('port_forwarding', rule_id)
        end

        def save_ip_address_to_data_dir(ip_address_id)
          save_element_to_data_dir('static_nat', ip_address_id)
        end

        def save_element_to_data_dir(element_name, value)
          element_file = @machine.data_dir.join(element_name)
          element_file.open('a+') do |f|
            f.write("#{value}\n")
            f.close()
          end
        end
      end
    end
  end
end
