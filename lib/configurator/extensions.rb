require 'yaml'

class String
  def option_path_split(sep = '.')
    return self unless self.count(sep) > 0
    [ (parts = self.split(sep))[0..-2].join(sep), parts.last ]
  end
end

class Hash
  def stringify_keys!
    self.replace(inject({}) { |h,(k,v)|
      h.tap { h[k.to_s] = v.stringify_keys! rescue v }
    })
  end

  def stringify_keys
    self.dup.stringify_keys!
  end
end

module Psych
  module Visitors
    class YAMLTree < Psych::Visitors::Visitor
      def visit_Configurator_DelegatedOption(target)
        send(@dispatch_cache[target.value.class], target.value)
      end

      def visit_Configurator_Section(target)
        send(@dispatch_cache[target.table.class], target.table.stringify_keys)
      end

      def visit_Configurator_Option(target)
        send(@dispatch_cache[target.value.class], target.value)
      end
    end
  end
end
