require 'fog'
require 'log4r'

module VagrantPlugins
  module Cloudstack
    module Action
      # This action connects to Cloudstack, verifies credentials work, and
      # puts the Cloudstack connection object into the
      # `:cloudstack_compute` key in the environment.
      class ConnectCloudstack
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_cloudstack::action::connect_cloudstack')
        end

        def call(env)
          # Get the domain we're going to booting up in
          domain        = env[:machine].provider_config.domain_id

          # Get the configs
          domain_config = env[:machine].provider_config.get_domain_config(domain)

          # Build the fog config
          fog_config    = {
              :provider => :cloudstack
              #:domain        => domain_config
          }

          if domain_config.api_key
            fog_config[:cloudstack_api_key]           = domain_config.api_key
            fog_config[:cloudstack_secret_access_key] = domain_config.secret_key
          end

          fog_config[:cloudstack_host]   = domain_config.host if domain_config.host
          fog_config[:cloudstack_path]   = domain_config.path if domain_config.path
          fog_config[:cloudstack_port]   = domain_config.port if domain_config.port
          fog_config[:cloudstack_scheme] = domain_config.scheme if domain_config.scheme

          @logger.info('Connecting to Cloudstack...')
          env[:cloudstack_compute] = Fog::Compute.new(fog_config)

          @app.call(env)
        end
      end
    end
  end
end
