require 'log4r'

module VagrantPlugins
  module Cloudstack
    module Action
      class ReadInfo
        def fetch_nic_ip_address(nics)
          ssh_nic =
              if !@domain_config.ssh_network_id.nil?
                nics.find { |nic| nic['networkid'] == @domain_config.ssh_network_id }
              elsif !@domain_config.ssh_network_name.nil?
                nics.find { |nic| nic['networkname'] == @domain_config.ssh_network_name }
              else
                # When without neither ssh_network_id and ssh_network_name, use 1st nic
                nics[0]
              end

          ssh_nic ||= nics[0]
          ssh_nic['ipaddress']
        end

        def retrieve_public_ip_port(public_port_name)
          domain = @machine.provider_config.domain_id
          @domain_config = @machine.provider_config.get_domain_config(domain)

          pf_ip_address_id = @domain_config.pf_ip_address_id
          pf_ip_address = @domain_config.pf_ip_address
          pf_public_port = @domain_config.send(public_port_name)

          if pf_public_port.nil?
            pf_public_port_file = @machine.data_dir.join(public_port_name)
            if pf_public_port_file.file?
              File.read(pf_public_port_file).each_line do |line|
                pf_public_port = line.strip
              end
              @domain_config.send("#{public_port_name}=", pf_public_port)
            end
          end

          if not pf_ip_address and pf_ip_address_id and pf_public_port
            begin
              response = @cloudstack.list_public_ip_addresses({:id => pf_ip_address_id})
            rescue Fog::Compute::Cloudstack::Error => e
              raise Errors::FogError, :message => e.message
            end

            if response['listpublicipaddressesresponse']['count'] == 0
              @logger.info("IP address #{pf_ip_address_id} not exists.")
              env[:ui].info(I18n.t("IP address #{pf_ip_address_id} not exists."))
              pf_ip_address = nil
            else
              pf_ip_address = response['listpublicipaddressesresponse']['publicipaddress'][0]['ipaddress']
            end
          end
          return pf_ip_address, pf_public_port
        end
      end
    end
  end
end
