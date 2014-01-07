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
          # Delete the Port forwarding rule
          env[:ui].info(I18n.t("vagrant_cloudstack.deleting_port_forwarding_rule"))
          port_forwarding_file = env[:machine].data_dir.join("port_forwarding")
          if port_forwarding_file.file?
            rule_id = port_forwarding_file.read
            begin
              job_id = env[:cloudstack_compute].delete_port_forwarding_rule({:id => rule_id})["deleteportforwardingruleresponse"]["jobid"]
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
            port_forwarding_file.delete
          end

          # Destroy the server and remove the tracking ID
          server = env[:cloudstack_compute].servers.get(env[:machine].id)
          env[:ui].info(I18n.t("vagrant_cloudstack.terminating"))

          job = server.destroy
          while true
            response = env[:cloudstack_compute].query_async_job_result({:jobid => job.id})
            if response["queryasyncjobresultresponse"]["jobstatus"] != 0
              break
            else
              env[:ui].info("Waiting for instance to be deleted")
              sleep 2
            end
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
