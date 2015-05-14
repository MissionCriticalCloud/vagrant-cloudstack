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
          # Get the configs
          domain                = env[:machine].provider_config.domain_id
          domain_config         = env[:machine].provider_config.get_domain_config(domain)
          expunge_on_destroy    = domain_config.expunge_on_destroy

          # Disable Static NAT
          env[:ui].info(I18n.t("vagrant_cloudstack.disabling_static_nat"))
          static_nat_file = env[:machine].data_dir.join("static_nat")
          if static_nat_file.file?
            File.open(static_nat_file, "r").each_line do |line|
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
            File.open(port_forwarding_file, "r").each_line do |line|
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
                raise Errors::FogError, :message => e.message
              end
            end
            port_forwarding_file.delete
          end

          # Delete the Firewall rule
          env[:ui].info(I18n.t("vagrant_cloudstack.deleting_firewall_rule"))
          firewall_file = env[:machine].data_dir.join("firewall")
          if firewall_file.file?
            File.open(firewall_file, "r").each_line do |line|
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
                raise Errors::FogError, :message => e.message
              end
            end
            firewall_file.delete
          end

          # Destroy the server and remove the tracking ID
          unless env[:machine].id.nil?
              server = env[:cloudstack_compute].servers.get(env[:machine].id)

          env[:ui].info(I18n.t("vagrant_cloudstack.terminating"))
          options = {}
          options['expunge'] = expunge_on_destroy if expunge_on_destroy != nil

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

          security_groups_file = env[:machine].data_dir.join("security_groups")
          if security_groups_file.file?
            File.open(security_groups_file, "r").each_line do |line|
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
