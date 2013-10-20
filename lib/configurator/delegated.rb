module Configurator
  class Delegated < SimpleDelegator
    attr_accessor :name, :parent
    private :name=, :parent=

    def initialize(name, parent, object)
      @name, @parent = name, parent
      super(object)
    end

    def path_name
      parent.nil? ? name : [ parent.path_name, name ].join('.')
    end

    def root
      parent.nil? ? self : parent.root
    end

    def renamed?; self.is_a? Renamed; end
    def deprecated?; self.is_a? Deprecated; end

    class Renamed < Delegated
      def initialize(name, parent, object)
        super.tap {
          warn "#{object.path_name} renamed to #{path_name} - please update your configuration"
        }
      end
    end

    class Deprecated < Delegated
      def initialize(name, parent, object, end_of_life = nil)
        super(name, parent, object).tap {
          if end_of_life && !end_of_life.is_a?(TrueClass)
            end_of_life = case end_of_life
              when Date, DateTime, Time then end_of_life.strftime('%F')
              else end_of_life
            end
            warn "#{path_name} is deprecated and will no longer be available on or after #{end_of_life}."
          else
            warn "#{path_name} is deprecated and will be removed soon."
          end
        }
      end
    end
  end
end