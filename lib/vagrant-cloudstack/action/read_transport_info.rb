module VagrantPlugins
  module Cloudstack
    module Action
      class ReadTransportInfo
        def initialize
          @public_port_fieldname = 'pf_public_port'
        end

        def retrieve_public_ip_port(cloudstack, domain_config, machine)
          pf_ip_address_id = domain_config.pf_ip_address_id
          pf_ip_address = domain_config.pf_ip_address
          pf_public_port = domain_config.send(@public_port_fieldname)

          if pf_public_port.nil?
            pf_public_port_file = machine.data_dir.join(@public_port_fieldname)
            if pf_public_port_file.file?
              File.read(pf_public_port_file).each_line do |line|
                pf_public_port = line.strip
              end
              domain_config.send("#{@public_port_fieldname}=", pf_public_port)
            end
          end

          if not pf_ip_address and pf_ip_address_id and pf_public_port
            begin
              response = cloudstack.list_public_ip_addresses({:id => pf_ip_address_id})
            rescue Fog::Compute::Cloudstack::Error => e
              raise Errors::FogError, :message => e.message
            end

            if (response['listpublicipaddressesresponse']['count']).zero?
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
