require 'lmnp_compta/command'

module LMNPCompta
  module Commands
    # Sous-commandes de configuration initiale et de paramétrage de l'activité.
    module Configurer
      # Classe de base pour les sous-commandes du groupe `configurer`.
      class SubCommand < LMNPCompta::Command
        # Registre des sous-commandes de configuration.
        # @return [Hash{String => Hash}] table des sous-commandes
        def self.registry
          @registry ||= {}
        end

        # Enregistre une sous-commande de configuration.
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
