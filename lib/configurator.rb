require 'configurator/core_ext'
require 'configurator/errors'
require 'configurator/bindings'

module Configurator
  autoload :Loader,    'configurator/loader'
  autoload :Section,   'configurator/section'
  autoload :Option,    'configurator/option'
  autoload :Delegated, 'configurator/delegated'
  autoload :VERSION,   'configurator/version'
end
