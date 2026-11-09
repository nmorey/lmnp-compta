module LMNPCompta
    # Classe de base pour les commandes principales de la CLI LMNP-Compta.
    class Command
        # Registre associant chaque nom de commande à sa classe et sa description.
        # @return [Hash{String => Hash}] table des commandes enregistrées
        def self.registry
            @registry ||= {}
        end

        # Enregistre une classe de commande dans le registre global.
        # @param name [String, Symbol] nom de la commande CLI
        # @param description [String] description sommaire de la commande
        # @return [void]
        def self.register(name, description)
            Command.registry[name.to_s] = { class: self, description: description }
        end

        # Initialise la commande avec les arguments de ligne de commande.
        # @param args [Array<String>] arguments passés à la commande
        def initialize(args)
            @args = args
        end

        # Exécute la logique de la commande.
        # @return [void]
        def execute
            raise NotImplementedError
        end
    end
end
