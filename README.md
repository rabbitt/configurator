# Configurator

## Installation
1. Add `gem 'configurator'` to your Gemfile
2. Run `bundle install`

## Usage

### Define your applications Configuration
```ruby
module Application
  class Config
    include Configurator::Bindings

    configuration do
      section :general do
        option :email, :string, :validate => lambda { |value| value.include? '@' or raise ValidationError, "email missing @" }
        option :domain, :string, :default => 'example.com'
      end

      section :ldap do
        option :host, :string, :required => true, :rename => :hostname
        option :encryption, :symbol, :default => :none, :expect => [ :none, :start_tls, :simple_tls ]
        option :base_dn, :string, :default => lambda { |root| "dc=%s,dc=%s" % root.general.domain.split('.')[-2..-1] }
        option :user_base, :string :default => lambda { |root, current| "ou=people,%s" % current.base_dn }
      end

      section :misc, :deprecated => '10/31/2013' do
        option :foo, :string, :renamed => 'root.general.bar', :default => 'baz'
        option :foobaz, :uri, :deprecated => '10/29/2013'
      end
    end
  end
end
```

This creates a singleton Appliation::Config instance which you can use to access your configuration. Additionally, you
can load up a YAML file by calling the ```load(config_path, environment)``` method of your new ```Application::Config```
object.

### Accessing / Modifying options

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
