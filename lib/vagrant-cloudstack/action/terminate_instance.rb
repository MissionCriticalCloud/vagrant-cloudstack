require 'log4r'

module VagrantPlugins
  module Cloudstack
    module Action
      # This terminates the running instance.
      class TerminateInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_cloudstack::action::terminate_instance')
        end

        def call(env)
          # Delete the Firewall rule
          remove_firewall_rules(env)

          # Disable Static NAT
          remove_static_nat(env)

          # Delete the Port forwarding rule
          remove_portforwarding(env)

          # Destroy the server and remove the tracking ID
          if env[:machine].id.nil?
            env[:ui].info(I18n.t('vagrant_cloudstack.no_instance_found'))
            return
          else
            server = env[:cloudstack_compute].servers.get(env[:machine].id)

            env[:ui].info(I18n.t('vagrant_cloudstack.terminating'))

            domain = env[:machine].provider_config.domain_id
            domain_config = env[:machine].provider_config.get_domain_config(domain)
            expunge_on_destroy = domain_config.expunge_on_destroy

            options = {}
            options['expunge'] = expunge_on_destroy

            job = server.destroy(options)
            wait_for_job_ready(env, job.id, 'Waiting for instance to be deleted')
          end

          remove_volumes(env)

          # Delete the vmcredentials file
          remove_stored_credentials(env)

          # Remove keyname from cloudstack
          remove_generated_ssh_key(env)

          remove_security_groups(env)

          env[:machine].id = nil

          env[:ui].info(I18n.t('vagrant_cloudstack.terminateinstance_done'))
          @app.call(env)
        end

        def remove_volumes(env)
          volumes_file = env[:machine].data_dir.join('volumes')
          if volumes_file.file?
            env[:ui].info(I18n.t('vagrant_cloudstack.deleting_volumes'))
            File.read(volumes_file).each_line do |line|
              volume_id = line.strip
              begin
                resp = env[:cloudstack_compute].detach_volume({:id => volume_id})
                job_id = resp['detachvolumeresponse']['jobid']
                wait_for_job_ready(env, job_id)
              rescue Fog::Cloudstack::Compute::Error => e
                if e.message =~ /Unable to execute API command detachvolume.*entity does not exist/
                  env[:ui].warn(I18n.t('vagrant_cloudstack.detach_volume_failed', message: e.message))
                else
                  raise Errors::FogError, :message => e.message
                end
              end
              resp = env[:cloudstack_compute].delete_volume({:id => volume_id})
              env[:ui].warn(I18n.t('vagrant_cloudstack.detach_volume_failed', volume_id: volume_id)) unless resp['deletevolumeresponse']['success'] == 'true'
            end
            volumes_file.delete
          end
        end

        def remove_security_groups(env)
          security_groups_file = env[:machine].data_dir.join('security_groups')
          if security_groups_file.file?
            File.read(security_groups_file).each_line do |line|
              security_group_id = line.strip
              begin
                security_group = env[:cloudstack_compute].security_groups.get(security_group_id)

                security_group.ingress_rules.each do |ir|
                  env[:cloudstack_compute].revoke_security_group_ingress({:id => ir['ruleid']})
                end
                env[:ui].info('Deleted ingress rules')

                security_group.egress_rules.each do |er|
                  env[:cloudstack_compute].revoke_security_group_egress({:id => er['ruleid']})
                end
                env[:ui].info('Deleted egress rules')

              rescue Fog::Cloudstack::Compute::Error => e
                raise Errors::FogError, :message => e.message
              end

              begin
                env[:cloudstack_compute].delete_security_group({:id => security_group_id})
              rescue Fog::Cloudstack::Compute::Error => e
                env[:ui].warn("Couldn't delete group right now.")
                env[:ui].warn('Waiting 30 seconds to retry')
                sleep 30
                retry
              end
            end
            security_groups_file.delete
          end
        end

        def remove_generated_ssh_key(env)
          sshkeyname_file = env[:machine].data_dir.join('sshkeyname')
          if sshkeyname_file.file?
            env[:ui].info(I18n.t('vagrant_cloudstack.ssh_key_pair_removing'))
            sshkeyname = ''
            File.read(sshkeyname_file).each_line do |line|
              sshkeyname = line.strip
            end

            begin
              response = env[:cloudstack_compute].delete_ssh_key_pair(name: sshkeyname)
              env[:ui].warn(I18n.t('vagrant_cloudstack.ssh_key_pair_no_success_removing', name: sshkeyname)) unless response['deletesshkeypairresponse']['success'] == 'true'
            rescue Fog::Cloudstack::Compute::Error => e
              env[:ui].warn(I18n.t('vagrant_cloudstack.errors.fog_error', :message => e.message))
            end
            sshkeyname_file.delete
          end
        end

        def remove_stored_credentials(env)
          vmcredentials_file = env[:machine].data_dir.join('vmcredentials')
          vmcredentials_file.delete if vmcredentials_file.file?
        end

        def remove_portforwarding(env)
          env[:ui].info(I18n.t('vagrant_cloudstack.deleting_port_forwarding_rule'))
          port_forwarding_file = env[:machine].data_dir.join('port_forwarding')
          if port_forwarding_file.file?
            File.read(port_forwarding_file).each_line do |line|
              rule_id = line.strip
              begin
                resp = env[:cloudstack_compute].delete_port_forwarding_rule({:id => rule_id})
                job_id = resp['deleteportforwardingruleresponse']['jobid']
                wait_for_job_ready(env, job_id)
              rescue Fog::Cloudstack::Compute::Error => e
                if e.message =~ /Unable to execute API command deleteportforwardingrule.*entity does not exist/
                  env[:ui].warn(" -- Failed to delete portforwarding rule: #{e.message}")
                else
                  raise Errors::FogError, :message => e.message
                end

              end
            end
            port_forwarding_file.delete
          end

          # Delete the Communicator Port forwording public port file
          # Delete the RDP Port forwording public port file
          %w(pf_public_port pf_public_rdp_port).each do |pf_filename|
            pf_file = env[:machine].data_dir.join(pf_filename)
            pf_file.delete if pf_file.file?
          end
        end

        def remove_static_nat(env)
          env[:ui].info(I18n.t('vagrant_cloudstack.disabling_static_nat'))
          static_nat_file = env[:machine].data_dir.join('static_nat')
          if static_nat_file.file?
            File.read(static_nat_file).each_line do |line|
              ip_address_id = line.strip
              begin
                options = {
                    :command => 'disableStaticNat',
                    :ipaddressid => ip_address_id
                }
                resp = env[:cloudstack_compute].request(options)
                job_id = resp['disablestaticnatresponse']['jobid']
                wait_for_job_ready(env, job_id)
              rescue Fog::Cloudstack::Compute::Error => e
                raise Errors::FogError, :message => e.message
              end
            end
            static_nat_file.delete
          end
        end

        def remove_firewall_rules(env)
          env[:ui].info(I18n.t('vagrant_cloudstack.deleting_firewall_rule'))
          firewall_file = env[:machine].data_dir.join('firewall')
          if firewall_file.file?
            File.read(firewall_file).each_line do |line|
              line_items=line.split(",").collect(&:strip)
              rule_id = line_items[0]
              type_string = line_items[1]

              if type_string == 'firewallrule'
                command_string = 'deleteFirewallRule'
                response_string = 'deletefirewallruleresponse'
              else
                command_string = 'deleteNetworkACL'
                response_string = 'deletenetworkaclresponse'
              end

              begin
                options = {
                    command: command_string,
                    id: rule_id
                }
                resp = env[:cloudstack_compute].request(options)
                job_id = resp[response_string]['jobid']
                wait_for_job_ready(env, job_id)
              rescue Fog::Cloudstack::Compute::Error => e
                if e.message =~ /Unable to execute API command deletefirewallrule.*entity does not exist/
                  env[:ui].warn(" -- Failed to delete #{type_string}: #{e.message}")
                else
                  raise Errors::FogError, :message => e.message
                end
              end
            end
            firewall_file.delete
          end
        end

        def wait_for_job_ready(env, job_id, message=nil)
          while true
            response = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
            if response['queryasyncjobresultresponse']['jobstatus'] != 0
              break
            else
              env[:ui].info(message) if message
              sleep 2
            end
          end
        end
      end
    end
  end
end
