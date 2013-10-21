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
require 'erb'
require 'yaml'

module Configurator
  class Loader
    attr_reader :data, :path
    private :data

    def initialize(path, _binding = nil)
      @path    = Pathname.new(path).realpath
      @binding = _binding
      @data    = nil
    end

    def [](env)
      data[env]
    end

    def data(reload = false)
      @data = nil if reload

      @data ||= unless @binding.nil?
        YAML::load(ERB.new(IO.read(@path.to_s)).result(@binding))
      else
        YAML::load(ERB.new(IO.read(@path.to_s)).result)
      end
    end

    def load(environment)
      data[environment.to_s]
    end

    def reload!(environment)
      data(true)[environment.to_s]
    end
  end
end