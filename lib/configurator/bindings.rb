require 'singleton'

module Configurator
  module Bindings
    extend self

    def self.included(base)
      base.send :include, Singleton
      base.send :include, InstanceMethods
      base.extend self
      base.class_eval(<<-EOF, __FILE__, __LINE__ + 1)
        def self.method_missing(method, *args, &block)
          return super unless instance.respond_to? method
          instance.public_send(method, *args, &block)
        end
      EOF
    end

    def config(&block)
      @config ||= Configurator::Section.new(:root)
      @config.instance_exec(@config, &block) if block_given?
      @config
    end
    alias :configuration :config
    alias :root :config

    alias :_inspect :inspect
    def inspect
      s = ''
      s << "#<#{self.class.name}:0x%x " % (self.__id__ * 2)
      s << {:config_path => config_path, :config => config}.inject([]) { |a,(k,v)| a << "@#{k}=#{v.inspect}" }.join(', ')
      s << '>'
    end

    module InstanceMethods
      attr_reader :config_path
      private :config_path

      def config
        @config ||= self.class.config
      end
      alias :root :config

      def respond_to?(method)
        return true if config.respond_to? method
        super
      end

      def method_missing(method, *args, &block)
        if config.include? method
          config[method]
        elsif config.public_methods.include? method
          config.public_send(method, *args, &block)
        else
          super
        end
      end

      def reload!
        ap @env
        return false unless config_path
        return false unless @env
        config.load loader.reload!(@env)

        unless config.requirements_fullfilled?
          raise ConfigurationInvalid, "Missing one or more required options."
        end
        self
      end

      def load(config_path, env)
        self.tap {
          @env         = env
          @config_path = config_path
          config.load loader.load(@env)

          unless config.requirements_fullfilled?
            raise ConfigurationInvalid, "Missing one or more required options."
          end
        }
      end

      def loader
        @loader ||= Configurator::Loader.new(config_path, Kernel.binding)
      end
      private :loader
    end
  end
end