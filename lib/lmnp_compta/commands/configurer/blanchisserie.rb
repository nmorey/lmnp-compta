require 'lmnp_compta/commands/configurer/sub_command'
require 'lmnp_compta/laundry'
require 'optparse'

module LMNPCompta
  module Commands
    module Configurer
      class Blanchisserie < SubCommand
        register 'blanchisserie', 'Gérer les configurations de blanchisserie (ajouter, lister)'

        def execute
          sub = @args.shift
          case sub
          when 'ajouter'
            ajouter_blanchisserie
          when 'lister'
            lister_blanchisseries
          else
            puts "Usage: lmnp configurer blanchisserie ajouter <id> [options]"
            puts "       lmnp configurer blanchisserie lister"
          end
        end

        private

        def ajouter_blanchisserie
          id = @args.shift
          if id.nil? || id.start_with?('-')
            puts "❌ Erreur: L'identifiant (id) est requis en premier argument."
            puts "Usage: lmnp configurer blanchisserie ajouter <id> --nom-bien \"Nom\" --conso-eau 0.05 --prix-eau 4.0 --conso-kwh 1.0 --prix-kwh 0.25 --prix-produit 0.5"
            return
          end

          options = {}
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp configurer blanchisserie ajouter <id> [options]"
            opts.on("--nom-bien NOM", "Nom du bien (doit correspondre au CSV Airbnb ou autre identifiant)") { |v| options[:nom_bien] = v }
            opts.on("--conso-eau M3", Float, "Consommation d'eau par lessive (en m³)") { |v| options[:conso_eau] = v }
            opts.on("--prix-eau PRIX", Float, "Prix de l'eau au m³") { |v| options[:prix_eau] = v }
            opts.on("--conso-kwh KWH", Float, "Consommation d'électricité par lessive (en kWh)") { |v| options[:conso_kwh] = v }
            opts.on("--prix-kwh PRIX", Float, "Prix de l'électricité au kWh") { |v| options[:prix_kwh] = v }
            opts.on("--prix-produit PRIX", Float, "Prix du produit par lessive") { |v| options[:prix_produit] = v }
            opts.on("-h", "--help", "Affiche l'aide") do
              puts opts
              exit 0
            end
          end

          begin
            parser.parse!(@args)
          rescue OptionParser::InvalidOption, OptionParser::InvalidArgument => e
            puts "❌ Erreur: #{e.message}"
            return
          end

          # Validation
          missing = []
          missing << "--nom-bien" unless options[:nom_bien]
          missing << "--conso-eau" unless options[:conso_eau]
          missing << "--prix-eau" unless options[:prix_eau]
          missing << "--conso-kwh" unless options[:conso_kwh]
          missing << "--prix-kwh" unless options[:prix_kwh]
          missing << "--prix-produit" unless options[:prix_produit]

          unless missing.empty?
            puts "❌ Erreur: Des options obligatoires sont manquantes: #{missing.join(', ')}"
            return
          end

          begin
            LMNPCompta::Laundry.add(
              id,
              options[:nom_bien],
              options[:conso_eau],
              options[:prix_eau],
              options[:conso_kwh],
              options[:prix_kwh],
              options[:prix_produit]
            )
            l = LMNPCompta::Laundry.find(id)
            puts "✅ Configuration blanchisserie ajoutée :"
            puts "   ID: #{id}"
            puts "   Bien: #{options[:nom_bien]}"
            puts "   Coût calculé par lessive: #{l.cost_per_wash.round(2)} €"
          rescue => e
            puts "❌ Erreur: #{e.message}"
          end
        end

        def lister_blanchisseries
          laundries = LMNPCompta::Laundry.load_all
          if laundries.empty?
            puts "Aucune configuration de blanchisserie."
          else
            puts "Configurations de blanchisserie :"
            laundries.each do |l|
              cost = l.cost_per_wash.round(2)
              puts "- [#{l.id}] #{l.nom_bien} : #{cost} € / lessive"
              puts "    (Eau: #{l.conso_eau}m³ * #{l.prix_eau}€, Elec: #{l.conso_kwh}kWh * #{l.prix_kwh}€, Produit: #{l.prix_produit}€)"
            end
          end
        end
      end
    end
  end
end
