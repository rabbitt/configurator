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
    attr_accessor :name, :parent
    attr_reader :table

    def initialize(name, parent = nil, options = {})
      @table = {}
      @parent  = parent
      @name    = name

      load options
    end

    def type; :section; end
    def deprecated?; false; end
    def renamed?; false; end

    def root; parent.nil? ? self : parent.root; end
    def path_name; parent.nil? ? name : [ parent.path_name, name ].join('.'); end
    def required?; options.any? { |k,o| o.required? }; end
    def optional?; !required?; end

    def include?(option_name)
      @table.key? option_name.to_sym
    end

    def [](option_name)
      @table[option_name.to_sym]
    end

    def []=(option_name, value)
      @table[option_name.to_sym].value = value
    end

    def each(&block)
      @table.each &block
    end

    def inject(*args, &block)
      @table.inject(*args, &block)
    end

    def to_h
      inject({}) { |hash,(_name,_option)|
        hash.tap {|h|
          unless _option.deprecated? || _option.renamed?
            h[_name] = _option.to_h rescue _option.value
          end
        }
      }
    end

    def config() self; end
    alias :value :config

    def load(data)
      unless data.is_a? Hash
        warn "#{path_name}: invalid load data for section (#{data.inspect}) - skipping..."
      else
        data.each { |key,value|
          if not @table.key? key.to_sym
            warn "#{path_name}: unable to load data for unknown key #{key.inspect} -> #{value.inspect}"
            next
          end
          @table[key.to_sym].value = value
        }
      end
    end
    alias :value= :load

    def requirements_fullfilled?
      @table.collect { |k,v|
        if v.respond_to? :requirements_fullfilled?
          v.requirements_fullfilled?
        else
          next true unless v.required? && v.value.nil? && !(v.deprecated? rescue false)
          warn "#{v.path_name}: option required but nil value."
          false
        end
      }
    end

    def option(option_name, *args)
      _options = args.last.is_a?(Hash) ? args.pop : {}
      _options.merge!(:type => args.first)

      option_name = option_name.to_sym
      deprecated  = _options.delete(:deprecated)

      option = Option.new(option_name, self, _options)

      if deprecated
        option = DelegatedOption::Deprecated.new(
          option.name, option.parent, option, end_of_life
        )
      end

      add_option option_name, option
    end

    def options(*names)
      names.each do |option_name|
        option option_name
      end
    end

    def section(option_name, options = {}, &block)
      option_name = option_name.to_sym
      deprecated  = options.delete(:deprecated)

      section = Section.new(option_name, self).tap { |s|
        s.instance_eval(&block) if block_given?
      }

      if deprecated
        section = DelegatedOption::Deprecated.new(
          section.name, section.parent, section, end_of_life
        )
      end

      add_option(option_name, section)
    end

    def alias!(orig_path, new_path)
      orig_path = "root.#{orig_path}" unless orig_path.include? 'root.'
      new_path  = "root.#{new_path}" unless new_path.include? 'root.'

      unless _option = root.get_path(orig_path)
        raise DeprecateFailed, "Unable to alias #{new_path} to #{orig_path} - option does not appear to be defined."
      end

      _option = root.get_path(orig_path)
      _parent, _name = new_path.option_path_split

      _parent = root.get_path(_parent)
      new_option  = AliasedOption.new(_name, _parent, _option)
      _parent.add_option(_name, new_option)
    end

    def deprecate!(option_paths, end_of_life = nil)
      [*option_paths].collect {|option_path|
        option_path = "root.#{option_path}" unless option_path.include? 'root.'

        unless _option = root.get_path(option_path)
          raise DeprecateFailed, "Unable to deprecated #{option_path} - option does not appear to be defined."
        end

        _option = DeprecatedOption.new(_option.name, _option.parent, _option, end_of_life)
        _option.parent.replace_option(_option.name, _option)
      }
    end
    alias :deprecated! :deprecate!

    # like alias but with reversed arguments and a warning on assignment
    # note: new path must already exist. old_path is created as an alias
    # to new_path.
    def rename!(old_path, target_path)
      old_path    = "root.#{old_path}" unless old_path.include? 'root.'
      target_path = "root.#{target_path}" unless target_path.include? 'root.'

      unless _option = root.get_path(target_path)
        raise OptionNotExist, "option #{target_path} does not exist -  target path must exist for rename."
      end

      _parent, _name = old_path.option_path_split
      _section = root.get_path(_parent)

      renamed_option = RenamedOption.new(_name, _section, _option)

      begin
        _section.add_option(_name, renamed_option)
      rescue OptionExists => e
        raise RenameFailed, "Unable to rename #{old_path} -> #{target_path}"
      end
    end
    alias :renamed! :rename!

    def add_option(option_name, object)
      option_name = option_name.to_sym
      if @table.key? option_name
        raise OptionExists, "Option #{path_name}.#{option_name} already exists"
      end

      @table[option_name] = object.tap {
        self.class.class_eval(<<-EOF, __FILE__, __LINE__ + 1)
          def #{option_name}()
            OptionValue.new(@table[#{option_name.inspect}])
          end

          def #{option_name}=(_value)
            @table[#{option_name.inspect}].value = _value
          end
        EOF
      }
    end

    def replace_option(name, new_option)
      name = name.to_sym
      unless @table.include? name
        raise OptionNotExist, "#{path_name}.#{name} doesn't exist"
      end
      @table[name] = new_option
    end

    def get_path(path)
      begin
        # remove the root - we start there anyway
        path.gsub!(/^root\.?/, '')
        current_path = [:root]

        path.split('.').collect(&:to_sym).inject(root) do |option, path_component|
          current_path << path_component
          unless option.include? path_component
            raise InvalidOptionPath, "#{current_path.join('.')}: doesn't exist in the current configuration."
          else
            option = option[path_component]
          end
        end
      rescue StandardError => e
        warn "#{e.class.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      end
    end

    alias :original_respond_to? :respond_to?
    def respond_to?(method, include_private = false)
      @table.key?(method) || original_respond_to?(method, include_private)
    end

    def method_missing(method, *args, &block)
      return super unless respond_to?(method)
      self[method] if include?(method)
    end
  end
end
