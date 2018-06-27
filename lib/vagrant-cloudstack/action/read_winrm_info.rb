require_relative 'read_transport_info.rb'
require 'log4r'

module VagrantPlugins
  module Cloudstack
    module Action
      # This action reads the WinRM info for the machine and puts it into the
      # `:machine_winrm_info` key in the environment.
      class ReadWinrmInfo < ReadTransportInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_cloudstack::action::read_winrm_info")

          @public_port_fieldname = 'pf_public_port'
        end

        def call(env)
          env[:machine_winrm_info] = read_winrm_info(env[:cloudstack_compute], env[:machine])

          @app.call(env)
        end

        def read_winrm_info(cloudstack, machine)
          return nil if (server = find_server(cloudstack, machine)).nil?

          # Get the Port forwarding config
          domain        = machine.provider_config.domain_id
          domain_config = machine.provider_config.get_domain_config(domain)

          pf_ip_address, pf_public_port = retrieve_public_ip_port(cloudstack, domain_config, machine)


          transport_info = {
                       :host => pf_ip_address || server.nics[0]['ipaddress'],
                       :port => pf_public_port
                     }

          transport_info = transport_info.merge({
            :username => domain_config.vm_user
          }) unless domain_config.vm_user.nil?
          machine.config.winrm.username = domain_config.vm_user unless domain_config.vm_user.nil?
          # The WinRM communicator doesnt support passing
          # the username via winrm_info ... yet ;-)

          # Read password from file into domain_config
          vmcredentials_file = machine.data_dir.join("vmcredentials")
          if vmcredentials_file.file?
            vmcredentials_password = nil
            File.read(vmcredentials_file).each_line do |line|
              vmcredentials_password = line.strip
            end
            domain_config.vm_password = vmcredentials_password
          end

          transport_info = transport_info.merge({
            :password => domain_config.vm_password
          }) unless domain_config.vm_password.nil?
          # The WinRM communicator doesnt support passing
          # the password via winrm_info ... yet ;-)
          machine.config.winrm.password = domain_config.vm_password unless domain_config.vm_password.nil?

          transport_info
        end
      end
    end
  end
end
