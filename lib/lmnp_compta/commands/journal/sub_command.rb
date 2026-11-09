require 'lmnp_compta/command'

module LMNPCompta
  module Commands
    # Sous-commandes de manipulation et de consultation du journal comptable.
    module Journal
      # Classe de base pour les sous-commandes du groupe `journal`.
      class SubCommand < LMNPCompta::Command
        # Registre des sous-commandes du journal.
        # @return [Hash{String => Hash}] table des sous-commandes
        def self.registry
          @registry ||= {}
        end

        # Enregistre une sous-commande du journal.
        # @param name [String, Symbol] nom de la sous-commande
        # @param description [String] description sommaire
        # @return [void]
        def self.register(name, description)
          SubCommand.registry[name.to_s] = { class: self, description: description }
        end
      end
    end
  end
end
