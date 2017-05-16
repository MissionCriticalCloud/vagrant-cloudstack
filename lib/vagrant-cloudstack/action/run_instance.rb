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
          @security_groups = []
        end

        def call(env)
          # Initialize metrics if they haven't been
          env[:metrics]         ||= {}
          @env = env

          # Get the domain we're going to booting up in
          @domain        = @env[:machine].provider_config.domain_id
          # Get the configs
          @domain_config = @env[:machine].provider_config.get_domain_config(@domain)

          sanitize_domain_config

          @zone             = CloudstackResource.new(@domain_config.zone_id, @domain_config.zone_name, 'zone')
          @networks         = CloudstackResource.create_list(@domain_config.network_id, @domain_config.network_name, 'network')
          @service_offering = CloudstackResource.new(@domain_config.service_offering_id, @domain_config.service_offering_name, 'service_offering')
          @disk_offering    = CloudstackResource.new(@domain_config.disk_offering_id, @domain_config.disk_offering_name, 'disk_offering')
          @template         = CloudstackResource.new(@domain_config.template_id, @domain_config.template_name || @env[:machine].config.vm.box, 'template')
          @pf_ip_address    = CloudstackResource.new(@domain_config.pf_ip_address_id, @domain_config.pf_ip_address, 'public_ip_address')

          if @zone.is_undefined?
            @env[:ui].error("No Zone specified!")
            exit(false)
          end

          begin
            @resource_service.sync_resource(@zone, { available: true })
            @resource_service.sync_resource(@service_offering, {listall: true})
            @resource_service.sync_resource(@disk_offering, {listall: true})
            @resource_service.sync_resource(@template, {zoneid: @zone.id, templatefilter: 'executable', listall: true})
            @resource_service.sync_resource(@pf_ip_address)
          rescue CloudstackResourceNotFound => e
            @env[:ui].error(e.message)
            exit(false)
          end

          cs_zone = @env[:cloudstack_compute].zones.find{ |f| f.id == @zone.id }
          if cs_zone.network_type.downcase == 'basic'
            # No network specification in basic zone
            @env[:ui].warn(I18n.t('vagrant_cloudstack.basic_network', :zone_name => @zone.name)) if !@networks.empty? && (@networks[0].id || @networks[0].name)
            @networks = [CloudstackResource.new(nil, nil, 'network')]

            # No portforwarding in basic zone, so none of the below
            @domain_config.pf_ip_address               = nil
            @domain_config.pf_ip_address_id            = nil
            @domain_config.pf_public_port              = nil
            @domain_config.pf_public_rdp_port          = nil
            @domain_config.pf_public_port_randomrange  = nil
          else
            @networks.each do |network|
              @resource_service.sync_resource(network)
            end
          end

          if cs_zone.security_groups_enabled
            prepare_security_groups
          else
            if !@domain_config.security_group_ids.empty? || !@domain_config.security_group_names.empty? || !@domain_config.security_groups.empty?
              @env[:ui].warn(I18n.t('vagrant_cloudstack.security_groups_disabled', :zone_name => @zone.name))
            end
            @domain_config.security_group_ids        = []
            @domain_config.security_group_names      = []
            @domain_config.security_groups           = []
          end

          @domain_config.display_name = generate_display_name if @domain_config.display_name.nil?

          # If there is no keypair or keyfile then warn the user
          if @domain_config.keypair.nil? && @domain_config.ssh_key.nil?
            @env[:ui].warn(I18n.t('vagrant_cloudstack.launch_no_keypair_no_sshkey'))
            store_ssh_keypair("vagacs_#{@domain_config.display_name}_#{sprintf('%04d', rand(9999))}",
                              nil, @domain, @domain_config.project_id)
          end


          # Launch!
          @env[:ui].info(I18n.t('vagrant_cloudstack.launching_instance'))
          @env[:ui].info(" -- Display Name: #{@domain_config.display_name}")
          @env[:ui].info(" -- Group: #{@domain_config.group}") if @domain_config.group
          @env[:ui].info(" -- Service offering: #{@service_offering.name} (#{@service_offering.id})")
          @env[:ui].info(" -- Disk offering: #{@disk_offering.name} (#{@disk_offering.id})") unless @disk_offering.id.nil?
          @env[:ui].info(" -- Template: #{@template.name} (#{@template.id})")
          @env[:ui].info(" -- Project UUID: #{@domain_config.project_id}") unless @domain_config.project_id.nil?
          @env[:ui].info(" -- Zone: #{@zone.name} (#{@zone.id})")
          @networks.each do |network|
            @env[:ui].info(" -- Network: #{network.name} (#{network.id})")
          end
          @env[:ui].info(" -- Keypair: #{@domain_config.keypair}") if @domain_config.keypair
          @env[:ui].info(' -- User Data: Yes') if @domain_config.user_data
          @security_groups.each do |security_group|
              @env[:ui].info(" -- Security Group: #{security_group.name} (#{security_group.id})")
          end

          server = create_vm

          # Wait for the instance to be ready first
          wait_for_instance_ready(server)

          store_volumes(server)

          store_password(server)

          begin
            configure_networking
          rescue CloudstackResourceNotFound => e
            @env[:ui].error(e.message)
            terminate
            exit(false)
          end

          unless @env[:interrupted]
            wait_for_communicator_ready
            @env[:ui].info(I18n.t('vagrant_cloudstack.ready'))
          end

          # Terminate the instance if we were interrupted
          terminate if @env[:interrupted]

          @app.call(@env)
        end

        def store_volumes(server)
          volumes = @env[:cloudstack_compute].volumes.find_all { |f| f.server_id == server.id }
          # volumes refuses to be iterated directly, do it by index
          (0...volumes.length).each do |idx|
            unless volumes[idx].type == 'ROOT'
              volumes_file = @env[:machine].data_dir.join('volumes')
              volumes_file.open('a+') do |f|
                f.write("#{volumes[idx].id}\n")
              end
            end
          end
        end

        def sanitize_domain_config
          # Accept a single entry as input, convert it to array
          @domain_config.pf_trusted_networks = [@domain_config.pf_trusted_networks] if @domain_config.pf_trusted_networks

          if @domain_config.network_id.nil?
            # Use names if ids are not present
            @domain_config.network_id = []

            if @domain_config.network_name.nil?
              @domain_config.network_name = []
            else
              @domain_config.network_name = Array(@domain_config.network_name)
            end
          else
            # Use ids if present
            @domain_config.network_id = Array(@domain_config.network_id)
            @domain_config.network_name = []
          end
        end

        def configure_networking
          enable_static_nat_rules

          evaluate_pf_private_port
          evaluate_pf_private_rdp_port


          create_port_forwardings
          # First create_port_forwardings,
          # as it may generate 'pf_public_port' or 'pf_public_rdp_port',
          # which after this may need a firewall rule
          configure_firewall
        end

        def enable_static_nat_rules
          unless @domain_config.static_nat.empty?
            @domain_config.static_nat.each do |rule|
              enable_static_nat( rule)
            end
          end
        end

        def generate_display_name
          local_user = ENV['USER'] ? ENV['USER'].dup : 'VACS'
          local_user.gsub!(/[^-a-z0-9_]/i, '')
          prefix = @env[:root_path].basename.to_s
          prefix.gsub!(/[^-a-z0-9_]/i, '')

          local_user + '_' + prefix + "_#{Time.now.to_i}"
        end

        def wait_for_communicator_ready
          @env[:metrics]['instance_ssh_time'] = Util::Timer.time do
            # Wait for communicator to be ready.
            communicator = @env[:machine].communicate.instance_variable_get('@logger').instance_variable_get('@name')
            @env[:ui].info(I18n.t('vagrant_cloudstack.waiting_for_communicator', :communicator => communicator.to_s.upcase))
            while true
              # If we're interrupted then just back out
              break if @env[:interrupted]
              break if @env[:machine].communicate.ready?
              sleep 2
            end
          end
          @logger.info("Time for SSH ready: #{@env[:metrics]['instance_ssh_time']}")
        end

        def wait_for_instance_ready( server)
          @env[:metrics]['instance_ready_time'] = Util::Timer.time do
            tries = @domain_config.instance_ready_timeout / 2

            @env[:ui].info(I18n.t('vagrant_cloudstack.waiting_for_ready'))
            begin
              retryable(:on => Fog::Errors::TimeoutError, :tries => tries) do
                # If we're interrupted don't worry about waiting
                next if @env[:interrupted]

                # Wait for the server to be ready
                server.wait_for(2) { ready? }
              end
            rescue Fog::Errors::TimeoutError
              # Delete the instance
              terminate

              # Notify the user
              raise Errors::InstanceReadyTimeout,
                    :timeout => @domain_config.instance_ready_timeout
            end
          end
          @logger.info("Time to instance ready: #{@env[:metrics]['instance_ready_time']}")
        end

        def create_vm
          server = nil
          begin
            options = {
                :display_name => @domain_config.display_name,
                :group => @domain_config.group,
                :zone_id => @zone.id,
                :flavor_id => @service_offering.id,
                :image_id => @template.id
            }

            unless @networks.empty?
              nets = @networks.map(&:id).compact.join(",")
              options['network_ids'] = nets unless nets.empty?
            end
            options['security_group_ids'] = @security_groups.map{|security_group| security_group.id}.join(',') unless @security_groups.empty?
            options['project_id'] = @domain_config.project_id unless @domain_config.project_id.nil?
            options['key_name'] = @domain_config.keypair unless @domain_config.keypair.nil?
            options['name'] = @domain_config.name unless @domain_config.name.nil?
            options['ip_address'] = @domain_config.private_ip_address unless @domain_config.private_ip_address.nil?
            options['disk_offering_id'] = @disk_offering.id unless @disk_offering.id.nil?

            if @domain_config.user_data != nil
              options['user_data'] = Base64.urlsafe_encode64(@domain_config.user_data)
              if options['user_data'].length > 2048
                raise Errors::UserdataError,
                      :userdataLength => options['user_data'].length
              end
            end

            server = @env[:cloudstack_compute].servers.create(options)
          rescue Fog::Compute::Cloudstack::NotFound => e
            # Invalid subnet doesn't have its own error so we catch and
            # check the error message here.
            # XXX FIXME vpc?
            if e.message =~ /subnet ID/
              raise Errors::FogError,
                    :message => "Subnet ID not found: #{@networks.map(&:id).compact.join(",")}"
            end

            raise
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Immediately save the ID since it is created at this point.
          @env[:machine].id = server.id
          server
        end

        def prepare_security_groups
          # Can't use Security Group IDs and Names at the same time
          # Let's use IDs by default...
          if @domain_config.security_group_ids.empty? and !@domain_config.security_group_names.empty?
            #@domain_config.security_group_ids = @domain_config.security_group_names.map { |name|  name_to_id(@env, name, 'security_group') }
            @security_groups = @domain_config.security_group_names.map do |name|
              group = CloudstackResource.new(nil, name, 'security_group')
              @resource_service.sync_resource(group)
              group
            end
          elsif !@domain_config.security_group_ids.empty?
            @security_groups = @domain_config.security_group_ids.map do |id|
              group = CloudstackResource.new(id, nil, 'security_group')
              @resource_service.sync_resource(group)
              group
            end
          end

          # Still no security group ids huh?
          # Let's try to create some security groups from specifcation, if provided.
          if !@domain_config.security_groups.empty? and @security_groups.empty?
            @domain_config.security_groups.each do |security_group|
              security_group = create_security_group( security_group)
              @security_groups.push(security_group)
            end
          end
        end

        def evaluate_pf_private_port
          if @domain_config.pf_private_port.nil?

            communicator = @env[:machine].communicate.instance_variable_get('@logger').instance_variable_get('@name')
            comm_obj = @env[:machine].config.send(communicator)

            @domain_config.pf_private_port = comm_obj.port if comm_obj.respond_to?('port')
            @domain_config.pf_private_port = comm_obj.guest_port if comm_obj.respond_to?('guest_port')
            @domain_config.pf_private_port = comm_obj.default.port if (comm_obj.respond_to?('default') && comm_obj.default.respond_to?('port'))
          end
        end

        def evaluate_pf_private_rdp_port
          @domain_config.pf_private_rdp_port = @env[:machine].config.vm.rdp.port if (@env[:machine].config.vm.respond_to?(:rdp) && @env[:machine].config.vm.rdp.respond_to?(:port))
        end

        def configure_firewall

          unless @pf_ip_address.is_undefined?
            ports = [ Hash[publicport: 'pf_public_port',     privateport: 'pf_private_port'] ]
            ports <<  Hash[publicport: 'pf_public_rdp_port', privateport: 'pf_private_rdp_port']

            ports.each do |port_set|
              if @pf_ip_address.details.has_key?('vpcid')
                forward_portname = port_set[:privateport]
              else
                forward_portname = port_set[:publicport]
              end
              check_portname = port_set[:publicport]
              # As we take care of implicit/auto port_forward of 'pf_public_port' we do Firewall as well, possibly
              if (@domain_config.pf_ip_address_id || @domain_config.pf_ip_address) &&
                  @domain_config.send(check_portname) &&
                  @domain_config.pf_trusted_networks &&
                  !@domain_config.pf_open_firewall
                # Allow access to public port from trusted networks only
                fw_rule_trusted_networks = {
                    :ipaddressid => @domain_config.pf_ip_address_id,
                    :ipaddress => @domain_config.pf_ip_address,
                    :protocol => 'tcp',
                    :startport => @domain_config.send(forward_portname),
                    :endport => @domain_config.send(forward_portname),
                    :cidrlist => @domain_config.pf_trusted_networks.join(',')
                }
                @domain_config.firewall_rules = [] unless @domain_config.firewall_rules
                @domain_config.firewall_rules << fw_rule_trusted_networks
              end
            end
          end

          unless @domain_config.firewall_rules.empty?

            # Inspect port_forwarding rules to make firewall rules
            if @pf_ip_address.details.has_key?('vpcid')
              port_name = :privateport
            else
              port_name = :publicport
            end
            unless @domain_config.port_forwarding_rules.empty?
              @domain_config.port_forwarding_rules.each do |port_forwarding_rule|
                if port_forwarding_rule[:generate_firewall] && @domain_config.pf_trusted_networks && !port_forwarding_rule[:openfirewall]
                  # Allow access to public port from trusted networks only
                  fw_rule_trusted_networks = {
                      :ipaddressid => port_forwarding_rule[:ipaddressid],
                      :ipaddress => port_forwarding_rule[:ipaddress],
                      :protocol => port_forwarding_rule[:protocol],
                      :startport => port_forwarding_rule[port_name],
                      :endport => port_forwarding_rule[port_name],
                      :cidrlist => @domain_config.pf_trusted_networks.join(',')
                  }
                  @domain_config.firewall_rules = [] unless @domain_config.firewall_rules
                  @domain_config.firewall_rules << fw_rule_trusted_networks
                end
              end
            end

            # Fill in the blanks for all rules
            @domain_config.firewall_rules.each do |firewall_rule|
              firewall_rule[:ipaddressid] = @domain_config.pf_ip_address_id if firewall_rule[:ipaddressid].nil?
              firewall_rule[:ipaddress] = @domain_config.pf_ip_address if firewall_rule[:ipaddress].nil?
              firewall_rule[:cidrlist] = @domain_config.pf_trusted_networks.join(',') if firewall_rule[:cidrlist].nil?
              firewall_rule[:protocol] = 'tcp' if firewall_rule[:protocol].nil?
              firewall_rule[:startport] = firewall_rule[:endport] if firewall_rule[:startport].nil?
            end

            # Apply all rules
            @domain_config.firewall_rules.each do |firewall_rule|
              create_firewall_rule( firewall_rule )
            end
          end
        end

        def create_port_forwardings
          unless @pf_ip_address.is_undefined?
            guest_windows = false || @env[:machine].config.vm.guest == :windows || @env[:machine].communicate.instance_variable_get('@logger').instance_variable_get('@name') == 'winrm'

            ports = [ Hash[:public_port => 'pf_public_port',     :private_port => 'pf_private_port'] ]
            ports <<  Hash[:public_port => 'pf_public_rdp_port', :private_port => 'pf_private_rdp_port'] if guest_windows

            ports.each do |port_set|
              # Implicit/automatic Port forward for 'private' port (SSH/WinRM or RDP)
              # Also sets 'public_port' port to random port if missing
              public_port_name = port_set[:public_port]
              private_port_name = port_set[:private_port]
              if (@domain_config.pf_ip_address_id || @domain_config.pf_ip_address) && (@domain_config.send(public_port_name) || @domain_config.pf_public_port_randomrange)
                port_forwarding_rule = {
                    :ipaddressid => @domain_config.pf_ip_address_id,
                    :ipaddress => @domain_config.pf_ip_address,
                    :protocol => 'tcp',
                    :publicport => @domain_config.send(public_port_name),
                    :privateport => @domain_config.send(private_port_name),
                    :openfirewall => @domain_config.pf_open_firewall
                }

                public_port = create_randomport_forwarding_rule(
                    port_forwarding_rule,
                    @domain_config.pf_public_port_randomrange[:start]...@domain_config.pf_public_port_randomrange[:end],
                    public_port_name
                )
                @domain_config.send("#{public_port_name}=", public_port)
              end
            end
          end

          unless @domain_config.port_forwarding_rules.empty?
            @domain_config.port_forwarding_rules.each do |port_forwarding_rule|
              port_forwarding_rule[:ipaddressid] = @domain_config.pf_ip_address_id if port_forwarding_rule[:ipaddressid].nil?
              port_forwarding_rule[:ipaddress] = @domain_config.pf_ip_address if port_forwarding_rule[:ipaddress].nil?
              port_forwarding_rule[:protocol] = 'tcp' if port_forwarding_rule[:protocol].nil?
              port_forwarding_rule[:openfirewall] = @domain_config.pf_open_firewall if port_forwarding_rule[:openfirewall].nil?
              port_forwarding_rule[:publicport] = port_forwarding_rule[:privateport] if port_forwarding_rule[:publicport].nil?
              port_forwarding_rule[:privateport] = port_forwarding_rule[:publicport] if port_forwarding_rule[:privateport].nil?

              create_port_forwarding_rule(port_forwarding_rule)
            end
          end
        end

        def create_randomport_forwarding_rule(rule, randomrange, filename)
          # Only if pf_public_port is nil, will generate and try
          # Otherwise, functionaly the same as just create_port_forwarding_rule
          pf_public_port = rule[:publicport]
          retryable(:on => DuplicatePFRule, :tries => 10) do
            begin
              rule[:publicport] = rand(randomrange) if pf_public_port.nil?

              create_port_forwarding_rule(rule)

              if pf_public_port.nil?
                pf_port_file = @env[:machine].data_dir.join(filename)
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
          pf_public_port.nil? ? (rule[:publicport]) : (pf_public_port)
        end

        def store_ssh_keypair(keyname, account = nil, domainid = nil, projectid = nil)
          response = @env[:cloudstack_compute].create_ssh_key_pair(keyname, account, domainid, projectid)
          sshkeypair = response['createsshkeypairresponse']['keypair']

          # Save private key to file
          sshkeyfile_file = @env[:machine].data_dir.join('sshkeyfile')
          sshkeyfile_file.open('w') do |f|
            f.write("#{sshkeypair['privatekey']}")
          end
          @domain_config.ssh_key = sshkeyfile_file.to_s

          # Save keyname to file for terminate_instance
          sshkeyname_file = @env[:machine].data_dir.join('sshkeyname')
          sshkeyname_file.open('w') do |f|
            f.write("#{sshkeypair['name']}")
          end

          @domain_config.keypair =  sshkeypair['name']
        end

        def store_password(server)
          password = nil
          if server.password_enabled and server.respond_to?('job_id')
            server_job_result = @env[:cloudstack_compute].query_async_job_result({:jobid => server.job_id})
            if server_job_result.nil?
              @env[:ui].warn(' -- Failed to retrieve job_result for retrieving the password')
              return
            end

            while true
              server_job_result = @env[:cloudstack_compute].query_async_job_result({:jobid => server.job_id})
              if server_job_result['queryasyncjobresultresponse']['jobstatus'] != 0
                password = server_job_result['queryasyncjobresultresponse']['jobresult']['virtualmachine']['password']
                break
              else
                sleep 2
              end
            end

            @env[:ui].info("Password of virtualmachine: #{password}")
            # Set the password on the current communicator
            @domain_config.vm_password = password

            # Save password to file
            vmcredentials_file = @env[:machine].data_dir.join('vmcredentials')
            vmcredentials_file.open('w') do |f|
              f.write("#{password}")
            end
          end
        end

        def create_security_group(security_group)
          begin
            sgid = @env[:cloudstack_compute].create_security_group(:name        => security_group[:name],
                                                                  :description => security_group[:description])['createsecuritygroupresponse']['securitygroup']['id']
            security_group_object = CloudstackResource.new(sgid, security_group[:name], 'security_group')
            @env[:ui].info(" -- Security Group #{security_group[:name]} created with ID: #{sgid}")
          rescue Exception => e
            if e.message =~ /already exis/
              security_group_object = CloudstackResource.new(nil, security_group[:name], 'security_group')
              @resource_service.sync_resource(security_group_object)
              @env[:ui].info(" -- Security Group #{security_group_object.name} found with ID: #{security_group_object.id}")
            end
          end

          # security group is created and we have it's ID
          # so we add the rules... Does it really matter if they already exist ? CLoudstack seems to take care of that!
          security_group[:rules].each do |rule|
            rule_options = {
                :securityGroupId => security_group_object.id,
                :protocol        => rule[:protocol],
                :startport       => rule[:startport],
                :endport         => rule[:endport],
                :cidrlist        => rule[:cidrlist]
            }

            # The rule[:type] is either ingress or egress, but the method call looks the same.
            # We build a dynamic method name and then send it off.
            @env[:cloudstack_compute].send("authorize_security_group_#{rule[:type]}".to_sym, rule_options)
            @env[:ui].info(" --- #{rule[:type].capitalize} Rule added: #{rule[:protocol]} from #{rule[:startport]} to #{rule[:endport]} (#{rule[:cidrlist]})")
          end

          # and record the security group ids for future deletion (of rules and groups if possible)
          security_groups_file = @env[:machine].data_dir.join('security_groups')
          security_groups_file.open('a+') do |f|
            f.write("#{security_group_object.id}\n")
          end
          security_group_object
        end

        def recover(env)
          return if env['vagrant.error'].is_a?(Vagrant::Errors::VagrantError)

          if env[:machine].provider.state.id != :not_created
            # Undo the import
            terminate
          end
        end

        def enable_static_nat(rule)
          @env[:ui].info(I18n.t('vagrant_cloudstack.enabling_static_nat'))

          begin
            ip_address = sync_ip_address(rule[:ipaddressid], rule[:ipaddress])
          rescue IpNotFoundException
            return
          end

          @env[:ui].info(" -- IP address : #{ip_address.name} (#{ip_address.id})")

          options = {
              :command          => 'enableStaticNat',
              :ipaddressid      => ip_address_id,
              :virtualmachineid => @env[:machine].id
          }

          begin
            resp = @env[:cloudstack_compute].request(options)
            is_success = resp['enablestaticnatresponse']['success']

            if is_success != 'true'
              @env[:ui].warn(" -- Failed to enable static nat: #{resp['enablestaticnatresponse']['errortext']}")
              return
            end
          rescue Fog::Compute::Cloudstack::Error => e
            raise Errors::FogError, :message => e.message
          end

          # Save ipaddress id to the data dir so it can be disabled when the instance is destroyed
          static_nat_file = @env[:machine].data_dir.join('static_nat')
          static_nat_file.open('a+') do |f|
            f.write("#{ip_address.id}\n")
          end
        end

        def create_port_forwarding_rule(rule)
          port_forwarding_rule = nil
          @env[:ui].info(I18n.t('vagrant_cloudstack.creating_port_forwarding_rule'))

          begin
            ip_address = sync_ip_address(rule[:ipaddressid], rule[:ipaddress])
          rescue IpNotFoundException
            return
          end

          @env[:ui].info(" -- IP address    : #{ip_address.name} (#{ip_address.id})")
          @env[:ui].info(" -- Protocol      : #{rule[:protocol]}")
          @env[:ui].info(" -- Public port   : #{rule[:publicport]}")
          @env[:ui].info(" -- Private port  : #{rule[:privateport]}")
          @env[:ui].info(" -- Open Firewall : #{rule[:openfirewall]}")

          if ip_address.details.has_key?('associatednetworkid')
            network = @networks.find{ |f| f.id == ip_address.details['associatednetworkid']}
          elsif ip_address.details.has_key?('vpcid')
            # In case of VPC and ip has not yet been used, a network MUST be specified
            network = @networks.find{ |f| f.details['vpcid'] == ip_address.details['vpcid']}
          end

          options = {
              :networkid        => network.id,
              :ipaddressid      => ip_address.id,
              :publicport       => rule[:publicport],
              :privateport      => rule[:privateport],
              :protocol         => rule[:protocol],
              :openfirewall     => rule[:openfirewall],
              :virtualmachineid => @env[:machine].id
          }

          options.delete(:openfirewall) if network.details.has_key?('vpcid')
          begin
            resp = @env[:cloudstack_compute].create_port_forwarding_rule(options)
            job_id = resp['createportforwardingruleresponse']['jobid']

            if job_id.nil?
              @env[:ui].warn(" -- Failed to create port forwarding rule: #{resp['createportforwardingruleresponse']['errortext']}")
              return
            end

            while true
              response = @env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
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
          port_forwarding_file = @env[:machine].data_dir.join('port_forwarding')
          port_forwarding_file.open('a+') do |f|
            f.write("#{port_forwarding_rule['id']}\n")
          end
        end

        def create_firewall_rule(rule)
          acl_name = ''
          firewall_rule = nil
          @env[:ui].info(I18n.t('vagrant_cloudstack.creating_firewall_rule'))

          ip_address = CloudstackResource.new(rule[:ipaddressid], rule[:ipaddress], 'public_ip_address')
          @resource_service.sync_resource(ip_address)

          @env[:ui].info(" -- IP address : #{ip_address.name} (#{ip_address.id})")
          @env[:ui].info(" -- Protocol   : #{rule[:protocol]}")
          @env[:ui].info(" -- CIDR list  : #{rule[:cidrlist]}")
          @env[:ui].info(" -- Start port : #{rule[:startport]}")
          @env[:ui].info(" -- End port   : #{rule[:endport]}")
          @env[:ui].info(" -- ICMP code  : #{rule[:icmpcode]}")
          @env[:ui].info(" -- ICMP type  : #{rule[:icmptype]}")

          if ip_address.details.has_key?('vpcid')
            network = @networks.find{ |f| f.id == ip_address.details['associatednetworkid']}
            acl_id = network.details['aclid']

            raise CloudstackResourceNotFound.new("No ACL found associated with VPC tier #{network.details['name']} (id: #{network.details['id']})") unless acl_id

            resp = @env[:cloudstack_compute].list_network_acl_lists(
              id:  network.details[acl_id]
            )
            acl_name = resp['listnetworkacllistsresponse']['networkacllist'][0]['name']

            resp = @env[:cloudstack_compute].list_network_acls(
              aclid:  network.details['aclid']
            )
            number = 0
            if resp["listnetworkaclsresponse"].key?("networkacl")
              resp["listnetworkaclsresponse"]["networkacl"].each{ |ace| number = [number, ace["number"]].max }
            end
            number = number+1

            command_string  = 'createNetworkACL'
            response_string = 'createnetworkaclresponse'
            type_string = 'networkacl'
            options = {
                :command     => command_string,
                :aclid       => network.details['aclid'],
                :action      => 'Allow',
                :protocol    => rule[:protocol],
                :cidrlist    => rule[:cidrlist],
                :startport   => rule[:startport],
                :endport     => rule[:endport],
                :icmpcode    => rule[:icmpcode],
                :icmptype    => rule[:icmptype],
                :number      => number,
                :traffictype => 'Ingress'
            }
          else
            command_string = 'createFirewallRule'
            response_string = 'createfirewallruleresponse'
            type_string = 'firewallrule'
            options = {
                :command          => command_string,
                :ipaddressid      => ip_address.id,
                :protocol         => rule[:protocol],
                :cidrlist         => rule[:cidrlist],
                :startport        => rule[:startport],
                :endeport         => rule[:endport],
                :icmpcode         => rule[:icmpcode],
                :icmptype         => rule[:icmptype]
            }
          end

          begin
            resp = @env[:cloudstack_compute].request(options)
            job_id = resp[response_string]['jobid']

            if job_id.nil?
              @env[:ui].warn(" -- Failed to create firewall rule: #{resp[response_string]['errortext']}")
              return
            end

            while true
              response = @env[:cloudstack_compute].query_async_job_result({:jobid => job_id})
              if response['queryasyncjobresultresponse']['jobstatus'] != 0
                firewall_rule = response['queryasyncjobresultresponse']['jobresult'][type_string]
                break
              else
                sleep 2
              end
            end
          rescue Fog::Compute::Cloudstack::Error => e
            if e.message =~ /The range specified,.*conflicts with rule/
              @env[:ui].warn(" -- Failed to create firewall rule: #{e.message}")
            elsif e.message =~ /Default ACL cannot be modified/
              @env[:ui].warn(" -- Failed to create network acl: #{e.message}: #{acl_name}")
            else
              raise Errors::FogError, :message => e.message
            end
          end

          unless firewall_rule.nil?
            # Save firewall rule id to the data dir so it can be released when the instance is destroyed
            firewall_file = @env[:machine].data_dir.join('firewall')
            firewall_file.open('a+') do |f|
              f.write("#{firewall_rule['id']},#{type_string}\n")
            end
          end
        end

        def terminate
          destroy_env = @env.dup
          destroy_env.delete(:interrupted)
          destroy_env[:config_validate]       = false
          destroy_env[:force_confirm_destroy] = true
          @env[:action_runner].run(Action.action_destroy, destroy_env)
        end

        private

        def sync_ip_address(ip_address_id, ip_address_value)
          ip_address = CloudstackResource.new(ip_address_id, ip_address_value, 'public_ip_address')

          if ip_address.is_undefined?
            message = 'IP address is not specified. Skip creating port forwarding rule.'
            @logger.info(message)
            @env[:ui].info(I18n.t(message))
            raise IpNotFoundException
          end

          @resource_service.sync_resource(ip_address)

          ip_address
        end
      end
    end
  end
end
