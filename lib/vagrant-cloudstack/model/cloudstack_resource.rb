module VagrantPlugins
  module Cloudstack
    module Model
      class CloudstackResource
        attr_accessor :id, :name
        attr_reader   :kind

        def initialize(id, name, kind)
          raise 'Resource must have a kind' if kind.nil? || kind.empty?
          @id             = id
          @name           = name
          @kind           = kind
        end

        def to_s
          "#{kind} - #{id || '<unknown id>'}:#{name || '<unknown name>'}"
        end
      end
    end
  end
end
