require 'lmnp_compta/command'

module LMNPCompta
    # Espace de noms regroupant les commandes CLI de LMNP-Compta.
    module Commands
        # Commande affichant l'aide globale et la liste des commandes disponibles.
        class Help < Command
            register 'help', 'Lister les commandes disponibles ou afficher l\'aide d\'une commande spécifique'

            # Affiche l'aide générale de l'application sur la sortie standard.
            # @return [void]
            def execute
                puts "Usage: lmnp <commande> [options]"
                puts "\nCommandes disponibles :"
                Command.registry.sort.each do |name, info|
                    puts "  #{name.ljust(20)} #{info[:description]}"
                end
                puts "\nLancez 'lmnp <commande> --help' pour voir les options d\'une commande spécifique."
            end
        end
    end
end
