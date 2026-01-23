require 'lmnp_compta/command'
require_relative 'bilan/sub_command'

Dir.glob(File.join(__dir__, 'bilan', '*.rb')).each do |file|
  require file
end

module LMNPCompta
  class BilanCommand < Command
    register :bilan, "Opérations de fin d'année (cloturer, liasse, fec)"

    def execute
      subcommand_name = @args.shift

      if subcommand_name.nil? || subcommand_name == '--help' || subcommand_name == '-h'
        show_help
        return
      end

      subcommand_info = LMNPCompta::Commands::Bilan::SubCommand.registry[subcommand_name]

      if subcommand_info
        subcommand_class = subcommand_info[:class]
        subcommand_class.new(@args).execute
      else
        puts "❌ Commande inconnue: #{subcommand_name}"
        show_help
        exit 1
      end
    end

    private

    def show_help
      puts "Usage: lmnp bilan <commande>"
      puts "Commandes disponibles :"
      LMNPCompta::Commands::Bilan::SubCommand.registry.sort.each do |name, info|
        puts "  #{name.ljust(20)} #{info[:description]}"
      end
    end
  end
end