require "log4r"

module VagrantPlugins
  module Cloudstack
    module Action
      # This action reads the state of the machine and puts it in the
      # `:machine_state_id` key in the environment.
      class ReadState
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_cloudstack::action::read_state")
        end

        def call(env)
          env[:machine_state_id] = read_state(env[:cloudstack_compute], env[:machine])

          @app.call(env)
        end

        def read_state(cloudstack, machine)
          return :not_created if machine.id.nil?

          # Find the machine
          server = cloudstack.servers.get(machine.id)
          if server.nil? || [:"shutting-down", :terminated].include?(server.state.downcase.to_sym)
            # The machine can't be found
            @logger.info("Machine not found or terminated, assuming it got destroyed.")
            machine.id = nil
            return :not_created
          end

          # Return the state
          return server.state.downcase.to_sym
        end
      end
    end
  end
end
