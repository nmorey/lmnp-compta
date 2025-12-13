require 'lmnp_compta/command'

module LMNPCompta
  module Commands
    class Help < Command
      register 'help', 'List available commands or show help for a specific command'

      def execute
        puts "Usage: lmnp <command> [options]"
        puts "\nAvailable commands:"
        LMNPCompta::Command.registry.sort.each do |name, info|
          puts "  #{name.ljust(20)} #{info[:description]}"
        end
        puts "\nRun 'lmnp <command> --help' for specific command usage."
      end
    end
  end
end
