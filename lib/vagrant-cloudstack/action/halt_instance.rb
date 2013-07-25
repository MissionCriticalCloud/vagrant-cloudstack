require "log4r"

module VagrantPlugins
  module Cloudstack
    module Action
      # This halts the running instance.
      class HaltInstance
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_cloudstack::action::halt_instance")
        end

        def call(env)
          server = env[:cloudstack_compute].servers.get(env[:machine].id)

          # Stop the server and remove the tracking ID
          env[:ui].info(I18n.t("vagrant_cloudstack.halting"))
          server.stop
          
          @app.call(env)
        end
      end
    end
  end
end
