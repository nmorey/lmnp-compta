require 'lmnp_compta/command'

module LMNPCompta
  module Commands
    module Configurer
      class SubCommand < LMNPCompta::Command
        def self.registry
          @registry ||= {}
        end

        def self.register(name, description)
          SubCommand.registry[name.to_s] = { class: self, description: description }
        end
      end
    end
  end
end
