require 'log4r'
require 'vagrant/util/retryable'
require 'vagrant-cloudstack/exceptions/exceptions'
require 'vagrant-cloudstack/util/timer'
require 'vagrant-cloudstack/model/cloudstack_resource'
require 'vagrant-cloudstack/service/cloudstack_resource_service'

module VagrantPlugins
  module Cloudstack
    module Action
      # This runs the configured instance.
      class RunInstance
        include Vagrant::Util::Retryable
        include VagrantPlugins::Cloudstack::Model
        include VagrantPlugins::Cloudstack::Service
        include VagrantPlugins::Cloudstack::Exceptions

        def initialize(app, env)
          @app              = app
          @logger           = Log4r::Logger.new('vagrant_cloudstack::action::run_instance')
          @resource_service = CloudstackResourceService.new(env[:cloudstack_compute], env[:ui])
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics]         ||= {}

          # Get the domain we're going to booting up in
          domain        = env[:machine].provider_config.domain_id
          # Get the configs
          domain_config = env[:machine].provider_config.get_domain_config(domain)

          @zone             = CloudstackResource.new(domain_config.zone_id, domain_config.zone_name, 'zone')
          @network          = CloudstackResource.new(domain_config.network_id, domain_config.network_name, 'network')
          @service_offering = CloudstackResource.new(domain_config.service_offering_id, domain_config.service_offering_name, 'service_offering')
          @disk_offering    = CloudstackResource.new(domain_config.disk_offering_id, domain_config.disk_offering_name, 'disk_offering')
          @template         = CloudstackResource.new(domain_config.template_id, domain_config.template_name || env[:machine].config.vm.box, 'template')

          hostname                    = domain_config.name
          network_type                = domain_config.network_type
          project_id                  = domain_config.project_id
          keypair                     = domain_config.keypair
          static_nat                  = domain_config.static_nat
          pf_ip_address_id            = domain_config.pf_ip_address_id
          pf_ip_address               = domain_config.pf_ip_address
          pf_public_port              = domain_config.pf_public_port
          pf_public_rdp_port          = domain_config.pf_public_rdp_port
          pf_public_port_randomrange  = domain_config.pf_public_port_randomrange
          pf_private_port             = domain_config.pf_private_port
          pf_open_firewall            = domain_config.pf_open_firewall
          pf_trusted_networks         = domain_config.pf_trusted_networks
          port_forwarding_rules       = domain_config.port_forwarding_rules
          firewall_rules              = domain_config.firewall_rules
          display_name                = domain_config.display_name
          group                       = domain_config.group
          security_group_ids          = domain_config.security_group_ids
          security_group_names        = domain_config.security_group_names
          security_groups             = domain_config.security_groups
          user_data                   = domain_config.user_data
          ssh_key                     = domain_config.ssh_key
          ssh_user                    = domain_config.ssh_user
          vm_user                     = domain_config.vm_user
          vm_password                 = domain_config.vm_password
          private_ip_address          = domain_config.private_ip_address

          @resource_service.sync_resource(@zone, { 'available' => true })
          @resource_service.sync_resource(@network)
          @resource_service.sync_resource(@service_offering)
          @resource_service.sync_resource(@disk_offering)
          @resource_service.sync_resource(@template, {'zoneid' => @zone.id, 'templatefilter' => 'executable' })

          # Can't use Security Group IDs and Names at the same time
          # Let's use IDs by default...
          if security_group_ids.empty? and !security_group_names.empty?
            security_group_ids = security_group_names.map { |name| name_to_id(env, name, 'security_group') }
          elsif !security_group_ids.empty?
            security_group_names = security_group_ids.map { |id| id_to_name(env, id, 'security_group') }
          end

          # Still no security group ids huh?
          # Let's try to create some security groups from specifcation, if provided.
          if !security_groups.empty? and security_group_ids.empty?
            security_groups.each do |security_group|
              sgname, sgid = create_security_group(env, security_group)
              security_group_names.push(sgname)
              security_group_ids.push(sgid)
            end
          end

          # If there is no keypair then warn the user
          if !keypair
            env[:ui].warn(I18n.t('vagrant_cloudstack.launch_no_keypair'))
          end

          if display_name.nil?
            local_user = ENV['USER'].dup
            local_user.gsub!(/[^-a-z0-9_]/i, '')
            prefix = env[:root_path].basename.to_s
            prefix.gsub!(/[^-a-z0-9_]/i, '')
            display_name = local_user + '_' + prefix + "_#{Time.now.to_i}"
          end

          # Launch!
          env[:ui].info(I18n.t('vagrant_cloudstack.launching_instance'))
          env[:ui].info(" -- Display Name: #{display_name}")
          env[:ui].info(" -- Group: #{group}") if group
          env[:ui].info(" -- Service offering: #{@service_offering.name} (#{@service_offering.id})")
          env[:ui].info(" -- Disk offering: #{@disk_offering.name} (#{@disk_offering.id})") unless @disk_offering.id.nil?
          env[:ui].info(" -- Template: #{@template.name} (#{@template.id})")
          env[:ui].info(" -- Project UUID: #{project_id}") unless project_id.nil?
          env[:ui].info(" -- Zone: #{@zone.name} (#{@zone.id})")
          env[:ui].info(" -- Network: #{@network.name} (#{@network.id})") unless @network.id.nil?
          env[:ui].info(" -- Keypair: #{keypair}") if keypair
          env[:ui].info(' -- User Data: Yes') if user_data
          security_group_names.zip(security_group_ids).each do |security_group_name, security_group_id|
              env[:ui].info(" -- Security Group: #{security_group_name} (#{security_group_id})")
          end

          begin
            options = {
                :display_name => display_name,
                :group        => group,
                :zone_id      => @zone.id,
                :flavor_id    => @service_offering.id,
                :image_id     => @template.id
            }

            options['network_ids'] = @network.id unless @network.id.nil?
            options['security_group_ids'] = security_group_ids unless security_group_ids.nil?
            options['project_id'] = project_id unless project_id.nil?
            options['key_name']   = keypair unless keypair.nil?
            options['name']       = hostname unless hostname.nil?
            options['ip_address'] = private_ip_address unless private_ip_address.nil?
            options['disk_offering_id'] = @disk_offering.id unless @disk_offering.id.nil?

            if user_data != nil
              options['user_data'] = Base64.urlsafe_encode64(user_data)
              if options['user_data'].length > 2048
                raise Errors::UserdataError,
                      :userdataLength => options['user_data'].length
              end
            end

            server = env[:cloudstack_compute].servers.create(options)
          rescue Fog::Compute::Cloudstack::NotFound => e
            # Invalid subnet doesn't have its own error so we catch and
            # check the error message here.
            # XXX FIXME vpc?
            if e.message =~ /subnet ID/
              raise Errors::FogError,
                    :message => "Subnet ID not found: #{@network.id}"
            end

            raise
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id                     = server.id

          # Wait for the instance to be ready first
          env[:metrics]['instance_ready_time'] = Util::Timer.time do
            tries = domain_config.instance_ready_timeout / 2

            env[:ui].info(I18n.t('vagrant_cloudstack.waiting_for_ready'))
            begin
              retryable(:on => Fog::Errors::TimeoutError, :tries => tries) do
                # If we're interrupted don't worry about waiting
                next if env[:interrupted]

                # Wait for the server to be ready
                server.wait_for(2) { ready? }
              end
            rescue Fog::Errors::TimeoutError
              # Delete the instance
              terminate(env)

              # Notify the user
              raise Errors::InstanceReadyTimeout,
                 :timeout => domain_config.instance_ready_timeout
            end
          end

          @logger.info("Time to instance ready: #{env[:metrics]['instance_ready_time']}")

          if server.password_enabled and server.respond_to?("job_id")
            store_password(env, domain_config, server.job_id)
          end

          if !static_nat.empty?
            static_nat.each do |rule|
              enable_static_nat(env, rule)
            end
          end


          pf_private_rdp_port = 3389
          pf_private_rdp_port = env[:machine].config.vm.rdp.port if ( env[:machine].config.vm.respond_to?(:rdp) && env[:machine].config.vm.rdp.respond_to?(:port) )

          if pf_private_port.nil?
            communicator = env[:machine].communicate.instance_variable_get('@logger').instance_variable_get('@name')
            comm_obj = env[:machine].config.send(communicator)

            pf_private_port = comm_obj.port if comm_obj.respond_to?('port')
            pf_private_port = comm_obj.guest_port if comm_obj.respond_to?('guest_port')
            pf_private_port = comm_obj.default.port if (comm_obj.respond_to?('default') && comm_obj.default.respond_to?('port'))
          end

          if (pf_ip_address_id || pf_ip_address) && (pf_public_port || pf_public_port_randomrange)
            port_forwarding_rule = {
              :ipaddressid  => pf_ip_address_id,
              :ipaddress    => pf_ip_address,
              :protocol     => 'tcp',
              :publicport   => pf_public_port,
              :privateport  => pf_private_port,
              :openfirewall => (pf_open_firewall && pf_trusted_networks) ? false : pf_open_firewall
            }

            pf_public_port = domain_config.pf_public_port = create_randomport_forwarding_rule( env, port_forwarding_rule, pf_public_port_randomrange, 'pf_public_port')

            if pf_open_firewall && pf_trusted_networks
              # Allow access to public port from trusted networks only
              fw_rule_trusted_networks = {
                  :ipaddressid  => pf_ip_address_id,
                  :ipaddress    => pf_ip_address,
                  :protocol     => "tcp",
                  :startport    => pf_public_port,
                  :endport      => pf_public_port,
                  :cidrlist     => pf_trusted_networks
              }
              firewall_rules = [] unless firewall_rules
              firewall_rules << fw_rule_trusted_networks
            end
          end

          if (pf_ip_address_id || pf_ip_address) && (pf_public_rdp_port || pf_public_port_randomrange)
            port_forwarding_rule = {
              :ipaddressid  => pf_ip_address_id,
              :ipaddress    => pf_ip_address,
              :protocol     => 'tcp',
              :publicport   => pf_public_rdp_port,
              :privateport  => pf_private_rdp_port,
              :openfirewall => (pf_open_firewall && pf_trusted_networks) ? false : pf_open_firewall
            }

            pf_public_rdp_port = domain_config.pf_public_rdp_port = create_randomport_forwarding_rule( env, port_forwarding_rule, pf_public_port_randomrange, 'pf_public_rdp_port')

            if pf_open_firewall && pf_trusted_networks
              # Allow access to public port from trusted networks only
              fw_rule_trusted_networks = {
                  :ipaddressid  => pf_ip_address_id,
                  :ipaddress    => pf_ip_address,
                  :protocol     => "tcp",
                  :startport    => pf_public_rdp_port,
                  :endport      => pf_public_rdp_port,
                  :cidrlist     => pf_trusted_networks
              }
              firewall_rules = [] unless firewall_rules
              firewall_rules << fw_rule_trusted_networks
            end
          end

          if !port_forwarding_rules.empty?
            port_forwarding_rules.each do |port_forwarding_rule|
              create_port_forwarding_rule(env, port_forwarding_rule)
            end
          end

          if !firewall_rules.empty?
            firewall_rules.each do |firewall_rule|
              create_firewall_rule(env, firewall_rule)
            end
          end

          if !env[:interrupted]
            env[:metrics]['instance_ssh_time'] = Util::Timer.time do
              # Wait for communicator to be ready.
              communicator = env[:machine].communicate.instance_variable_get("@logger").instance_variable_get("@name")
              env[:ui].info(I18n.t('vagrant_cloudstack.waiting_for_communicator', :communicator => communicator.to_s.upcase))
              while true
                # If we're interrupted then just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
                sleep 2
              end
            end

            @logger.info("Time for SSH ready: #{env[:metrics]['instance_ssh_time']}")

            # Ready and booted!
            env[:ui].info(I18n.t('vagrant_cloudstack.ready'))
          end

          # Terminate the instance if we were interrupted
          terminate(env) if env[:interrupted]

          @app.call(env)
        end

        def create_randomport_forwarding_rule(env, rule, randomrange, filename)
          # Only if pf_public_port is nil, will generate and try
          # Otherwise, functionaly the same as just create_port_forwarding_rule
          pf_public_port = rule[:publicport]
          retryable(:on => DuplicatePFRule, :tries => 10) do
            begin
              rule[:publicport] = rand(randomrange) if pf_public_port.nil?

              create_port_forwarding_rule(env, rule)
              
              if pf_public_port.nil?
                pf_port_file = env[:machine].data_dir.join(filename)
                pf_port_file.open('a+') do |f|
                  f.write("#{rule[:publicport]}")
                end
              end
            rescue Errors::FogError => e
              if pf_public_port.nil? && !(e.message =~ /The range specified,.*conflicts with rule.*which has/).nil?
                raise DuplicatePFRule, :message => e.message
              else
                raise Errors::FogError, :message => e.message
              end
            end
          end
          return rule[:publicport] if pf_public_port.nil?
        end

        def store_password(env, domain_config, job_id)
          server_job_result = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
          if server_job_result.nil?
            env[:ui].warn(' -- Failed to retrieve job_result for retrieving the password')
            return
          end

          while true
            server_job_result = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
            if server_job_result['queryasyncjobresultresponse']['jobstatus'] != 0
              password = server_job_result['queryasyncjobresultresponse']['jobresult']['virtualmachine']['password']
              break
            else
              sleep 2
            end
          end

          env[:ui].info("Password of virtualmachine: #{password}")
          # Set the password on the current communicator
          domain_config.vm_password = password

          # Save password to file
          vmcredentials_file = env[:machine].data_dir.join('vmcredentials')
          vmcredentials_file.open('a+') do |f|
            f.write("#{password}")
          end
        end

        def create_security_group(env, security_group)
          begin
            sgid = env[:cloudstack_compute].create_security_group(:name        => security_group[:name],
                                                                  :description => security_group[:description])['createsecuritygroupresponse']['securitygroup']['id']
            env[:ui].info(" -- Security Group #{security_group[:name]} created with ID: #{sgid}")
          rescue Exception => e
            if e.message =~ /already exis/
              sgid = name_to_id(env, security_group[:name], 'security_group')
              env[:ui].info(" -- Security Group #{security_group[:name]} found with ID: #{sgid}")
            end
          end

          # security group is created and we have it's ID
          # so we add the rules... Does it really matter if they already exist ? CLoudstack seems to take care of that!
          security_group[:rules].each do |rule|
            rule_options = {
                :securityGroupId => sgid,
                :protocol        => rule[:protocol],
                :startport       => rule[:startport],
                :endport         => rule[:endport],
                :cidrlist        => rule[:cidrlist]
            }

            # The rule[:type] is either ingress or egress, but the method call looks the same.
            # We build a dynamic method name and then send it off.
            env[:cloudstack_compute].send("authorize_security_group_#{rule[:type]}".to_sym, rule_options)
            env[:ui].info(" --- #{rule[:type].capitalize} Rule added: #{rule[:protocol]} from #{rule[:startport]} to #{rule[:endport]} (#{rule[:cidrlist]})")
          end

          # and record the security group ids for future deletion (of rules and groups if possible)
          security_groups_file = env[:machine].data_dir.join('security_groups')
          security_groups_file.open('a+') do |f|
            f.write("#{sgid}\n")
          end
          [security_group[:name], sgid]
        end

        def recover(env)
          return if env['vagrant.error'].is_a?(Vagrant::Errors::VagrantError)

          if env[:machine].provider.state.id != :not_created
            # Undo the import
            terminate(env)
          end
        end

        def enable_static_nat(env, rule)
          env[:ui].info(I18n.t('vagrant_cloudstack.enabling_static_nat'))

          begin
            ip_address = sync_ip_address(rule[:ipaddressid], rule[:ipaddress])
          rescue IpNotFoundException
            return
          end

          env[:ui].info(" -- IP address : #{ip_address.name} (#{ip_address.id})")

          options = {
              :command          => 'enableStaticNat',
              :ipaddressid      => ip_address_id,
              :virtualmachineid => env[:machine].id
          }

          begin
            resp = env[:cloudstack_compute].request(options)
            is_success = resp['enablestaticnatresponse']['success']

            if is_success != 'true'
              env[:ui].warn(" -- Failed to enable static nat: #{resp['enablestaticnatresponse']['errortext']}")
              return
            end
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Save ipaddress id to the data dir so it can be disabled when the instance is destroyed
          static_nat_file = env[:machine].data_dir.join('static_nat')
          static_nat_file.open('a+') do |f|
            f.write("#{ip_address.id}\n")
          end
        end

        def create_port_forwarding_rule(env, rule)
          env[:ui].info(I18n.t('vagrant_cloudstack.creating_port_forwarding_rule'))

          begin
            ip_address = sync_ip_address(rule[:ipaddressid], rule[:ipaddress])
          rescue IpNotFoundException
            return
          end

          env[:ui].info(" -- IP address    : #{ip_address.name} (#{ip_address.id})")
          env[:ui].info(" -- Protocol      : #{rule[:protocol]}")
          env[:ui].info(" -- Public port   : #{rule[:publicport]}")
          env[:ui].info(" -- Private port  : #{rule[:privateport]}")
          env[:ui].info(" -- Open Firewall : #{rule[:openfirewall]}")

          options = {
              :ipaddressid      => ip_address.id,
              :publicport       => rule[:publicport],
              :privateport      => rule[:privateport],
              :protocol         => rule[:protocol],
              :openfirewall     => rule[:openfirewall],
              :virtualmachineid => env[:machine].id
          }

          begin
            resp = env[:cloudstack_compute].create_port_forwarding_rule(options)
            job_id = resp['createportforwardingruleresponse']['jobid']

            if job_id.nil?
              env[:ui].warn(" -- Failed to create port forwarding rule: #{resp['createportforwardingruleresponse']['errortext']}")
              return
            end

            while true
              response = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
              if response['queryasyncjobresultresponse']['jobstatus'] != 0
                port_forwarding_rule = response['queryasyncjobresultresponse']['jobresult']['portforwardingrule']
                break
              else
                sleep 2
              end
            end
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Save port forwarding rule id to the data dir so it can be released when the instance is destroyed
          port_forwarding_file = env[:machine].data_dir.join('port_forwarding')
          port_forwarding_file.open('a+') do |f|
            f.write("#{port_forwarding_rule['id']}\n")
          end
        end

        def create_firewall_rule(env, rule)
          env[:ui].info(I18n.t('vagrant_cloudstack.creating_firewall_rule'))

          begin
            ip_address = sync_ip_address(rule[:ipaddressid], rule[:ipaddress])
          rescue IpNotFoundException
            return
          end

          env[:ui].info(" -- IP address : #{ip_address.name} (#{ip_address.id})")
          env[:ui].info(" -- Protocol   : #{rule[:protocol]}")
          env[:ui].info(" -- CIDR list  : #{rule[:cidrlist]}")
          env[:ui].info(" -- Start port : #{rule[:startport]}")
          env[:ui].info(" -- End port   : #{rule[:endport]}")
          env[:ui].info(" -- ICMP code  : #{rule[:icmpcode]}")
          env[:ui].info(" -- ICMP type  : #{rule[:icmptype]}")

          options = {
              :command          => 'createFirewallRule',
              :ipaddressid      => ip_address.id,
              :protocol         => rule[:protocol],
              :cidrlist         => rule[:cidrlist],
              :startport        => rule[:startport],
              :endeport         => rule[:endport],
              :icmpcode         => rule[:icmpcode],
              :icmptype         => rule[:icmptype]
          }

          begin
            resp = env[:cloudstack_compute].request(options)
            job_id = resp['createfirewallruleresponse']['jobid']

            if job_id.nil?
              env[:ui].warn(" -- Failed to create firewall rule: #{resp['createfirewallruleresponse']['errortext']}")
              return
            end

            while true
              response = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
              if response['queryasyncjobresultresponse']['jobstatus'] != 0
                firewall_rule = response['queryasyncjobresultresponse']['jobresult']['firewallrule']
                break
              else
                sleep 2
              end
            end
          rescue Fog::Compute::Cloudstack::Error => e
            if e.message =~ /The range specified,.*conflicts with rule/
              env[:ui].warn(" -- Failed to create firewall rule: #{e.message}")
            else
              raise Errors::FogError, :message => e.message
            end
          end

          unless firewall_rule.nil?
            # Save firewall rule id to the data dir so it can be released when the instance is destroyed
            firewall_file = env[:machine].data_dir.join('firewall')
            firewall_file.open('a+') do |f|
              f.write("#{firewall_rule['id']}\n")
            end
          end
        end

        def terminate(env)
          destroy_env = env.dup
          destroy_env.delete(:interrupted)
          destroy_env[:config_validate]       = false
          destroy_env[:force_confirm_destroy] = true
          env[:action_runner].run(Action.action_destroy, destroy_env)
        end

        private

        def sync_ip_address(ip_address_id, ip_address_value)
          ip_address = CloudstackResource.new(ip_address_id, ip_address_value, 'public_ip_address')

          if ip_address.is_undefined?
            message = 'IP address is not specified. Skip creating port forwarding rule.'
            @logger.info(message)
            env[:ui].info(I18n.t(message))
            raise IpNotFoundException
          end

          @resource_service.sync_resource(ip_address)

          ip_address
        end

        def translate_from_to(env, resource_type, options)
          if resource_type == 'public_ip_address'
            pluralised_type = 'public_ip_addresses'
          else
            pluralised_type = "#{resource_type}s"
          end

          full_response = env[:cloudstack_compute].send("list_#{pluralised_type}".to_sym, options)
          full_response["list#{pluralised_type.tr('_', '')}response"][resource_type.tr('_', '')]
        end

        def resourcefield_to_id(env, resource_type, resource_field, resource_field_value, options={})
          env[:ui].info("Fetching UUID for #{resource_type} with #{resource_field} '#{resource_field_value}'")
          full_response = translate_from_to(env, resource_type, options)
          result        = full_response.find {|type| type[resource_field] == resource_field_value }
          result['id']
        end

        def id_to_resourcefield(env, resource_id, resource_type, resource_field, options={})
          env[:ui].info("Fetching #{resource_field} for #{resource_type} with UUID '#{resource_id}'")
          options = options.merge({'id' => resource_id})
          full_response = translate_from_to(env, resource_type, options)
          full_response[0][resource_field]
        end

        def name_to_id(env, resource_name, resource_type, options={})
          resourcefield_to_id(env, resource_type, 'name', resource_name, options)
        end

        def id_to_name(env, resource_id, resource_type, options={})
          id_to_resourcefield(env, resource_id, resource_type, 'name', options)
        end

        def ip_to_id(env, ip_address, options={})
          resourcefield_to_id(env, 'public_ip_address', 'ipaddress', ip_address, options)
        end

        def id_to_ip(env, ip_address_id, options={})
          id_to_resourcefield(env, ip_address_id, 'public_ip_address', 'ipaddress', options)
        end
      end
    end
  end
end
