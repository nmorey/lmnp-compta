require 'lmnp_compta/command'

module LMNPCompta
  module Commands
    # Sous-commandes relatives à la gestion du bilan et de la clôture annuelle.
    module Bilan
      # Classe de base pour les sous-commandes du groupe `bilan`.
      class SubCommand < LMNPCompta::Command
        # Registre des sous-commandes de bilan.
        # @return [Hash{String => Hash}] table des sous-commandes
        def self.registry
          @registry ||= {}
        end

        # Enregistre une sous-commande de bilan.
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
