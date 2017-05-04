require_relative 'read_transport_info.rb'
require 'log4r'

module VagrantPlugins
  module Cloudstack
    module Action
      # This action reads the WinRM info for the machine and puts it into the
      # `:machine_winrm_info` key in the environment.
      class ReadRdpInfo < ReadTransportInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_cloudstack::action::read_rdp_info")

          @public_port_fieldname = 'pf_public_rdp_port'
        end

        def call(env)
          env[:machine_rdp_info] = read_rdp_info(env[:cloudstack_compute], env[:machine])

          @app.call(env)
        end

        def read_rdp_info(cloudstack, machine)
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
          domain        = machine.provider_config.domain_id
          domain_config = machine.provider_config.get_domain_config(domain)

          pf_ip_address, pf_public_port = retrieve_public_ip_port(cloudstack, domain_config, machine)

          transport_info = {
                       :host => pf_ip_address || server.nics[0]['ipaddress'],
                       :port => pf_public_port
                     }

          transport_info
        end
      end
    end
  end
end
