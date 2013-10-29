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
  class Error < StandardError; end

  class ValidationError < Error; end
  class ConfigurationInvalid < Error; end

  class CastError < Error; end
  class InvalidCastType < CastError; end
  class CastFailure < CastError; end

  class OptionError < Error; end
  class OptionExists < OptionError; end
  class OptionInvalid < OptionError; end
  class OptionInvalidArgument < OptionError; end
  class OptionInvalidCallableDefault < OptionError; end
  class RenameFailed < OptionError; end

  class OptionLoopError < SystemStackError
    attr_accessor :stack

    def initialize(*args)
      @stack = []
      super
    end

    def to_s
      "Loop detected in #{stack.first}. Request Stack: #{stack.join(' -> ')}"
    end
  end

end