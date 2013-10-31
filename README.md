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
        option :email,  validate: ->(_value) { _value.include?('@') && _value.count('.') >= 1 },
                        validate_message: "email must contain @ and at least one '.'"
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

`option <name>[[, type], options]`

Note: type is completely optionally, however, if you don't provide a type, your option will be marked as type `:any` which essentially marks it as accepting any data type, and prevents type validation from happening against it (unless you provide your own validation rule).

As you build your configuration object, methods will be created automatically at each level providing you with access to each section and option. For example, given the above example `Application::Config` object, you would be able to reference the ldap encryption option by way of `Application::Config.ldap.encryption`. Additionally, each node has access back to it's parent node as well as the root node, so you could also (but probably never would) do the following to get the general domain option: `Application::Config.ldap.encryption.parent.hostname.root.general.domain`

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
  <dd><strong><em>Type Validation</em></strong>: Ensures value can be represented as a valid Pathname object.</dd>
  <dd><strong><em>Type Casting</em></strong>: Converts value to a Pathname object.</dd>

  <dt>:uri</dt>
  <dd></dd>
  <dd><strong><em>Type Validation</em></strong>: Ensures value can be represented sa a valid URI object.</dd>
  <dd><strong><em>Type Casting</em></strong>: Converts vaue to a URI object</dd>

  <dt>[&lt;subtype&gt;]</dt>
  <dd>This type represents a collection of subtype objects, i.e, an array of objects of one given type. Subtype can be one of the types listed here, except another collection.</dd>
  <dd><strong><em>Type Validation</em></strong>: Enssures the object is an array containing only elements of type 'subtype'</dd>
  <dd><strong><em>Type Casting</em></strong>: Converts all elements in the array to type 'subtype'</dd>
</dl>

<dl>
</dl>

##### Defaults

Defaults can be used to provide a default value for configuration options, and can either be a literal value or a callable lambda. Defaults are only used in the event that no overriding value has been assigned to the configuration option (either by loading a YAML config file via, or direct assignment). Callables must not accept any calling parameters and are executed within the context of the option's parent section. This allows for references to the option's sibling options, as well as the root and parent sections. See `ldap.hostname` and `ldap.user_base` as examples of this in the example under Usage above.

##### Deprecations, Renames and Aliases

In addition to specifying defaults, validations and casting types, you can also mark options as deprecated or renamed as well as alias one option to another. Deprecating, Renaming and Aliasing are all useful options for maintaining backwards compatability with your previous configurations. Additionally, it serves as a way to let your users know when changes have been made to the underlying structure of the configuration, allowing them to update their configuration files appropriately.

###### Deprecation

Deprecated options are a way of letting your end user know that a given option is planned for removal - even allowing for an end of life date to be provided. The signature for marking an option as deprecated is:

  `deprecated! '&lt;option.path>'[, [end of life date]]`

The option.path is the list of names of the path, starting with 'root' and proceeding section by section all the way to the option itself, separated by a dots. For example, the option path for `Application::Config.ldap.encryption` would be `root.ldap.encryption` - though 'root.' is optionally, so you could just as easily write 'ldap.encryption'.

###### Renames

Renames are a way of telling your users that an option has been renamed, or moved from one option path name to another. With renames, you should have already renamed/moved your option to it's new name (and optionally section) before calling `renamed!`. Once you call `renamed!`, a new option is added to your configuration using the `legacy path` you provided, and links that legacy path to the `new path`. Any assignments, or reads, from the `legacy path` will trigger warnings letting the user know that the path has changed, and what it has changed to.

The signature for a rename is:

  `renamed! 'legacy path', 'new path'`

###### Aliases

Aliases function like renames but do not actually emit warnings. They are useful as alternate access points for a given configuration option. Like renames, the link target must exist or an exception will be thrown.

The signature for an alias is similar to Ruby's own alias method and is:

  `alias! 'original.path', 'new.path'`

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
