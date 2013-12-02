require "vagrant"

module VagrantPlugins
  module Cloudstack
    class Config < Vagrant.plugin("2", :config)
      # Cloudstack api host.
      #
      # @return [String]
      attr_accessor :host

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

      # Project uuid that the instance should belong to
      #
      # @return [String]
      attr_accessor :project_id

      # Service offering uuid to use for the instance
      #
      # @return [String]
      attr_accessor :service_offering_id

      # Template uuid to use for the instance
      #
      # @return [String]
      attr_accessor :template_id

      # Zone uuid to launch the instance into. If nil, it will
      # launch in default project.
      #
      # @return [String]
      attr_accessor :zone_id

      # Network Type
      #
      # @return [String]
      attr_accessor :network_type

      def initialize(domain_specific=false)
        @host                   = UNSET_VALUE
        @path                   = UNSET_VALUE
        @port                   = UNSET_VALUE
        @scheme                 = UNSET_VALUE
        @api_key                = UNSET_VALUE
        @secret_key             = UNSET_VALUE
        @instance_ready_timeout = UNSET_VALUE
        @domain_id              = UNSET_VALUE
        @network_id             = UNSET_VALUE
        @project_id             = UNSET_VALUE
        @service_offering_id    = UNSET_VALUE
        @template_id            = UNSET_VALUE
        @zone_id                = UNSET_VALUE
        @network_type           = UNSET_VALUE

        # Internal state (prefix with __ so they aren't automatically
        # merged)
        @__compiled_domain_configs = {}
        @__finalized = false
        @__domain_config = {}
        @__domain_specific = domain_specific
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
        # Domain_id must be nil, since we can't default that
        @host = nil if @host == UNSET_VALUE

        # Path must be nil, since we can't default that
        @path = nil if @path == UNSET_VALUE

        # Port must be nil, since we can't default that
        @port = nil if @port == UNSET_VALUE

        # Scheme is 'http' by default
        @scheme = "http" if @scheme == UNSET_VALUE

        # Api key must be nil, since we can't default that
        @api_key = nil if @api_key == UNSET_VALUE

        # Secret key must be nil, since we can't default that
        @secret_key = nil if @secret_key == UNSET_VALUE

        # Set the default timeout for waiting for an instance to be ready
        @instance_ready_timeout = 120 if @instance_ready_timeout == UNSET_VALUE

        # Domain id must be nil, since we can't default that
        @domain_id = nil if @domain_id == UNSET_VALUE

        # Network uuid must be nil, since we can't default that
        @network_id = nil if @network_id == UNSET_VALUE

        # Project uuid must be nil, since we can't default that
        @project_id = nil if @project_id == UNSET_VALUE

        # Service offering uuid must be nil, since we can't default that
        @service_offering_id = nil if @service_offering_id == UNSET_VALUE

        # Template uuid must be nil, since we can't default that
        @template_id = nil if @template_id == UNSET_VALUE

        # Zone uuid must be nil, since we can't default that
        @zone_id = nil if @zone_id == UNSET_VALUE

        # NetworkType is 'Advanced' by default
        @network_type = "Advanced" if @network_type == UNSET_VALUE

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

          errors << I18n.t("vagrant_cloudstack.config.ami_required") if config.ami.nil?
        end

        { "Cloudstack Provider" => errors }
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
