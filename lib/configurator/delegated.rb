=begin
Copyright (C) 2013 Carl P. Corliss

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
=end

module Configurator
  class OptionValue < SimpleDelegator
    def initialize(option)
      @option = option

      case @option.value
        when String then
          self.class.send(:define_method, :to_str) { self.to_s } unless defined? :to_str
        when Numeric then
          self.class.send(:define_method, :to_int) { self.to_i } unless defined? :to_int
      end

      super(option.value)
    end

    def valid?; @option.valid?; end
    def required?; @option.required?; end
    def optional?; @option.optional?; end
    def path_name; @option.path_name; end
    def name; @option.name; end

    def value; self; end
    def value=(value)
      @option.value = value
      initialize(@option)
    end
  end

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