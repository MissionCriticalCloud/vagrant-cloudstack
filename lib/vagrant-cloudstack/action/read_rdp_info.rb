require 'log4r'

module VagrantPlugins
  module Cloudstack
    module Action
      # This action reads the WinRM info for the machine and puts it into the
      # `:machine_winrm_info` key in the environment.
      class ReadRdpInfo < VagrantPlugins::Cloudstack::Action::ReadInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_cloudstack::action::read_rdp_info')
        end

        def call(env)
          env[:machine_rdp_info] = read_rdp_info(env[:cloudstack_compute], env[:machine])

          @app.call(env)
        end

        def read_rdp_info(cloudstack, machine)
          return nil if machine.id.nil?

          @cloudstack = cloudstack
          @machine = machine

          # Find the machine
          server = @cloudstack.servers.get(@machine.id)
          if server.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            @machine.id = nil
            return nil
          end

          # Get the Port forwarding config
          pf_ip_address, pf_public_rdp_port = retrieve_public_ip_port('pf_public_rdp_port')

          nic_ip_address = server.nics[0]['ipaddress']

          rdp_info = {
                       :host => pf_ip_address || nic_ip_address,
                       :port => pf_public_rdp_port
                     }

          rdp_info
        end
      end
    end
  end
end
