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
    attr_accessor :name, :parent
    attr_reader :type, :default, :caster, :validations, :required
    private :validations, :required

    UNDEFINED_OPTION = :__undefined__

    def initialize(name, parent, options={})
      @name     = name.to_sym
      @value    = nil
      @parent   = parent
      @guarding = false

      @default = ((default = options.delete(:default)).nil? ? UNDEFINED_OPTION : default).freeze
      @type    = (type = options.delete(:type)).nil? ? compute_type(@default) : type
      @caster  = (cast = options.delete(:cast)).nil? ? Cast::Director[@type] : Cast::Director[cast]

      @required    = determine_if_required?(options)
      @validations = gather_validations(options)

      if options.count > 0
        warn "#{path_name}: encountered unknown options: #{options.inspect}"
      end
    rescue StandardError => e
      raise OptionInvalid.new("Failed to add option #{parent.path_name}.#{name}: #{e.class.name}: #{e.message}") { |ve|
        ve.set_backtrace(e.backtrace)
      }
    end

    def inspect
      _type = type.is_a?(Array) ? "Collection::#{type.first.to_s.capitalize}" : type.to_s.capitalize
      "<Option::#{_type} @name=#{name} @required=#{required.inspect} @default=#{default.inspect} @value=#{value.inspect}>"
    end

    def compute_type(type)
      case type
        when UNDEFINED_OPTION then :any
        when OptionValue then type.type
        when Bignum, Fixnum then :integer
        when Float then :float
        when Symbol then :symbol
        when FalseClass, TrueClass, /(true|false|yes|no|enabled?|disabled?|on|off)/i then :boolean
        when String then :string
        when Pathname then :path
        when URI then :uri
        when Hash then :hash
        when Array then
          type.size <= 0 ? :array : [compute_type(type.first)]
        when Proc then
          with_loop_guard do
            compute_type(type.call)
          end rescue :any
        else :any
      end
    end

    def value=(v)
      return nil unless validate(v)
      @value = v
    end

    def value
      return nil if @value.nil? && @default == UNDEFINED_OPTION

      value = (@value || @default)

      begin
        with_loop_guard do
          if value.respond_to? :call
            unless value.arity == 0
              raise OptionInvalidCallableDefault, "#{path_name}: callable defaults must not accept any arguments"
            end
            value = value.call
          end
        end
      rescue OptionLoopError
        raise # bubble up
      rescue NoMethodError => e
        method = e.message.match(/undefined method .([^']+)'.+/)[1]
        raise OptionInvalidCallableDefault, "#{path_name}: bad method/option name #{method.inspect} in callable default."
      rescue StandardError => e
        excp = OptionInvalidCallableDefault.new "#{path_name}: error executing callable default: #{e.class.name}: #{e.message}"
        excp.set_backtrace(e.backtrace)
        raise excp
      end

      @caster.convert(value)
    end

    def include?(data)
      value.respond_to?(:include?) ? value.include?(data) : false
    end

    def empty?; value.nil? || value.empty?; end
    def valid?; validate(value); end
    def required?; !!@required; end
    def optional?; !required?; end
    def path_name; [ parent.path_name, name ].join('.'); end
    def deprecated?; false; end
    def renamed?; false; end

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
        validate_msg = options.delete(:validate_message)

        expectations = options.delete(:expect)
        expect_msg   = options.delete(:expect_messgae)

        type_validator     = options.delete(:type_validator)
        type_validator_msg = options.delete(:type_validation_message)

        if !validation
          if expectations
            raise OptionInvalidArgument, "#{path_name}: can't disable validations and set an expectation at the same time!"
          elsif type_validator
            raise OptionInvalidArgument, "#{path_name}: can't disable validations and assign a type validator at the same time!"
          end
        end

        return [] unless validation

        if type_validator
          validations << lambda { |_value|
            unless type_validator.call(_value)
              if type_validator_msg
                raise ValidationError, "#{path_name}: #{_value.inspect} fails to validate as custom type: #{type_validator_msg}"
              else
                raise ValidationError, "#{path_name}: #{_value.inspect} fails to validate as custom type."
              end
            end
            true
          }
        else
          validations << lambda { |_value|
            unless validate_type(_value)
              raise ValidationError, "#{path_name}: #{_value.inspect} fails to validate as #{type.inspect}"
            end
            true
          }
        end

        validations << lambda { |_value|
          unless validation.call(_value)
            if validate_msg
              raise ValidationError, "#{path_name}: #{_value.inspect} fails custom validation rule: #{validate_msg}"
            else
              raise ValidationError, "#{path_name}: #{_value.inspect} fails custom validation rule"
            end
          end
          true
        } if validation.respond_to?(:call)

        unless expectations.nil?
          if expectations.respond_to? :call
            validations << lambda { |_value|
              unless expectations.call(_value)
                if expect_msg
                  raise ValidationError, "#{path_name}: #{_value.inspect} fails custom expectation: #{expect_msg}"
                else
                  raise ValidationError, "#{path_name}: #{_value.inspect} fails custom expectation"
                end
              end
              true
            }
          else
            validations << lambda { |_value|
              unless expectations.include?(_value)
                raise ValidationError, "#{path_name}: Failed expectation: #{_value.inspect} not in list: #{expectations.collect(&:inspect).join(', ')}"
              end
              true
            }
          end
        end
      }
    end

    def validate(_value)
      return true if type == :any && validations.empty?

      begin
        # try on just the raw value first
        validations.all? { |validation| validation.call(_value.freeze) }
      rescue StandardError => initial_exception
        begin
          # now try on the converted value
          cast_value = @caster.convert(_value)
          validations.all? { |validation| validation.call(cast_value) }
        rescue ValidationError => e
          raise ValidationError.new(e.message).tap {|ve| ve.set_backtrace(initial_exception.backtrace) }
        rescue CastError
          raise initial_exception
        end
      end
    end

    def validate_type(_value, validation_type = nil)
      validation_type ||= type

      case validation_type
        when :any; true
        when Array then
          return _value.is_a?(Array) if validation_type.empty?
          [*_value].flatten.all? { |v|
            validate_type(v, validation_type.first)
          }
        when :scalar then
          validate_type(_value, :integer) || validate_type(_value, :float) ||
          validate_type(_value, :symbol) || validate_type(_value, :string) ||
          validate_type(_value, :boolean)
        when :boolean then
          _value.is_a?(FalseClass) || _value.is_a?(TrueClass)
        when :float then
          ((Float(_value) rescue nil) == _value.to_f)
        when :integer then
          ((Float(_value).to_i rescue nil) == _value.to_i)
        when :path then
          _value.is_a?(Pathname)
        when :array then _value.is_a?(Array)
        when :hash then _value.is_a?(Hash)
        when :string then _value.is_a? String
        when :symbol then _value.is_a? Symbol
        when :uri then !!(URI.parse(_value) rescue false)
        else
          warn "unable to validate - no handler for type: #{type.inspect}"
          true # assume valid
      end
    end

    def with_loop_guard(&block)
      begin
        raise OptionLoopError if @guarding
        @guarding = true
        yield
      rescue OptionLoopError => error
        raise error.tap { |e| e.stack << path_name }
      ensure
        @guarding = false
      end
    end

  end
end
