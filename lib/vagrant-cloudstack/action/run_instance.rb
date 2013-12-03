require "log4r"
require 'pp'   # XXX FIXME REMOVE WHEN NOT NEEDED

require 'vagrant/util/retryable'

require 'vagrant-cloudstack/util/timer'

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
          env[:metrics] ||= {}

          # Get the domain we're going to booting up in
          domain = env[:machine].provider_config.domain

          # Get the configs
          domain_config       = env[:machine].provider_config.get_domain_config(domain)
          zone_id             = domain_config.zone_id
          network_id          = domain_config.network_id
          network_type        = domain_config.network_type
          project_id          = domain_config.project_id
          service_offering_id = domain_config.service_offering_id
          template_id         = domain_config.template_id
          keypair             = domain_config.keypair

          pf_ip_address_id    = domain_config.pf_ip_address_id
          pf_public_port      = domain_config.pf_public_port
          pf_private_port     = domain_config.pf_private_port

          # If there is no keypair then warn the user
          if !keypair
            env[:ui].warn(I18n.t("vagrant_cloudstack.launch_no_keypair"))
          end

          # Launch!
          env[:ui].info(I18n.t("vagrant_cloudstack.launching_instance"))
          env[:ui].info(" -- Service offering UUID: #{service_offering_id}")
          env[:ui].info(" -- Template UUID: #{template_id}")
          env[:ui].info(" -- Project UUID: #{project_id}") if project_id != nil
          env[:ui].info(" -- Zone UUID: #{zone_id}")
          env[:ui].info(" -- Network UUID: #{network_id}") if network_id
          env[:ui].info(" -- Keypair: #{keypair}") if keypair

          local_user = ENV['USER'].dup
          local_user.gsub!(/[^-a-z0-9_]/i, "")
          prefix = env[:root_path].basename.to_s
          prefix.gsub!(/[^-a-z0-9_]/i, "")
          display_name = local_user + "_" + prefix + "_#{Time.now.to_i}"

          begin
            case network_type
            when "Advanced"
              options = {
                :display_name       => display_name,
                :zone_id            => zone_id,
                :flavor_id          => service_offering_id,
                :image_id           => template_id,
                :network_ids        => [network_id]
              }
            when "Basic"
              options = {
                :display_name       => display_name,
                :zone_id            => zone_id,
                :flavor_id          => service_offering_id,
                :image_id           => template_id
              }
            end

            options['project_id'] = project_id if project_id != nil
            options['key_name'] = keypair if keypair != nil

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
          # XXX FIXME does cloudstack+fog return the job id rather than
          # server id?
          env[:machine].id = server.id

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
                port_forwarding_rule =  response["queryasyncjobresultresponse"]["jobresult"]["portforwardingrule"]
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
          destroy_env[:config_validate] = false
          destroy_env[:force_confirm_destroy] = true
          env[:action_runner].run(Action.action_destroy, destroy_env)
        end
      end
    end
  end
end
