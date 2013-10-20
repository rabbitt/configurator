module Configurator
  class Error < StandardError; end

  class ValidationError < Error; end

  class OptionExists < Error; end
  class OptionInvalid < Error; end
  class OptionInvalidArgument < Error; end
  class OptionInvalidCallableDefault < Error; end
  class RenameFailed < Error; end
  class ConfigurationInvalid < Error; end
end