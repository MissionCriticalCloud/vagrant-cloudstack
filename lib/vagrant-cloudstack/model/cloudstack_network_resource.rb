module VagrantPlugins
  module Cloudstack
    module Model
      class CloudstackNetworkResource < CloudstackResource
        attr_accessor :acl_id

        def initialize(id, name)
          super(id, name, 'network')
        end

        def is_vpc?
          !acl_id.nil?
        end

        def to_s
          kind = is_vpc? ? 'VPC tier' : 'Guest network'
          "#{kind} - #{id || '<unknown id>'}:#{name || '<unknown name>'}"
        end
      end
    end
  end
end
