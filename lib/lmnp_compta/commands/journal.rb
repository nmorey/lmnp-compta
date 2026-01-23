require 'lmnp_compta/command'
require_relative 'journal/sub_command'

# Charger automatiquement toutes les sous-commandes
Dir.glob(File.join(__dir__, 'journal', '*.rb')).each do |file|
  require file
end

module LMNPCompta
  class JournalCommand < Command
    register :journal, "Gère le journal (saisir, importer, status...)"

    def execute
      subcommand_name = @args.shift

      if subcommand_name.nil? || subcommand_name == '--help' || subcommand_name == '-h'
        show_help
        return
      end

      subcommand_info = LMNPCompta::Commands::Journal::SubCommand.registry[subcommand_name]

      if subcommand_info
        subcommand_class = subcommand_info[:class]
        subcommand_class.new(@args).execute
      else
        puts "❌ Commande inconnue: #{subcommand_name}"
        show_help
        raise "Command Exited with error" # exit 1 replaced for debug
      end
    end

    private

    def show_help
      puts "Usage: lmnp journal <commande> [options]"
      puts "Commandes disponibles :"
      LMNPCompta::Commands::Journal::SubCommand.registry.sort.each do |name, info|
        puts "  #{name.ljust(20)} #{info[:description]}"
      end
    end
  end
end
