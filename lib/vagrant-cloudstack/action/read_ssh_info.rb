require_relative 'read_info.rb'
require 'log4r'

module VagrantPlugins
  module Cloudstack
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo < VagrantPlugins::Cloudstack::Action::ReadInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_cloudstack::action::read_ssh_info')
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:cloudstack_compute], env[:machine])

          @app.call(env)
        end

        def read_ssh_info(cloudstack, machine)
          return nil if machine.id.nil?

          @cloudstack = cloudstack
          @machine = machine

          # Find the machine
          server = @cloudstack.servers.get(@machine.id)
          if server.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            @machine.id = nil
            return nil
          end

          # Get the Port forwarding config
          pf_ip_address, pf_public_port = retrieve_public_ip_port('pf_public_port')

          nic_ip_address = fetch_nic_ip_address(server.nics)

          ssh_info = {
                       :host => pf_ip_address || nic_ip_address,
                       :port => pf_public_port
                     }

          if @domain_config.keypair.nil? && @domain_config.ssh_key.nil?
            sshkeyfile_file = @machine.data_dir.join('sshkeyfile')
            if sshkeyfile_file.file?
              @domain_config.ssh_key = sshkeyfile_file.to_s
            end
          end

          ssh_info = ssh_info.merge({
            :private_key_path => @domain_config.ssh_key,
            :password         => nil
          }) unless @domain_config.ssh_key.nil?
          ssh_info = ssh_info.merge({ :username => @domain_config.ssh_user }) unless @domain_config.ssh_user.nil?
          ssh_info
        end
      end
    end
  end
end
