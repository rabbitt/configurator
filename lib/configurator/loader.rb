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