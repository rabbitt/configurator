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

      case @option.type
        when :string then
          self.class.send(:define_method, :to_str) { self.to_s } unless defined? :to_str
        when :integer then
          self.class.send(:define_method, :to_int) { self.to_i } unless defined? :to_int
      end

      super(option.value)
    end

    def method_missing(method, *args, &block)
      begin
        super
      rescue NoMethodError
        begin
          raise NoMethodError, "undefined method '#{method}' for #{@option.type} option #{path_name}."
        rescue NoMethodError => e
          # hack to remove trace information for this file
          e.backtrace.collect!{ |line| line.include?(__FILE__) ? nil : line}.compact!
          raise
        end
      end
    end

    def empty?; !option.value.nil? && @option.value.empty?; end
    def nil?; @option.value.nil?; end
    def cast; @option.caster.class.name.split('::').last.downcase.to_sym; end
    def type; @option.type; end
    def default; @option.default; end
    def valid?; @option.valid?; end
    def required?; @option.required?; end
    def optional?; @option.optional?; end
    def path_name; @option.path_name; end
    def name; @option.name; end

    def value; self; end
  end

  class DelegatedOption < SimpleDelegator
    attr_accessor :name, :parent
    private :name=, :parent=

    def initialize(new_name, new_parent, object)
      @name, @parent = new_name, new_parent
      super(object)
    end

    def root() parent.nil? ? self : parent.root; end
    def path_name()
      parent.nil? ? name : [ parent.path_name, name ].join('.')
    end

    def renamed?; self.is_a? RenamedOption; end
    def deprecated?; self.is_a? DeprecatedOption; end
    def emit_warning(); end
    def value() emit_warning; super; end
    def value=(v) emit_warning; super; end
  end

  class AliasedOption < DelegatedOption; end

  class RenamedOption < AliasedOption
    def emit_warning
      warn "Configuration option #{path_name} was renamed to #{__getobj__.path_name} - please update your configuration"
    end
  end

  class DeprecatedOption < DelegatedOption
    def initialize(name, parent, object, end_of_life = nil)
      @eol = end_of_life
      super(name, parent, object)
    end

    def emit_warning
      if @eol && !@eol.is_a?(TrueClass)
        @eol = case @eol
          when Date, DateTime, Time then @eol.strftime('%F')
          else @eol
        end
        warn "Configuration option #{path_name} is deprecated and will no longer be available on or after #{@eol}."
      else
        warn "Configuration option #{path_name} is deprecated and will be removed soon."
      end
    end
  end
end