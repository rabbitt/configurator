module Configurator
  module LoopGuard
    def included(base)
      base.instance_variable_delete(:@guarding)
    end

    def with_loop_guard(&block)
      begin
        raise OptionLoopError if @guarding
        @guarding = true
        yield
      rescue OptionLoopError => error
        raise error.tap { |e| e.stack << path_name }
      ensure
        @guarding = false
      end
    end
  end
end