require "vagrant"

module VagrantPlugins
  module Cloudstack
    class Config < Vagrant.plugin("2", :config)
      INSTANCE_VAR_DEFAULT_NIL = %w(host name path port domain_id network_id network_name project_id service_offering_id service_offering_name
           template_id template_name zone_id zone_name keypair pf_ip_address_id pf_ip_address pf_public_port
           pf_public_rdp_port pf_private_port pf_trusted_networks display_name group user_data ssh_key ssh_user
           ssh_network_id ssh_network_name vm_user vm_password private_ip_address affinity_group_ids affinity_group_names).freeze
      INSTANCE_VAR_DEFAULT_EMPTY_ARRAY = %w(static_nat port_forwarding_rules firewall_rules security_group_ids security_group_names security_groups).freeze

      # Cloudstack api host.
      #
      # @return [String]
      attr_accessor :host

      # Hostname for the machine instance
      # This will be passed through to the api.
      #
      # @return [String]
      attr_accessor :name

      # Cloudstack api path.
      #
      # @return [String]
      attr_accessor :path

      # Cloudstack api port.
      #
      # @return [String]
      attr_accessor :port

      # Cloudstack api scheme
      #
      # @return [String]
      attr_accessor :scheme

      # The API key for accessing Cloudstack.
      #
      # @return [String]
      attr_accessor :api_key

      # The secret key for accessing Cloudstack.
      #
      # @return [String]
      attr_accessor :secret_key

      # The timeout to wait for an instance to become ready.
      #
      # @return [Fixnum]
      attr_accessor :instance_ready_timeout

      # Domain id to launch the instance into.
      #
      # @return [String]
      attr_accessor :domain_id

      # Network uuid(s) that the instance should use
      #
      # @return [String,Array]
      attr_accessor :network_id

      # Network name(s) that the instance should use
      #
      # @return [String,Array]
      attr_accessor :network_name

      # Network Type
      #
      # @return [String]
      attr_accessor :network_type

      # Project uuid that the instance should belong to
      #
      # @return [String]
      attr_accessor :project_id

      # Service offering uuid to use for the instance
      #
      # @return [String]
      attr_accessor :service_offering_id

      # Service offering name to use for the instance
      #
      # @return [String]
      attr_accessor :service_offering_name

      # Disk offering uuid to use for the instance
      #
      # @return [String]
      attr_accessor :disk_offering_id

      # Disk offering name to use for the instance
      #
      # @return [String]
      attr_accessor :disk_offering_name

      # Template uuid to use for the instance
      #
      # @return [String]
      attr_accessor :template_id

      # Template name to use for the instance
      #
      # @return [String]
      attr_accessor :template_name

      # Zone uuid to launch the instance into. If nil, it will
      # launch in default project.
      #
      # @return [String]
      attr_accessor :zone_id

      # Zone name to launch the instance into. If nil, it will
      # launch in default project.
      #
      # @return [String]
      attr_accessor :zone_name

      # The name of the keypair to use.
      #
      # @return [String]
      attr_accessor :keypair

      # Paramters for Static NAT
      #
      # @return [String]
      attr_accessor :static_nat

      # IP address id to use for port forwarding rule
      #
      # @return [String]
      attr_accessor :pf_ip_address_id

      # IP address to use for port forwarding rule
      #
      # @return [String]
      attr_accessor :pf_ip_address

      # public port to use for port forwarding rule
      #
      # @return [String]
      attr_accessor :pf_public_port

      # public port to use for port forwarding rule
      #
      # @return [String]
      attr_accessor :pf_public_rdp_port

      # private port to use for port forwarding rule
      #
      # @return [String]
      attr_accessor :pf_private_rdp_port

      # public port to use for port forwarding rule
      #
      # @return [Range]
      attr_accessor :pf_public_port_randomrange

      # private port to use for port forwarding rule
      #
      # @return [String]
      attr_accessor :pf_private_port

      # flag to enable/disable automatic open firewall rule
      #
      # @return [Boolean]
      attr_accessor :pf_open_firewall

      # CIDR List string of trusted networks
      #
      # @return [String]
      attr_accessor :pf_trusted_networks

      # comma separated list of port forwarding rules
      # (hash with rule parameters)
      #
      # @return [Array]
      attr_accessor :port_forwarding_rules

      # comma separated list of firewall rules
      # (hash with rule parameters)
      #
      # @return [Array]
      attr_accessor :firewall_rules

      # comma separated list of security groups id that going
      # to be applied to the virtual machine.
      #
      # @return [Array]
      attr_accessor :security_group_ids

      # comma separated list of security groups name that going
      # to be applied to the virtual machine.
      #
      # @return [Array]
      attr_accessor :security_group_names

      # comma separated list of security groups
      # (hash with ingress/egress rules)
      # to be applied to the virtual machine.
      #
      # @return [Array]
      attr_accessor :security_groups

      # display name for the instance
      #
      # @return [String]
      attr_accessor :display_name

      # group for the instance
      #
      # @return [String]
      attr_accessor :group

      # The user data string
      #
      # @return [String]
      attr_accessor :user_data

      # The key to be used when loging in to the vm via ssh
      #
      # @return [String]
      attr_accessor :ssh_key

      # The username to be used when loging in to the vm via ssh
      #
      # @return [String]
      attr_accessor :ssh_user

      # The network_id to be used when loging in to the vm via ssh
      #
      # @return [String]
      attr_accessor :ssh_network_id

      # The network_name to be used when loging in to the vm via ssh
      #
      # @return [String]
      attr_accessor :ssh_network_name

      # The username to be used when loging in to the vm
      #
      # @return [String]
      attr_accessor :vm_user

      # The username to be used when loging in to the vm
      #
      # @return [String]
      attr_accessor :vm_password

      # Private ip for the instance
      #
      # @return [String]
      attr_accessor :private_ip_address

      # Affinity Group IDs for the instance
      #
      # @return [String]
      attr_accessor :affinity_group_ids

      # Affinity Group Names for the instance
      #
      # @return [String]
      attr_accessor :affinity_group_names

      # flag to enable/disable expunge vm on destroy
      #
      # @return [Boolean]
      attr_accessor :expunge_on_destroy

      def initialize(domain_specific = false)
        # Initialize groups in bulk, re-use these groups to set defaults in bulk
        INSTANCE_VAR_DEFAULT_NIL.each do |instance_variable|
          instance_variable_set("@#{instance_variable}", UNSET_VALUE)
        end
        # Initialize groups in bulk, re-use these groups to set defaults in bulk
        INSTANCE_VAR_DEFAULT_EMPTY_ARRAY.each do |instance_variable|
          instance_variable_set("@#{instance_variable}", UNSET_VALUE)
        end

        @scheme                     = UNSET_VALUE
        @api_key                    = UNSET_VALUE
        @secret_key                 = UNSET_VALUE
        @instance_ready_timeout     = UNSET_VALUE
        @network_type               = UNSET_VALUE
        @pf_private_rdp_port        = UNSET_VALUE
        @pf_public_port_randomrange = UNSET_VALUE
        @pf_open_firewall           = UNSET_VALUE
        @expunge_on_destroy         = UNSET_VALUE

        # Internal state (prefix with __ so they aren't automatically
        # merged)
        @__compiled_domain_configs = {}
        @__finalized               = false
        @__domain_config           = {}
        @__domain_specific         = domain_specific
      end

      # Allows domain-specific overrides of any of the settings on this
      # configuration object. This allows the user to override things like
      # template and keypair name for domains. Example:
      #
      #     cloudstack.domain_config "abcd-ef01-2345-6789" do |domain|
      #       domain.template_id = "1234-5678-90ab-cdef"
      #       domain.keypair_name = "company-east"
      #     end
      #
      # @param [String] domain The Domain name to configure.
      # @param [Hash] attributes Direct attributes to set on the configuration
      #   as a shortcut instead of specifying a full block.
      # @yield [config] Yields a new domain configuration.
      def domain_config(domain, attributes=nil, &block)
        # Append the block to the list of domain configs for that domain.
        # We'll evaluate these upon finalization.
        @__domain_config[domain] ||= []

        # Append a block that sets attributes if we got one
        if attributes
          attr_block = lambda do |config|
            config.set_options(attributes)
          end

          @__domain_config[domain] << attr_block
        end

        # Append a block if we got one
        @__domain_config[domain] << block if block_given?
      end

      #-------------------------------------------------------------------
      # Internal methods.
      #-------------------------------------------------------------------

      def merge(other)
        super.tap do |result|
          # Copy over the domain specific flag. "True" is retained if either
          # has it.
          new_domain_specific = other.instance_variable_get(:@__domain_specific)
          result.instance_variable_set(
              :@__domain_specific, new_domain_specific || @__domain_specific)

          # Go through all the domain configs and prepend ours onto
          # theirs.
          new_domain_config = other.instance_variable_get(:@__domain_config)
          @__domain_config.each do |key, value|
            new_domain_config[key] ||= []
            new_domain_config[key] = value + new_domain_config[key]
          end

          # Set it
          result.instance_variable_set(:@__domain_config, new_domain_config)

          # Merge in the tags
          result.tags.merge!(self.tags)
          result.tags.merge!(other.tags)
        end
      end

      def finalize!
        INSTANCE_VAR_DEFAULT_NIL.each do |instance_variable|
          # ... must be nil, since we can't default that
          instance_variable_set("@#{instance_variable}", nil) if
              instance_variable_get("@#{instance_variable}") == UNSET_VALUE
        end

        INSTANCE_VAR_DEFAULT_EMPTY_ARRAY.each do |instance_variable|
          # ... must be empty array
          instance_variable_set("@#{instance_variable}", []) if
              instance_variable_get("@#{instance_variable}") == UNSET_VALUE
        end

        # We default the scheme to whatever the user has specifid in the .fog file
        # *OR* whatever is default for the provider in the fog library
        @scheme                 = nil if @scheme == UNSET_VALUE

        # Try to get access keys from environment variables, they will
        # default to nil if the environment variables are not present
        @api_key                = ENV['CLOUDSTACK_API_KEY'] if @api_key == UNSET_VALUE
        @secret_key             = ENV['CLOUDSTACK_SECRET_KEY'] if @secret_key == UNSET_VALUE

        # Set the default timeout for waiting for an instance to be ready
        @instance_ready_timeout = 120 if @instance_ready_timeout == UNSET_VALUE

        # NetworkType is 'Advanced' by default
        @network_type           = "Advanced" if @network_type == UNSET_VALUE

        # Private rdp port defaults to 3389
        @pf_private_rdp_port     = 3389 if @pf_private_rdp_port == UNSET_VALUE

        # Public port random-range, default to rfc6335 'Dynamic Ports'; "(never assigned)"
        @pf_public_port_randomrange = {:start=>49152, :end=>65535} if @pf_public_port_randomrange == UNSET_VALUE

        # Open firewall is true by default (for backwards compatibility)
        @pf_open_firewall       = true if @pf_open_firewall == UNSET_VALUE

        # expunge on destroy is nil by default
        @expunge_on_destroy     = false if @expunge_on_destroy == UNSET_VALUE

        # Compile our domain specific configurations only within
        # NON-DOMAIN-SPECIFIC configurations.
        unless @__domain_specific
          @__domain_config.each do |domain, blocks|
            config = self.class.new(true).merge(self)

            # Execute the configuration for each block
            blocks.each { |b| b.call(config) }

            # The domain name of the configuration always equals the domain config name:
            config.domain = domain

            # Finalize the configuration
            config.finalize!

            # Store it for retrieval
            @__compiled_domain_configs[domain] = config
          end
        end

        # Mark that we finalized
        @__finalized = true
      end

      def validate(machine)
        errors = []

        if @domain
          # Get the configuration for the domain we're using and validate only that domain.
          config = get_domain_config(@domain)

          unless config.use_fog_profile
            errors << I18n.t("vagrant_cloudstack.config.api_key_required") if \
               config.access_key_id.nil?
            errors << I18n.t("vagrant_cloudstack.config.secret_key_required") if \
               config.secret_access_key.nil?
          end
        end

        {"Cloudstack Provider" => errors}
      end

      # This gets the configuration for a specific domain. It shouldn't
      # be called by the general public and is only used internally.
      def get_domain_config(name)
        raise 'Configuration must be finalized before calling this method.' unless @__finalized

        # Return the compiled domain config
        @__compiled_domain_configs[name] || self
      end
    end
  end
end
