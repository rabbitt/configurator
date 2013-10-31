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

require 'singleton'
require 'monitor'

module Configurator
  module Cast
    class Director
      class << self
        def __mutex__
          @__mutex__ ||= ::Monitor.new
        end

        def casts
          if @casts.nil?
            __mutex__.synchronize { @casts ||= {} }
          else
            @casts
          end
        end

        def type_to_key(type)
          case type
            when ::Array then "collection:%s" % type.first
            when ::Proc then "proc:%d" % type.object_id
            else type.to_s
          end
        end

        def acquire(type)
          type_key = type_to_key(type)
          return casts[type_key] if casts.include?(type_key)

          __mutex__.synchronize do
            return casts[type_key] if casts.include?(type_key)

            casts[type_key] = case type
              when ::Array then
                Cast::Collection.new(type.first)
              when :uri, /uri/i then
                Cast::URI.new
              when :any, /any/i then
                Cast::Generic.new
              when ::Symbol, ::String then
                begin
                  Cast.const_get(type.to_s.capitalize).new
                rescue NameError
                  raise InvalidCastType, "Invalid cast type #{type}"
                end
              when ::Proc then
                Cast::Callable.new(type)
            else
              raise InvalidCastType, "Invalid cast type #{type}"
            end
          end

          casts[type_key]
        end
        alias :[] :acquire
      end
    end

    class Generic
      def _cast(value) value; end
      private :_cast

      def convert(value)
        begin
          _cast(value);
        rescue StandardError => e
          raise CastError.new(e.message).tap { |exc| exc.set_backtrace(e.backtrace) }
        end
      end
    end

    class Collection < Generic
      def initialize(subtype)
        @cast = Director.acquire(subtype)
        raise ArgumentError, "Collection subtype cannot be another collection" if @cast.is_a? Collection
      end

      def _cast(value)
        [*value].collect { |v| @cast.convert(v) }
      end
    end

    class Scalar < Generic; end

    class String < Generic
      def _cast(value) value.to_s; end
    end

    class Integer < Generic
      def _cast(value) value.to_i; end
    end

    class Float < Generic
      def _cast(value) value.to_f; end
    end

    class Symbol < Generic
      def _cast(value) value.to_s.to_sym; end
    end

    class URI < Generic
      def _cast(value) ::URI.parse(value); end
    end

    class Path < Generic
      def _cast(value) ::Pathname.new(value); end
    end

    class Hash < Generic
      def _cast(value)
        return value if value.is_a?(::Hash)
        case value
          when Array then
            return Hash[*value] if value.size % 2 == 0
            raise CastError, "input array value has odd number of elements - unable to convert to Hash"
          else { value => value }
        end
      end
    end

    class Array < Generic
      def _cast(value) [*value] rescue [value]; end
    end

    class Boolean < Generic
      def _cast(value)
        case value
          when /(off|false|no|disabled?)/ then false
          when /(on|true|enable|yes)/ then true
          else !!value
        end
      end
    end

    class Callable < Generic
      def initialize(proc)
        @proc = proc
      end

      def _cast(value)
        @proc.call(value)
      end
    end
  end
end