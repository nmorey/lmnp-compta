require 'lmnp_compta/command'

module LMNPCompta
    module Commands
        class Help < Command
            register 'help', 'Lister les commandes disponibles ou afficher l\'aide d\'une commande spécifique'

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
