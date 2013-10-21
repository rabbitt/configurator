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
  class Section
    attr_reader :parent, :name, :options

    def initialize(name, parent = nil, options = {})
      @options = {}
      @parent  = parent
      @name    = name

      load options
    end

    def root
      parent.nil? ? self : parent.root
    end

    def path_name
      parent.nil? ? name : [ parent.path_name, name ].join('.')
    end

    def required?
      options.any? { |k,o| o.required? }
    end

    def optional?
      !required?
    end

    def include?(option_name)
      @options.key? option_name.to_sym
    end

    def [](option_name)
      @options[option_name.to_sym].value
    end

    def []=(option_name, value)
      @options[option_name.to_sym].value = value
    end

    def each(&block)
      @options.each &block
    end

    def to_h
      @options.inject({}) { |h,(k,v)|
        h[k] = v.is_a?(Section) ? v.to_h : v.value
        h
      }
    end

    def to_yaml
      to_h.to_yaml
    end

    def config() self; end
    alias :value :config

    def load(data)
      unless data.is_a? Hash
        warn "#{path_name}: invalid load data for section (#{data.inspect}) - skipping..."
      else
        data.each { |key,value|
          if not @options.key? key.to_sym
            warn "#{path_name}: unable to load data for unknown key #{key.inspect} -> #{value.inspect}"
            next
          end
          @options[key.to_sym].value = value
        }
      end
    end
    alias :value= :load

    def requirements_fullfilled?
      @options.collect { |k,v|
        if v.respond_to? :requirements_fullfilled?
          v.requirements_fullfilled?
        else
          next true unless v.required? && v.value.nil? && !(v.deprecated? rescue false)
          warn "#{v.path_name}: option required but nil value."
          false
        end
      }
    end

    def option(option_name, type, options = {})
      option_name = option_name.to_sym
      deprecated  = options.delete(:deprecated)
      renamed_to  = options.delete(:rename)

      option = Option.new(option_name, self, options.merge(:type => type))
      option = deprecate(option, deprecated) if deprecated
      option = rename(option, renamed_to) if renamed_to

      add_option option_name, option
    end

    def section(option_name, options = {}, &block)
      option_name = option_name.to_sym
      deprecated  = options.delete(:deprecated)
      renamed_to  = options.delete(:rename)

      section = Section.new(option_name, self).tap { |s| s.instance_eval(&block) }
      section = deprecate(section, deprecated) if deprecated
      section = rename(section, renamed_to) if renamed_to

      add_option(option_name, section)
    end

    def deprecate(option, end_of_life = nil)
      Delegated::Deprecated.new(option.name, option.parent, option, end_of_life)
    end

    def rename(option, to_path)
      if to_path.is_a? Symbol
        new_path, new_name = self, to_path
      else
        # otherwise, if it's a dot separated string, it's a
        # full path to a new section.name locaiton
        new_section, new_name = (parts = to_path.split('.'))[0..-2].join('.'), parts.last
        new_path = root.get_path(new_section)
      end

      begin
        Delegated::Renamed.new(new_name, new_path, option).tap { |_option|
          # new location
          new_path.add_option(new_name, _option)
        }
      rescue OptionExists => e
        raise RenameFailed, "Unable to rename #{option.path_name} -> #{new_path.path_name}.#{new_name}"
      end
    end

    alias :original_respond_to? :respond_to?
    def respond_to?(method, include_private = false)
      @options.key?(method) || original_respond_to?(method, include_private)
    end

    protected

    def add_option(option_name, object)
      option_name = option_name.to_sym
      if @options.key? option_name
        raise OptionExists, "Option #{path_name}.#{option_name} already exists"
      end

      @options[option_name] = object.tap {
        self.class.class_eval(<<-EOF, __FILE__, __LINE__ + 1)
          def #{option_name}()
            OptionValueDelegator.new(@options[#{option_name.inspect}])
          end

          def #{option_name}=(_value)
            @options[#{option_name.inspect}].value = _value
          end
        EOF
      }
    end

    def get_path(path)
      begin
        # remove the root - we start there anyway
        path.gsub!(/^root\./, '')
        current_path = [:root]

        path.split('.').collect(&:to_sym).inject(root) do |option, path_component|
          current_path << path_component
          unless option.include? path_component
            raise InvalidPath, "#{current_path.join('.')}: doesn't exist in the current configuration."
          else
            option = option[path_component]
          end
        end
      rescue StandardError => e
        warn "#{e.class.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      end
    end

    def method_missing(method, *args, &block)
      return super unless respond_to?(method)
      self[method] if include?(method)
    end
  end
end
