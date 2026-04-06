require 'lmnp_compta/commands/configurer/sub_command'
require 'lmnp_compta/vehicle'

module LMNPCompta
  module Commands
    module Configurer
      class Vehicules < SubCommand
        register 'vehicules', 'Gérer les véhicules personnels (ajouter, lister)'

        def execute
          require 'optparse'
          parser = OptionParser.new do |opts|
             opts.banner = "Usage: lmnp configurer vehicules {ajouter|lister} [options]"
             opts.on("-h", "--help", "Affiche l'aide") do
                 puts opts
                 puts "\nSous-commandes :"
                 puts "  ajouter \"Nom\" CV    Ajouter un véhicule personnel"
                 puts "  lister              Lister les véhicules enregistrés"
                 exit 0
             end
          end

          begin
             parser.parse!(@args)
          rescue OptionParser::InvalidOption => e
             puts e
             puts parser
             exit 1
          end

          sub = @args.shift
          case sub
          when 'ajouter'
            name = @args.shift
            cv = @args.shift
            if name.nil? || cv.nil?
              puts "Usage: lmnp configurer vehicules ajouter \"Nom\" CV"
              return
            end
            begin
              Vehicle.add(name, cv)
              puts "Véhicule '#{name}' (#{cv} CV) ajouté."
            rescue => e
              puts "Erreur: #{e.message}"
            end
          when 'lister'
            vehicles = Vehicle.load_all
            if vehicles.empty?
              puts "Aucun véhicule enregistré."
            else
              puts "Véhicules enregistrés :"
              vehicles.each { |v| puts "- #{v.name} (#{v.fiscal_power} CV)" }
            end
          else
            puts "Usage: lmnp configurer vehicules ajouter <nom> <cv>"
            puts "       lmnp configurer vehicules lister"
          end
        end
      end
    end
  end
end
