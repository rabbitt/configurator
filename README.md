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
        option :domain, default: 'example.com'
        option :email,  validate: ->(value) { value.include? '@' or raise ValidationError, "email missing @" }
      end

      section :ldap do
        option :host,       rename: :hostname
        option :encryption, :symbol, default: :none, expect: [ :none, :start_tls, :simple_tls ]
        option :base_dn,    default: -> { "dc=%s,dc=%s" % root.general.domain.split('.')[-2..-1] }
        option :user_base,  default: -> { "ou=people,%s" % base_dn }
      end

      section :misc, deprecated: '10/31/2013' do
        option :foo,  default: 'baz', renamed: 'root.general.bar'
        option :foobaz, :uri, deprecated: '10/29/2013'
      end
    end
  end
end
```

This creates a singleton Appliation::Config instance which you can use to access your configuration. Additionally, you
can load up a YAML file by calling the ```load(config_path, environment)``` method of your new ```Application::Config```
object.

#### Sections
##### Deprecations
##### Renames
#### Options
##### Types
##### Defaults
##### Casting to another type
##### Validations

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
