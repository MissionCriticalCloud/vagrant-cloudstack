require "log4r"

module VagrantPlugins
  module Cloudstack
    module Action
      # This terminates the running instance.
      class TerminateInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_cloudstack::action::terminate_instance")
        end

        def call(env)
          # Delete the Firewall rule
          env[:ui].info(I18n.t("vagrant_cloudstack.deleting_firewall_rule"))
          firewall_file = env[:machine].data_dir.join("firewall")
          if firewall_file.file?
            File.read(firewall_file).each_line do |line|
              rule_id = line.strip
              begin
                options = {
                  :command => "deleteFirewallRule",
                  :id      => rule_id
                }
                resp = env[:cloudstack_compute].request(options)
                job_id = resp["deletefirewallruleresponse"]["jobid"]
                while true
                  response = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
                  if response["queryasyncjobresultresponse"]["jobstatus"] != 0
                    break
                  else
                    sleep 2
                  end
                end
              rescue Fog::Compute::Cloudstack::Error => e
                if e.message =~ /Unable to execute API command deletefirewallrule.*entity does not exist/
                  env[:ui].warn(" -- Failed to delete firewall rule: #{e.message}")
                else
                  raise Errors::FogError, :message => e.message
                end
              end
            end
            firewall_file.delete
          end

          env[:ui].info('Deleting ACL rule ...')
          network_acl_file = env[:machine].data_dir.join("network_acl")
          if network_acl_file.file?
            File.read(network_acl_file).each_line do |line|
              rule_id = line.strip
              begin
                options = {
                  :command => "deleteNetworkACL",
                  :id      => rule_id
                }
                resp = env[:cloudstack_compute].request(options)
                job_id = resp["deletenetworkaclresponse"]["jobid"]
                while true
                  response = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
                  if response["queryasyncjobresultresponse"]["jobstatus"] != 0
                    break
                  else
                    sleep 2
                  end
                end
              rescue Fog::Compute::Cloudstack::Error => e
                if e.message =~ /Unable to execute API command deletenetworkacl.*entity does not exist/
                  env[:ui].warn(" -- Failed to delete network ACL: #{e.message}")
                else
                  raise Errors::FogError, :message => e.message
                end
              end
            end
            network_acl_file.delete
          end

          # Disable Static NAT
          env[:ui].info(I18n.t("vagrant_cloudstack.disabling_static_nat"))
          static_nat_file = env[:machine].data_dir.join("static_nat")
          if static_nat_file.file?
            File.read(static_nat_file).each_line do |line|
              ip_address_id = line.strip
              begin
                options = {
                  :command => "disableStaticNat",
                  :ipaddressid => ip_address_id
                }
                resp = env[:cloudstack_compute].request(options)
                job_id = resp["disablestaticnatresponse"]["jobid"]
                while true
                  response = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
                  if response["queryasyncjobresultresponse"]["jobstatus"] != 0
                    break
                  else
                    sleep 2
                  end
                end
              rescue Fog::Compute::Cloudstack::Error => e
                raise Errors::FogError, :message => e.message
              end
            end
            static_nat_file.delete
          end

          # Delete the Port forwarding rule
          env[:ui].info(I18n.t("vagrant_cloudstack.deleting_port_forwarding_rule"))
          port_forwarding_file = env[:machine].data_dir.join("port_forwarding")
          if port_forwarding_file.file?
            File.read(port_forwarding_file).each_line do |line|
              rule_id = line.strip
              begin
                resp = env[:cloudstack_compute].delete_port_forwarding_rule({:id => rule_id})
                job_id = resp["deleteportforwardingruleresponse"]["jobid"]
                while true
                  response = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
                  if response["queryasyncjobresultresponse"]["jobstatus"] != 0
                    break
                  else
                    sleep 2
                  end
                end
              rescue Fog::Compute::Cloudstack::Error => e
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
          ['pf_public_port', 'pf_public_rdp_port'].each do |pf_filename|
            pf_file = env[:machine].data_dir.join(pf_filename)
            pf_file.delete if pf_file.file?
          end

          # Destroy the server and remove the tracking ID
          unless env[:machine].id.nil?
              server = env[:cloudstack_compute].servers.get(env[:machine].id)

          env[:ui].info(I18n.t("vagrant_cloudstack.terminating"))

          domain                = env[:machine].provider_config.domain_id
          domain_config         = env[:machine].provider_config.get_domain_config(domain)
          expunge_on_destroy    = domain_config.expunge_on_destroy

          options = {}
          options['expunge'] = expunge_on_destroy

          job = server.destroy(options)
          while true
            response = env[:cloudstack_compute].query_async_job_result({:jobid => job.id})
            if response["queryasyncjobresultresponse"]["jobstatus"] != 0
              break
            else
              env[:ui].info("Waiting for instance to be deleted")
              sleep 2
            end
          end

            else
                env[:ui].info(I18n.t("vagrant_cloudstack.no_instance_found"))
                return
          end

          # Delete the vmcredentials file
          vmcredentials_file = env[:machine].data_dir.join("vmcredentials")
          vmcredentials_file.delete if vmcredentials_file.file?

          # Remove keyname from cloudstack
          sshkeyname_file = env[:machine].data_dir.join('sshkeyname')
          if sshkeyname_file.file?
            env[:ui].info(I18n.t('vagrant_cloudstack.ssh_key_pair_removing'))
            sshkeyname = ''
            File.read(sshkeyname_file).each_line do |line|
              sshkeyname = line.strip
            end

            begin
              response = env[:cloudstack_compute].delete_ssh_key_pair(name: sshkeyname)
              env[:ui].warn(I18n.t('vagrant_cloudstack.ssh_key_pair_no_success_removing', name: sshkeyname )) unless response['deletesshkeypairresponse']['success'] == 'true'
            rescue Fog::Compute::Cloudstack::Error => e
              env[:ui].warn(I18n.t('vagrant_cloudstack.errors.fog_error', :message => e.message))
            end
            sshkeyname_file.delete
          end

          security_groups_file = env[:machine].data_dir.join("security_groups")
          if security_groups_file.file?
            File.read(security_groups_file).each_line do |line|
              security_group_id = line.strip
              begin
                security_group = env[:cloudstack_compute].security_groups.get(security_group_id)

                security_group.ingress_rules.each do |ir|
                  env[:cloudstack_compute].revoke_security_group_ingress({:id => ir["ruleid"]})
                end
                env[:ui].info("Deleted ingress rules")

                security_group.egress_rules.each do |er|
                  env[:cloudstack_compute].revoke_security_group_egress({:id => er["ruleid"]})
                end
                env[:ui].info("Deleted egress rules")

              rescue Fog::Compute::Cloudstack::Error => e
                raise Errors::FogError, :message => e.message
              end

              begin
                env[:cloudstack_compute].delete_security_group({:id => security_group_id})
              rescue Fog::Compute::Cloudstack::Error => e
                env[:ui].warn("Couldn't delete group right now.")
                env[:ui].warn("Waiting 30 seconds to retry")
                sleep 30
                retry
              end
            end
            security_groups_file.delete
          end

          env[:machine].id = nil

          @app.call(env)
        end
      end
    end
  end
end
