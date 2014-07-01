require "log4r"
require "vagrant/util/retryable"
require "vagrant-cloudstack/util/timer"

module VagrantPlugins
  module Cloudstack
    module Action
      # This runs the configured instance.
      class RunInstance
        include Vagrant::Util::Retryable

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_cloudstack::action::run_instance")
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics]         ||= {}

          # Get the domain we're going to booting up in
          domain                = env[:machine].provider_config.domain_id

          # Get the configs
          domain_config         = env[:machine].provider_config.get_domain_config(domain)
          hostname              = domain_config.name
          zone_id               = domain_config.zone_id
          zone_name             = domain_config.zone_name
          network_id            = domain_config.network_id
          network_name          = domain_config.network_name
          network_type          = domain_config.network_type
          #TODO: Fog currently does not support the project apis, when that is fixed we should add that here too.
          project_id            = domain_config.project_id
          service_offering_id   = domain_config.service_offering_id
          service_offering_name = domain_config.service_offering_name
          template_id           = domain_config.template_id
          template_name         = domain_config.template_name
          keypair               = domain_config.keypair
          pf_ip_address_id      = domain_config.pf_ip_address_id
          pf_public_port        = domain_config.pf_public_port
          pf_private_port       = domain_config.pf_private_port
          display_name          = domain_config.display_name
          group                 = domain_config.group
          security_group_ids    = domain_config.security_group_ids
          security_group_names  = domain_config.security_group_names
          security_groups       = domain_config.security_groups
          user_data             = domain_config.user_data

          # If for some reason the user have specified both network_name and network_id, take the id since that is
          # more specific than the name. But always try to fetch the name of the network to present to the user.
          if network_id.nil? and network_name
            network_id = name_to_id(env, network_name, "network")
          elsif network_id
            network_name = id_to_name(env, network_id, "network")
          end

          if zone_id.nil? and zone_name
            zone_id = name_to_id(env, zone_name, "zone", {'available' => true})
          elsif zone_id
            zone_name = id_to_name(env, zone_id, "zone", {'available' => true})
          end

          if service_offering_id.nil? and service_offering_name
            service_offering_id = name_to_id(env, service_offering_name, "service_offering")
          elsif service_offering_id
            service_offering_name = id_to_name(env, service_offering_id, "service_offering")
          end

          if template_id.nil? and template_name
            template_id = name_to_id(env, template_name, "template", {'zoneid'         => zone_id,
                                                                      'templatefilter' => 'executable'})
          elsif template_id
            template_name = id_to_name(env, template_id, "template", {'zoneid'         => zone_id,
                                                                      'templatefilter' => 'executable'})
          end

          # Can't use Security Group IDs and Names at the same time
          # Let's use IDs by default...
          if security_group_ids.nil? and !security_group_names.nil?
            security_group_ids = security_group_names.map { |name| name_to_id(env, name, "security_group") }
          elsif !security_group_ids.nil?
            security_group_names = security_group_ids.map { |id| id_to_name(env, id, "security_group") }
          end

          if security_group_ids.nil? or security_group_ids.empty?
            security_group_ids, security_group_names = create_security_groups(env, security_groups)
          end

          # If there is no keypair then warn the user
          if !keypair
            env[:ui].warn(I18n.t("vagrant_cloudstack.launch_no_keypair"))
          end

          if display_name.nil?
            local_user = ENV['USER'].dup
            local_user.gsub!(/[^-a-z0-9_]/i, "")
            prefix = env[:root_path].basename.to_s
            prefix.gsub!(/[^-a-z0-9_]/i, "")
            display_name = local_user + "_" + prefix + "_#{Time.now.to_i}"
          end

          # Launch!
          env[:ui].info(I18n.t("vagrant_cloudstack.launching_instance"))
          env[:ui].info(" -- Display Name: #{display_name}")
          env[:ui].info(" -- Group: #{group}") if group
          env[:ui].info(" -- Service offering: #{service_offering_name} (#{service_offering_id})")
          env[:ui].info(" -- Template: #{template_name} (#{template_id})")
          env[:ui].info(" -- Project UUID: #{project_id}") if project_id != nil
          env[:ui].info(" -- Zone: #{zone_name} (#{zone_id})")
          env[:ui].info(" -- Network: #{network_name} (#{network_id})") if !network_id.nil? or !network_name.nil?
          env[:ui].info(" -- Keypair: #{keypair}") if keypair
          env[:ui].info(" -- User Data: Yes") if user_data
          if !security_group_ids.nil?
            security_group_names.zip(security_group_ids).each do |security_group_name, security_group_id|
              env[:ui].info(" -- Security Group: #{security_group_name} (#{security_group_id})")
            end
          end

          begin
            options = {
                :display_name => display_name,
                :group        => group,
                :zone_id      => zone_id,
                :flavor_id    => service_offering_id,
                :image_id     => template_id
            }

            if network_type == "Advanced"
              options['network_ids'] = [network_id]
            elsif network_type == "Basic"
              options['security_group_ids'] = security_group_ids
            end
            options['project_id'] = project_id if project_id != nil
            options['key_name']   = keypair if keypair != nil
            options['name']       = hostname if hostname != nil

            if user_data != nil
              options['user_data'] = Base64.encode64(user_data)
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
                    :message => "Subnet ID not found: #{network_id}"
            end

            raise
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Immediately save the ID since it is created at this point.
          env[:machine].id                     = server.id

          # Wait for the instance to be ready first
          env[:metrics]["instance_ready_time"] = Util::Timer.time do
            tries = domain_config.instance_ready_timeout / 2

            env[:ui].info(I18n.t("vagrant_cloudstack.waiting_for_ready"))
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
                    timeout: domain_config.instance_ready_timeout
            end
          end

          @logger.info("Time to instance ready: #{env[:metrics]["instance_ready_time"]}")

          if pf_ip_address_id and pf_public_port and pf_private_port
            create_port_forwarding_rule(env, pf_ip_address_id,
                                        pf_public_port, pf_private_port)
          end

          if !env[:interrupted]
            env[:metrics]["instance_ssh_time"] = Util::Timer.time do
              # Wait for SSH to be ready.
              env[:ui].info(I18n.t("vagrant_cloudstack.waiting_for_ssh"))
              while true
                # If we're interrupted then just back out
                break if env[:interrupted]
                break if env[:machine].communicate.ready?
                sleep 2
              end
            end

            @logger.info("Time for SSH ready: #{env[:metrics]["instance_ssh_time"]}")

            # Ready and booted!
            env[:ui].info(I18n.t("vagrant_cloudstack.ready"))
          end

          # Terminate the instance if we were interrupted
          terminate(env) if env[:interrupted]

          @app.call(env)
        end

        def create_security_groups(env, security_groups)
            security_group_ids = []
            security_group_names = []
            security_groups.each do |sg|
              # Creating the security group and retrieving it's ID
              sgid = nil
              begin
                sgid = env[:cloudstack_compute].create_security_group(:name        => sg[:name],
                                                                      :description => sg[:description])["createsecuritygroupresponse"]["securitygroup"]["id"]
                env[:ui].info(" -- Security Group #{sg[:name]} created with ID: #{sgid}")
              rescue Exception => e
                if e.message =~ /already exis/
                  sgid = name_to_id(env, sg[:name], "security_group")
                  env[:ui].info(" -- Security Group #{sg[:name]} found with ID: #{sgid}")
                end
              end

              # security group is created and we have it's ID
              # so we add the rules... Does it really matter if they already exist ? CLoudstack seems to take care of that!
              sg[:rules].each do |rule|
                rule_options = {
                    :securityGroupId => sgid,
                    :protocol        => rule[:protocol],
                    :startport       => rule[:startport],
                    :endport         => rule[:endport],
                    :cidrlist        => rule[:cidrlist]
                }
                env[:cloudstack_compute].send("authorize_security_group_#{rule[:type]}".to_sym, rule_options)
                env[:ui].info(" --- #{rule[:type].capitalize} Rule added: #{rule[:protocol]} from #{rule[:startport]} to #{rule[:endport]} (#{rule[:cidrlist]})")
              end

              # We want to use the Security groups we created
              security_group_ids.push(sgid)
              security_group_names.push(sg[:name])

              # and record the security group ids for future deletion (of rules and groups if possible)
              security_groups_file = env[:machine].data_dir.join('security_groups')
              security_groups_file.open('a+') do |f|
                f.write("#{sgid}\n")
              end
            end
          end
          [security_group_ids, security_group_names]
        end

        def recover(env)
          return if env["vagrant.error"].is_a?(Vagrant::Errors::VagrantError)

          if env[:machine].provider.state.id != :not_created
            # Undo the import
            terminate(env)
          end
        end

        def create_port_forwarding_rule(env, pf_ip_address_id, pf_public_port, pf_private_port)
          env[:ui].info(I18n.t("vagrant_cloudstack.creating_port_forwarding_rule"))

          begin
            response = env[:cloudstack_compute].list_public_ip_addresses({:id => pf_ip_address_id})
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end

          if response["listpublicipaddressesresponse"]["count"] == 0
            @logger.info("IP address #{pf_ip_address_id} not exists. Skip creating port forwarding rule.")
            env[:ui].info(I18n.t("IP address #{pf_ip_address_id} not exists. Skip creating port forwarding rule."))
            return
          end

          pf_ip_address = response["listpublicipaddressesresponse"]["publicipaddress"][0]["ipaddress"]

          env[:ui].info(" -- IP address ID: #{pf_ip_address_id}")
          env[:ui].info(" -- IP address: #{pf_ip_address}")
          env[:ui].info(" -- Public port: #{pf_public_port}")
          env[:ui].info(" -- Private port: #{pf_private_port}")

          options = {
              :ipaddressid      => pf_ip_address_id,
              :publicport       => pf_public_port,
              :privateport      => pf_private_port,
              :protocol         => "tcp",
              :virtualmachineid => env[:machine].id,
              :openfirewall     => "true"
          }

          begin
            job_id = env[:cloudstack_compute].create_port_forwarding_rule(options)["createportforwardingruleresponse"]["jobid"]
            while true
              response = env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
              if response["queryasyncjobresultresponse"]["jobstatus"] != 0
                port_forwarding_rule = response["queryasyncjobresultresponse"]["jobresult"]["portforwardingrule"]
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
          port_forwarding_file.open('w+') do |f|
            f.write(port_forwarding_rule["id"])
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

        def translate_from_to(env, resource_type, options)
          pluralised_type = "#{resource_type}s"
          full_response   = env[:cloudstack_compute].send("list_#{pluralised_type}".to_sym, options)
          full_response["list#{pluralised_type.tr('_', '')}response"][resource_type.tr('_', '')]
        end

        def name_to_id(env, resource_name, resource_type, options={})
          env[:ui].info("Fetching UUID for #{resource_type} named '#{resource_name}'")
          full_response = translate_from_to(env, resource_type, options)
          result        = full_response.find { |type| type["name"] == resource_name }
          result['id']
        end

        def id_to_name(env, resource_id, resource_type, options={})
          env[:ui].info("Fetching name for #{resource_type} with UUID '#{resource_id}'")
          options = options.merge({'id' => resource_id})
          full_response = translate_from_to(env, resource_type, options)
          full_response[0]['name']
        end
      end
    end
  end
end
