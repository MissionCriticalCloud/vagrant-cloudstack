require "vagrant"

module VagrantPlugins
  module Cloudstack
    class Config < Vagrant.plugin("2", :config)
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

      # Network uuid that the instance should use
      #
      # @return [String]
      attr_accessor :network_id

      # Network name that the instance should use
      #
      # @return [String]
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

      # IP address id to use for port forwarding rule
      #
      # @return [String]
      attr_accessor :pf_ip_address_id

      # public port to use for port forwarding rule
      #
      # @return [String]
      attr_accessor :pf_public_port

      # private port to use for port forwarding rule
      #
      # @return [String]
      attr_accessor :pf_private_port

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


      def initialize(domain_specific=false)
        @host                      = UNSET_VALUE
        @name                      = UNSET_VALUE
        @path                      = UNSET_VALUE
        @port                      = UNSET_VALUE
        @scheme                    = UNSET_VALUE
        @api_key                   = UNSET_VALUE
        @secret_key                = UNSET_VALUE
        @instance_ready_timeout    = UNSET_VALUE
        @domain_id                 = UNSET_VALUE
        @network_id                = UNSET_VALUE
        @network_name              = UNSET_VALUE
        @network_type              = UNSET_VALUE
        @project_id                = UNSET_VALUE
        @service_offering_id       = UNSET_VALUE
        @service_offering_name     = UNSET_VALUE
        @template_id               = UNSET_VALUE
        @template_name             = UNSET_VALUE
        @zone_id                   = UNSET_VALUE
        @zone_name                 = UNSET_VALUE
        @keypair                   = UNSET_VALUE
        @pf_ip_address_id          = UNSET_VALUE
        @pf_public_port            = UNSET_VALUE
        @pf_private_port           = UNSET_VALUE
        @security_group_ids        = UNSET_VALUE
        @display_name              = UNSET_VALUE
        @group                     = UNSET_VALUE
        @security_group_names      = UNSET_VALUE
        @security_groups           = UNSET_VALUE
        @user_data                 = UNSET_VALUE


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
        # Host must be nil, since we can't default that
        @host                   = nil if @host == UNSET_VALUE

        # Name must be nil, since we can't default that
        @name                   = nil if @name == UNSET_VALUE

        # Path must be nil, since we can't default that
        @path                   = nil if @path == UNSET_VALUE

        # Port must be nil, since we can't default that
        @port                   = nil if @port == UNSET_VALUE

        # We default the scheme to whatever the user has specifid in the .fog file
        # *OR* whatever is default for the provider in the fog library
        @scheme                 = nil if @scheme == UNSET_VALUE

        # Try to get access keys from environment variables, they will
        # default to nil if the environment variables are not present
        @api_key                = ENV['CLOUDSTACK_API_KEY'] if @api_key == UNSET_VALUE
        @secret_key             = ENV['CLOUDSTACK_SECRET_KEY'] if @secret_key == UNSET_VALUE

        # Set the default timeout for waiting for an instance to be ready
        @instance_ready_timeout = 120 if @instance_ready_timeout == UNSET_VALUE

        # Domain id must be nil, since we can't default that
        @domain_id              = nil if @domain_id == UNSET_VALUE

        # Network uuid must be nil, since we can't default that
        @network_id             = nil if @network_id == UNSET_VALUE

        # Network uuid must be nil, since we can't default that
        @network_name           = nil if @network_name == UNSET_VALUE

        # NetworkType is 'Advanced' by default
        @network_type           = "Advanced" if @network_type == UNSET_VALUE

        # Project uuid must be nil, since we can't default that
        @project_id             = nil if @project_id == UNSET_VALUE

        # Service offering uuid must be nil, since we can't default that
        @service_offering_id    = nil if @service_offering_id == UNSET_VALUE

        # Service offering name must be nil, since we can't default that
        @service_offering_name  = nil if @service_offering_name == UNSET_VALUE

        # Template uuid must be nil, since we can't default that
        @template_id            = nil if @template_id == UNSET_VALUE

        # Template name must be nil, since we can't default that
        @template_name          = nil if @template_name == UNSET_VALUE

        # Zone uuid must be nil, since we can't default that
        @zone_id                = nil if @zone_id == UNSET_VALUE

        # Zone uuid must be nil, since we can't default that
        @zone_name              = nil if @zone_name == UNSET_VALUE

        # Keypair defaults to nil
        @keypair                = nil if @keypair == UNSET_VALUE

        # IP address id must be nil, since we can't default that
        @pf_ip_address_id       = nil if @pf_ip_address_id == UNSET_VALUE

        # Public port must be nil, since we can't default that
        @pf_public_port         = nil if @pf_public_port == UNSET_VALUE

        # Private port must be nil, since we can't default that
        @pf_private_port        = nil if @pf_private_port == UNSET_VALUE

        # Security Group IDs must be nil, since we can't default that
        @security_group_ids     = [] if @security_group_ids == UNSET_VALUE

        # Security Group Names must be nil, since we can't default that
        @security_group_names   = [] if @security_group_names == UNSET_VALUE

        # Security Groups must be nil, since we can't default that
        @security_groups        = [] if @security_groups == UNSET_VALUE

        # Display name must be nil, since we can't default that
        @display_name           = nil if @display_name == UNSET_VALUE

        # Group must be nil, since we can't default that
        @group                  = nil if @group == UNSET_VALUE

        # User Data is nil by default
        @user_data              = nil if @user_data == UNSET_VALUE

        # Compile our domain specific configurations only within
        # NON-DOMAIN-SPECIFIC configurations.
        if !@__domain_specific
          @__domain_config.each do |domain, blocks|
            config = self.class.new(true).merge(self)

            # Execute the configuration for each block
            blocks.each { |b| b.call(config) }

            # The domain name of the configuration always equals the
            # domain config name:
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
          # Get the configuration for the domain we're using and validate only
          # that domain.
          config = get_domain_config(@domain)

          if !config.use_fog_profile
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
        if !@__finalized
          raise "Configuration must be finalized before calling this method."
        end

        # Return the compiled domain config
        @__compiled_domain_configs[name] || self
      end
    end
  end
end
