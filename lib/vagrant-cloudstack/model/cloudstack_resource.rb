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

        def self.create_list(ids, names, kind)
          # padding with nil elements
          if ids.length < names.length
            ids += [nil] * (names.length - ids.length)
          elsif ids.length > names.length
            names += [nil] * (ids.length - names.length)
          end

          ids_enum = ids.to_enum
          names_enum = names.to_enum

          resources = []

          loop do
            id = ids_enum.next
            name = names_enum.next
            resources << CloudstackResource.new(id, name, kind)
          end

          resources
        end
      end
    end
  end
end
