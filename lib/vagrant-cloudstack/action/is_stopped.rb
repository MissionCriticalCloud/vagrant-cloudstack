module VagrantPlugins
  module Cloudstack
    module Action
      # This can be used with "Call" built-in to check if the machine
      # is stopped and branch in the middleware.
      class IsStopped
        def initialize(app, env)
          @app = app
        end

        def call(env)
          env[:result] = env[:machine].state.id == :Stopped
          @app.call(env)
        end
      end
    end
  end
end
