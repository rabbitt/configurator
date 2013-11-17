require 'ostruct'

module Configurator
  class Type
    BUILTIN_TYPES = [
      :scalar, :integer, :float, :symbol, :boolean, :string,
      :hash, :array,
      :any, :path, :uri
    ]

    class << self
      include LoopGuard

      @custom_types = {}

      def add_type(token, options = {})
        token = token.to_sym

        raise TypeExists, "Can't redefine builtin type #{token.inspect}." if self::BUILTIN_TYPES.include? token
        raise TypeExists, "Type #{token.inspect} already exists" if @custom_types.key? token

        @custom_types[token] = OpenStruct.new(
          token:       token,
          klass:       options.delete(:klass),
          caster:      options.delete(:cast) || ->(v) { v }),
          validator:   options.delete(:validate) || ->(v) { true }),
        )
      end

      def compute(type)
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
            type.size <= 0 ? :array : [compute(type.first)]
          when Proc then
            with_loop_guard do
              compute(type.call)
            end rescue :any
        else
          if (custom_type = @custom_types.select {|k,t| t.klass && type.is_a? t.klass }.first)
            custom_type.token
          else
            :any
          end
        end
      end

      def types
        self::BUILTIN_TYPES | @custom_types.keys
      end
    end
  end
end