require 'log4r'

module VagrantPlugins
  module Cloudstack
    module Action
      # This action reads the WinRM info for the machine and puts it into the
      # `:machine_winrm_info` key in the environment.
      class ReadWinrmInfo < VagrantPlugins::Cloudstack::Action::ReadInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_cloudstack::action::read_winrm_info')
        end

        def call(env)
          env[:machine_winrm_info] = read_winrm_info(env[:cloudstack_compute], env[:machine])

          @app.call(env)
        end

        def read_winrm_info(cloudstack, machine)
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
          pf_ip_address, pf_public_port = retrieve_public_ip_port('pf_public_port')

          nic_ip_address = server.nics[0]['ipaddress']

          winrm_info = {
                       :host => pf_ip_address || nic_ip_address,
                       :port => pf_public_port
                     }

          winrm_info = winrm_info.merge({
            :username => @domain_config.vm_user
          }) unless @domain_config.vm_user.nil?
          @machine.config.winrm.username = @domain_config.vm_user unless @domain_config.vm_user.nil?
          # The WinRM communicator doesnt support passing
          # the username via winrm_info ... yet ;-)

          # Read password from file into domain_config
          if @domain_config.vm_password.nil?
            vmcredentials_file = @machine.data_dir.join("vmcredentials")
            if vmcredentials_file.file?
              vmcredentials_password = nil
              File.read(vmcredentials_file).each_line do |line|
                vmcredentials_password = line.strip
              end
              @domain_config.vm_password = vmcredentials_password
            end
          end

          winrm_info = winrm_info.merge({
            :password => @domain_config.vm_password
          }) unless @domain_config.vm_password.nil?
          # The WinRM communicator doesnt support passing
          # the password via winrm_info ... yet ;-)
          @machine.config.winrm.password = @domain_config.vm_password unless @domain_config.vm_password.nil?

          winrm_info
        end
      end
    end
  end
end
