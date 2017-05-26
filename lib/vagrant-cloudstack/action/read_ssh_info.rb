require_relative 'read_transport_info.rb'
require 'log4r'

module VagrantPlugins
  module Cloudstack
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo < ReadTransportInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_cloudstack::action::read_ssh_info")

          @public_port_fieldname = 'pf_public_port'
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:cloudstack_compute], env[:machine])

          @app.call(env)
        end

        def read_ssh_info(cloudstack, machine)
          return nil if (server = find_server(cloudstack, machine)).nil?

          # Get the Port forwarding config
          domain        = machine.provider_config.domain_id
          domain_config = machine.provider_config.get_domain_config(domain)

          pf_ip_address, pf_public_port = retrieve_public_ip_port(cloudstack, domain_config, machine)

          if domain_config.keypair.nil? && domain_config.ssh_key.nil?
            sshkeyfile_file = machine.data_dir.join('sshkeyfile')
            if sshkeyfile_file.file?
              domain_config.ssh_key = sshkeyfile_file.to_s
            end
          end

          nic_ip_address = fetch_nic_ip_address(server.nics, domain_config)

          transport_info = {
                       :host => pf_ip_address || nic_ip_address,
                       :port => pf_public_port
                     }
          transport_info = transport_info.merge({
            :private_key_path => domain_config.ssh_key,
            :password         => nil
          }) unless domain_config.ssh_key.nil?
          transport_info = transport_info.merge({ :username => domain_config.ssh_user }) unless domain_config.ssh_user.nil?
          transport_info
        end

        def fetch_nic_ip_address(nics, domain_config)
          ssh_nic =
            if !domain_config.ssh_network_id.nil?
              nics.find { |nic| nic["networkid"] == domain_config.ssh_network_id }
            elsif !domain_config.ssh_network_name.nil?
              nics.find { |nic| nic["networkname"] == domain_config.ssh_network_name }
            else
              # When without neither ssh_network_id and ssh_network_name, use 1st nic
              nics[0]
            end

          ssh_nic ||= nics[0]
          ssh_nic["ipaddress"]
        end
      end
    end
  end
end
