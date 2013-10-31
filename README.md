# Configurator

## Installation
1. Add `gem 'configurator', :git => 'https://github.com/rabbitt/configurator.git'` to your Gemfile
2. Run `bundle install`

## Usage

### Creating a Configuration

```ruby
module Application
  class Config
    include Configurator::Bindings
    configuration do
      section :general do
        option :bar, default: 'baz'
        option :domain, default: -> { %x { hostname -f }.strip.split('.')[-2..-1].join('.') }
        option :email,  validate: ->(_value) { _value.include? '@' or raise ValidationError, "email missing @" }
      end
      section :ldap do
        option :hostname,   default: -> { "ldap.%s" % root.general.domain }
        option :encryption, default: :none, expect: [ :none, :start_tls, :simple_tls ]
        option :base_dn,    default: -> { "dc=%s,dc=%s" % root.general.domain.split('.') }
        option :user_base,  default: -> { "ou=people,%s" % base_dn }
      end
      section :misc do
        option :foobaz, :uri, deprecated: '10/29/2013'
      end
    end
    renamed! 'misc.foo', 'general.bar'
    renamed! 'ldap.host', 'ldap.hostname'
    deprecated! 'misc', '10/31/2013'
    alias! 'general.bar', 'general.baz'
  end
end
```

This creates a singleton Application::Config instance which you can use to access your configuration. Additionally, you can load up a YAML file by calling the `load(config_path, environment)` method of your new `Application::Config` object.

#### Sections

Sections are for defining nested groups of related information. Initially, by calling `configuration do; end` a root section (aptly called 'root') is automagically created for you. All top-level section/option definitions are added to the root section.

#### Options

Options are the actual meat of your configuration and can be defined with specific types, defaults, validations and can be auto-converted to another type on read if you provide casting information.

The format of an option definition is as follows:

`option <name>, [[type], [options]]`

Note: type is completely optionally, however, if you don't provide a type, your option will be marked as type `:any` which essentially marks it as accepting any data type, and prevents type validation from happening against it (unless you provide your own validation rule).

##### Types

Configurator types are used for both validation and type-casting, with validation using the type-cast version of the input value. Following are the list of types that Configurator understands:

<dl>

  <dt>:any</dt>
  <dd>Default type if none specified.</dd>
  <dd><strong><em>Type Validation</em></strong>: Any data is considered valid for an option of this type.</dd>
  <dd><strong><em>Type Casting</em></strong>: No type-casting is performed for this data type - data out == data in.</dd>

  <dt>:scalar</dt>
  <dd>Allows for values of :integer, :float and :string, :symbol, :boolean</dd>
  <dd><strong><em>Type Validation</em></strong>: Any of :integer, :Float, :symbol, :string and :boolean are considered valid values </dd>
  <dd><strong><em>Type Casting</em></strong>: No type-casting is performed for this data type - data out == data in.</dd>

  <dt>:integer</dt>
  <dd>Used for Bignum, Fixnum and generally any non-Float Numeric value.</dd>
  <dd><strong><em>Type Validation</em></strong>: Ensures a valid integer value is present.</dd>
  <dd><strong><em>Type Casting</em></strong>: Conversion to integer is performed using #to_i on the given object.</dd>

  <dt>:float</dt>
  <dd>Used for Bignum, Fixnum and generally any non-Float Numeric value.</dd>
  <dd><strong><em>Type Validation</em></strong>: Ensures a valid float value is present.</dd>
  <dd><strong><em>Type Casting</em></strong>: Conversion to Float is performed using #to_f on the given object.</dd>

  <dt>:symbol, :string, :array, :hash</dt>
  <dd>Used for values of the same basic Ruby type.</dd>
  <dd><strong><em>Type Validation</em></strong>: Ensures input value is one of Symbol, String or Array.</dd>
  <dd><strong><em>Type Casting</em></strong>: Data is converted to the specific type using one #to_s for strings, #to_s.to_sym for symbols and [*value] for arrays.</dd>

  <dt>:boolean</dt>
  <dd>Used for true/false type values. Automatically converts objects to their boolean equivalent.</dd>
  <dd><strong><em>Type Validation</em></strong>: Ensure input value either a TrueClass or FalseClass.</dd>
  <dd><strong><em>Type Casting</em></strong>: Converts strings containing any of: yes, no, enabled, disabled, true, false, off, on; otherwise converts to false for nil and true for any valid object.</dd>

  <dt>:path</dt>
  <dd>Used for pathing data, such as fully qualified, or relative paths to files/directories.</dd>
  <dd><strong><em>Type Validation</em></strong>: Ensures </dd>
  <dd><strong><em>Type Casting</em></strong>: Converts path data to Pathname object.</dd>

  <dt>:uri</dt>
  <dd></dd>
  <dd><strong><em>Type Validation</em></strong>: </dd>
  <dd><strong><em>Type Casting</em></strong>: </dd>

  <dt>[&lt;subtype&gt;]</dt>
  <dd></dd>
  <dd><strong><em>Type Validation</em></strong>: </dd>
  <dd><strong><em>Type Casting</em></strong>: </dd>
</dl>

<dl>
</dl>

##### Defaults
##### Casting to another type
##### Validations
#### Deprecations
#### Renames
#### Aliases

#### Accessing / Modifying options

```ruby
config = Application::Config

config.general.email # -> nil
config.general.email.valid? # -> false
config.general.email.required? # -> true
config.general.email = 'dev@null.com'
config.general.email.valid? # -> true
config.general.email # -> 'dev@null.com'

config.ldap.host # -> nil
config.ldap.hostname # -> nil
config.ldap.host = 'foo.bar.com'
config.ldap.host # -> 'foo.bar.com'
config.ldap.hostname # -> 'foo.bar.com'

config.general.domain # -> 'example.com'
config.ldap.base_dn # -> 'dc=example,dc=com'
config.ldap.user_base # -> 'ou=people,dc=example,dc=com'
config.general.daomin = 'foo.com'
config.ldap.base_dn # -> 'dc=foo,dc=com'
config.ldap.user_base # -> 'ou=people,dc=foo,dc=com'

config.misc.foo # -> 'baz'
config.general.bar # -> 'baz'
config.misc.foo === config.general.bar # -> true
```

### Loading config file

```ruby
Application::Config.load(File.expand_path('/path/to/config.yml'), :production)
trap('HUP') { Application::Config.reload! }
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
