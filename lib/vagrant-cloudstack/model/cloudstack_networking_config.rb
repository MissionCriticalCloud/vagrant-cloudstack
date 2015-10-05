module VagrantPlugins
  module Cloudstack
    module Model
      class CloudstackNetworkingConfig
        attr_reader :static_nat,
                    :pf_ip_address_id,
                    :pf_ip_address,
                    :pf_public_port,
                    :pf_public_rdp_port,
                    :pf_public_port_randomrange,
                    :pf_open_firewall,
                    :pf_trusted_networks,
                    :security_groups,
                    :private_ip_address
        attr_accessor :network,
                      :pf_private_port,
                      :pf_private_rdp_port,
                      :pf_public_rdp_port,
                      :default_port_forwarding_rule_created

        def initialize(config)
          @static_nat                 = config.static_nat
          @pf_ip_address_id           = config.pf_ip_address_id
          @pf_ip_address              = config.pf_ip_address
          @pf_public_port             = config.pf_public_port
          @pf_public_rdp_port         = config.pf_public_rdp_port
          @pf_public_port_randomrange = config.pf_public_port_randomrange
          @pf_private_port            = config.pf_private_port
          @pf_open_firewall           = config.pf_open_firewall
          @pf_trusted_networks        = config.pf_trusted_networks   || []
          @port_forwarding_rules      = config.port_forwarding_rules || []
          @firewall_rules             = config.firewall_rules        || []
          @security_groups            = config.security_groups       || []
          @private_ip_address         = config.private_ip_address

          @default_port_forwarding_rule_created = false
        end

        def needs_public_port?
          !(has_pf_public_port? || has_pf_public_rdp_port?)
        end

        def has_portforwarding?
          has_pf_ip_address? && (has_pf_public_port? || has_pf_public_port_range?)
        end

        def has_pf_public_port_range?
          !portforwarding_port_range.nil?
        end

        def port_forwarding_rule(vm_guest)
          {
            :network      => @network,
            :ipaddressid  => @pf_ip_address_id,
            :ipaddress    => @pf_ip_address,
            :protocol     => 'tcp',
            :publicport   => public_port(vm_guest),
            :privateport  => private_port(vm_guest),
            :openfirewall => @pf_open_firewall
          }
        end

        def portforwarding_port_range
          @pf_public_port_randomrange[:start]...@pf_public_port_randomrange[:end]
        end

        def should_open_firewall_to_trusted_networks?
          !(@pf_trusted_networks.empty? || @pf_open_firewall)
        end

        def firewall_rules
          extended_firewall_rules = enhance_firewall_rules
          if should_open_firewall_to_trusted_networks?
            extended_firewall_rules << {
                :ipaddressid  => @pf_ip_address_id,
                :ipaddress    => @pf_ip_address,
                :protocol     => 'tcp',
                :startport    => @pf_public_port,
                :endport      => @pf_public_port,
                :cidrlist     => trusted_networks_cidrlist
            }

            extended_firewall_rules + firewall_rules_from_port_forwarding
          end
          extended_firewall_rules
        end

        def port_forwarding_rules(vm_guest)
          rules = enhance_port_forwarding_rules
          rules << port_forwarding_rule(vm_guest) if rules.empty? && !@default_port_forwarding_rule_created
          rules
        end

        def udpate_public_port(vm_guest, public_port)
          case vm_guest
          when :windows
            @pf_public_rdp_port = public_port
          when :linux
            @pf_public_port = public_port
          else
            raise "Unexpected vm guest #{vm_guest}"
          end
        end

        private

        def has_pf_ip_address?
          !(@pf_ip_address_id || @pf_ip_address).nil?
        end

        def has_pf_public_port?
          !@pf_public_port.nil?
        end

        def has_pf_public_rdp_port?
          !@pf_public_rdp_port.nil?
        end

        def enhance_firewall_rules
          @firewall_rules.each do |rule|
            rule[:network]     ||= @network
            rule[:ipaddressid] ||= @pf_ip_address_id
            rule[:ipaddress]   ||= @pf_ip_address
            rule[:cidrlist]    ||= trusted_networks_cidrlist
            rule[:protocol]    ||= 'tcp'
            rule[:endport]     ||= rule[:startport]
          end
        end

        def firewall_rules_from_port_forwarding
          rules = []
          enhance_port_forwarding_rules.each do |rule|
            if rule[:generate_firewall] && !rule[:openfirewall]
              rules << {
                :ipaddressid  => rule[:ipaddressid],
                :ipaddress    => rule[:ipaddress],
                :protocol     => rule[:protocol],
                :startport    => rule[:publicport],
                :endport      => rule[:publicport],
                :cidrlist     => trusted_networks_cidrlist
              }
            end if @pf_trusted_networks
          end
          rules
        end

        def enhance_port_forwarding_rules
          @port_forwarding_rules.each do |rule|
            rule[:ipaddressid]  ||= @pf_ip_address_id
            rule[:ipaddress]    ||= @pf_ip_address
            rule[:protocol]     ||= 'tcp'
            rule[:openfirewall] ||= @pf_open_firewall
            rule[:publicport]   ||= rule[:privateport]
            rule[:privateport]  ||= rule[:publicport]
          end
        end

        def firewall_rule_truested_networks
          {
            :ipaddressid  => @pf_ip_address_id,
            :ipaddress    => @pf_ip_address,
            :protocol     => 'tcp',
            :startport    => @pf_public_port,
            :endport      => @pf_public_port,
            :cidrlist     => trusted_networks_cidrlist
          }
        end

        def private_port(vm_guest)
          case vm_guest
          when :windows
            @pf_private_rdp_port
          when :linux
            @pf_private_port
          else
            raise "Unexpected vm guest #{vm_guest}"
          end
        end

        def public_port(vm_guest)
          case vm_guest
          when :windows
            @pf_public_rdp_port
          when :linux
            @pf_public_port
          else
            raise "Unexpected vm guest #{vm_guest}"
          end
        end

        def trusted_networks_cidrlist
          if @pf_trusted_networks.respond_to?(:join)
            @pf_trusted_networks.join(',')
          else
            @pf_trusted_networks
          end
        end
      end
    end
  end
end
