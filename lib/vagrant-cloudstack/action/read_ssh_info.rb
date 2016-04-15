require 'log4r'

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
          domain        = machine.provider_config.domain_id
          domain_config = machine.provider_config.get_domain_config(domain)

          pf_ip_address_id = domain_config.pf_ip_address_id
          pf_ip_address    = domain_config.pf_ip_address
          pf_public_port   = domain_config.pf_public_port

          if pf_public_port.nil?
            pf_public_port_file = machine.data_dir.join('pf_public_port')
            if pf_public_port_file.file?
              File.read(pf_public_port_file).each_line do |line|
                pf_public_port = line.strip
              end
              domain_config.pf_public_port = pf_public_port
            end
          end

          if not pf_ip_address and pf_ip_address_id and pf_public_port
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

          if domain_config.keypair.nil? && domain_config.ssh_key.nil?
            sshkeyfile_file = machine.data_dir.join('sshkeyfile')
            if sshkeyfile_file.file?
              domain_config.ssh_key = sshkeyfile_file.to_s
            end
          end

          nic_ip_address = fetch_nic_ip_address(server.nics, domain_config)

          ssh_info = {
                       :host => pf_ip_address || nic_ip_address,
                       :port => pf_public_port
                     }
          ssh_info = ssh_info.merge({
            :private_key_path => domain_config.ssh_key,
            :password         => nil
          }) unless domain_config.ssh_key.nil?
          ssh_info = ssh_info.merge({ :username => domain_config.ssh_user }) unless domain_config.ssh_user.nil?
          ssh_info
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
