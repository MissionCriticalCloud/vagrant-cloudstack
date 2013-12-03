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
          server.destroy
          env[:machine].id = nil

          @app.call(env)
        end
      end
    end
  end
end
