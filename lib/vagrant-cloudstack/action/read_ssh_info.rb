require "log4r"

module VagrantPlugins
  module Cloudstack
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_cloudstack::action::read_ssh_info")
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:cloudstack_compute], env[:machine])

          @app.call(env)
        end

        def read_ssh_info(cloudstack, machine)
          return nil if machine.id.nil?

          # Find the machine
          server = cloudstack.servers.get(machine.id)
          if server.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end

          # Get the Port forwarding config
          domain = machine.provider_config.domain_id
          domain_config = machine.provider_config.get_domain_config(domain)

          pf_ip_address_id = domain_config.pf_ip_address_id
          pf_public_port = domain_config.pf_public_port

          if pf_ip_address_id and pf_public_port
            begin
              response = cloudstack.list_public_ip_addresses({:id => pf_ip_address_id})
            rescue Fog::Compute::Cloudstack::Error => e
              raise Errors::FogError, :message => e.message
            end

            if response["listpublicipaddressesresponse"]["count"] == 0
              @logger.info("IP address #{pf_ip_address_id} not exists.")
              env[:ui].info(I18n.t("IP address #{pf_ip_address_id} not exists."))
              pf_ip_address = nil
            else
              pf_ip_address = response["listpublicipaddressesresponse"]["publicipaddress"][0]["ipaddress"]
            end
          end

          unless pf_ip_address.nil?
            return {:host => pf_ip_address, :port => pf_public_port}
          else
            return {:host => server.nics[0]['ipaddress'], :port => 22}
          end
        end
      end
    end
  end
end
