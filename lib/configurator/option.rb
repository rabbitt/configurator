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

require 'pathname'

module Configurator
  class Option
    attr_reader :name, :parent, :type, :default, :cast, :validations, :required
    private :validations, :required

    VALID_TYPES = [ Array, :any, :array, :boolean, :float, :integer, :path, :string, :symbol, :uri ]
    UNDEFINED_OPTION = :__undefined__

    def initialize(name, parent, options={})
      @name   = name.to_sym
      @value  = nil
      @parent = parent

      @type        = (options.delete(:type) || :any).freeze
      @cast        = options.delete(:cast).freeze
      @default     = (options.delete(:default) || UNDEFINED_OPTION).freeze

      @required    = determine_if_required?(options)
      @validations = gather_validations(options)

      if options.count > 0
        warn "#{path_name}: encountered unknown options: #{options.inspect}"
      end
    end

    def value=(v)
      validate(v) ? @value = v : nil
    end

    def value
      return nil if @value.nil? && @default == UNDEFINED_OPTION

      value = (@value || @default)

      begin
        value = case value.arity
          when 0 then value.call
          when 1 then value.call(parent.root)
          when -1, 2 then value.call(parent.root, parent)
          else raise OptionInvalidCallableDefault, "#{path_name}: callable default must accept -1..2 arguments"
        end if value.respond_to? :call
      rescue NoMethodError => e
        method = e.message.match(/undefined method .([^']+)'.+/)[1]
        raise OptionInvalidCallableDefault, "#{path_name}: bad method/option name #{method.inspect} in callable default."
      rescue StandardError => e
        raise OptionInvalidCallableDefault, "#{path_name}: error executing callable default: #{e.class.name}: #{e.message}"
      end

      cast_value(value)
    end

    def include?(data)
      value.respond_to?(:include?) ? value.include?(data) : false
    end

    def valid?; validate(value); end
    def required?; !!@required; end
    def optional?; !required?; end
    def path_name; [ parent.path_name, name ].join('.'); end

  private

    def determine_if_required?(options)
      if options.key?(:required) && options.key?(:optional)
        unless !!options[:required] != !!options[:optional]
          raise OptionInvalidArgument, "#{path_name}: can't be both required and optional at the same time!"
        else
          options.delete(:optional)
          !!options.delete(:required)
        end
      elsif options.key?(:required)
        !!options.delete(:required)
      elsif options.key?(:optional)
        not !!options.delete(:optional)
      else
        # if there's no default, require option
        default == :__undefined__ ? true : false
      end
    end

    def gather_validations(options)
      # XXX: create Validation classes (Expection would derive from Validation) and
      # move all validation logic into those classes
      [].tap { |validations|
        validation   = (v = options.delete(:validate)).nil? ? true : v
        expectations = options.delete(:expect)

        if !validation && expectations
          raise OptionInvalidArgument, "#{path_name}: can't expect something and disable validations at the same time!"
        end

        return [] unless validation

        validations << lambda { |_value|
          unless validate_type(_value)
            raise ValidationError, "#{path_name}: #{_value.inspect} fails to validate as #{type.inspect}"
          end
          true
        }

        validations << lambda { |_value|
          unless validation.call(_value)
            raise ValidationError, "#{path_name}: #{_value.inspect} fails custom validation rule"
          end
          true
        } if validation.respond_to?(:call)

        unless expectations.nil?
          if expectations.respond_to? :call
            validations << lambda { |_value|
              unless expectations.call(_value)
                raise ValidationError, "#{path_name}: #{_value.inspect} fails custom expectation"
              end
              true
            }
          elsif expectations.is_a? Array
            validations << lambda { |_value|
              unless expectations.include?(_value)
                raise ValidationError, "#{path_name}: Failed expectation: #{_value.inspect} not in list: #{expectations.join(', ')}"
              end
              true
            }
          else
            validations << lambda { |_value|
              unless expectations == _value
                raise ValidationError, "#{path_name}: Failed expectation: #{_value.inspect} != #{expectations.inspect}"
              end
              true
            }
          end
        end
      }
    end

    def validate(_value)
      _value = cast_value(_value || @value)
      return true if type == :any || validations.empty?
      validations.all? { |validation| validation.call(_value) }
    end

    def validate_type(_value, validation_type = nil)
      validation_type ||= type

      case validation_type
        when Array;
          if validation_type.empty?
            _value.is_a?(Array)
          else
            [*_value].flatten.all? { |v|
              validate_type(v, validation_type.first)
            }
          end
        when :any; true
        when :array; _value.is_a?(Array)
        when :boolean; _value.is_a?(FalseClass) || _value.is_a?(TrueClass)
        when :float; ((Float(_value) rescue nil) == _value.to_f)
        when :integer; ((Float(_value).to_i rescue nil) == _value.to_i)
        when :path; _value.is_a? Pathname
        when :string; _value.is_a? String
        when :symbol; _value.is_a? Symbol
        when :uri; !!(URI.parse(_value.to_s) rescue false)
        else
          warn "unable to validate - no handler for type: #{type.inspect}"
          true # assume valid
      end
    end

    def cast_value(_value, cast_type = nil)
      return _value unless cast_type ||= @cast

      case cast_type
        when Array then
          type.empty? ? [*_value].flatten : [*_value].flatten.collect{|v| cast_value(v, cast_type.first)}
        when :array; [*_value].flatten
        when :integer; _value.to_i
        when :float; _value.to_f
        when :string; _value.to_s
        when :boolean;
          case _value
            when /(off|false|no|disabled?)/ then false
            when /(on|true|enable|yes)/ then true
            else !!_value
          end
        when :symbol; _value.to_s.to_sym
        when :uri; URI(_value.to_s) rescue nil
        when :path; Pathname.new(_value)
        else cast_type.respond_to?(:call) ? cast_type.call(_value) : _value
      end
    end
  end

  class OptionValueDelegator < SimpleDelegator
    def initialize(option)
      @option = option

      case @option.value
        when String then define_method(:to_str) { to_s }
        when Numeric then define_method(:to_int) { to_i }
      end

      super(option.value)
    end

    def valid?; @option.valid?; end
    def required?; @option.required?; end
    def optional?; @option.optional?; end
    def path_name; @option.path_name; end
    def name; @option.name; end
  end
end