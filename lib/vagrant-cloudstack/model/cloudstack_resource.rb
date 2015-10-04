module VagrantPlugins
  module Cloudstack
    module Model
      class CloudstackResource
        attr_accessor :id, :name
        attr_reader   :kind

        def initialize(id, name, kind)
          raise ArgumentError, 'Resource must have a kind' if kind.nil? || kind.empty?
          @id             = id
          @name           = name
          @kind           = kind
        end

        def is_undefined?
          is_id_undefined? and is_name_undefined?
        end

        def is_id_undefined?
          id.nil? || id.empty?
        end

        def is_name_undefined?
          name.nil? || name.empty?
        end

        def to_s
          "#{kind} - #{id || '<unknown id>'}:#{name || '<unknown name>'}"
        end

        def unsynched(another_resource)
          self == another_resource ||
          (self.kind == another_resource.kind && \
          (self.id   == another_resource.id   && another_resource.name.nil?) || \
          (self.name == another_resource.name && another_resource.id.nil?))
        end

        def ==(another_resource)
          self.id   == another_resource.id   && \
          self.name == another_resource.name && \
          self.kind == another_resource.kind
        end
      end
    end
  end
end
