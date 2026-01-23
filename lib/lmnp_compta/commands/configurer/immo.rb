require 'lmnp_compta/commands/configurer/sub_command'
require 'lmnp_compta/asset'
require 'lmnp_compta/montant'
require 'lmnp_compta/settings'
require 'yaml'
require 'optparse'
require 'fileutils'
require 'date'

module LMNPCompta
  module Commands
    module Configurer
      class Immo < SubCommand
        register 'immo', 'Créer une immobilisation'

        DEFAULT_BREAKDOWN = [
          Asset::Component.new(nom: "Terrain", valeur: 15, duree: 0 ),
          Asset::Component.new(nom: "Gros Oeuvre", valeur: 40, duree: 50 ),
          Asset::Component.new(nom: "Façade", valeur: 15, duree: 25 ),
          Asset::Component.new(nom: "Installations Générales", valeur: 15, duree: 20 ),
          Asset::Component.new(nom: "Agencements Intérieurs", valeur: 15, duree: 15 )
        ]

        def execute
          options = {}
          overrides = {}
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp configurer immo [options]"
            opts.on("--valeur MONTANT", "Valeur totale du bien") { |v| options[:valeur] = v }
            opts.on("--date DATE", "Date d'achat (AAAA-MM-JJ)") { |v| options[:date] = v }
            opts.on("--nom NOM", "Nom du bien") { |v| options[:nom] = v }
            # Breakdown options
            opts.on("--terrain PERCENT", Integer) { |v| overrides['Terrain'] = v }
            opts.on("--gros-oeuvre PERCENT", Integer) { |v| overrides['Gros Oeuvre'] = v }
            opts.on("--facade PERCENT", Integer) { |v| overrides['Façade'] = v }
            opts.on("--installations PERCENT", Integer) { |v| overrides['Installations Générales'] = v }
            opts.on("--agencements PERCENT", Integer) { |v| overrides['Agencements Intérieurs'] = v }
          end

          begin
            parser.parse!(@args)
          rescue OptionParser::InvalidOption => e
            puts "❌ Erreur: #{e.message}"
            puts parser
            return
          end

          settings = Settings.instance
          immo_file = settings.immo_file
          existing_assets = File.exist?(immo_file) ? YAML.load_file(immo_file) : []

          breakdown = DEFAULT_BREAKDOWN.map do |item|
            Asset::Component.new(nom: item.nom,
                                 valeur: overrides[item.nom] || item.valeur,
                                 duree: item.duree)
          end

          total_percent = breakdown.sum(&:valeur)
          if overrides.any? && total_percent != 100
            puts "Erreur: Total pourcentages = #{total_percent}% (doit être 100%)."
            return
          end

          unless options[:valeur] && options[:date] && options[:nom]
            puts "=== Création Immobilisation ==="
            breakdown.each do |c|
               dur = c.duree == 0 ? "Non amortissable" : "#{c.duree} ans"
               puts "  - #{c.nom.ljust(25)} : #{c.valeur}% (#{dur})"
            end
            puts ""
          end

          nom = options[:nom] || prompt("Nom du bien")
          date_str = options[:date] || prompt("Date d'achat (AAAA-MM-JJ)", default: Date.today.to_s)
          valeur_str = options[:valeur] || prompt("Valeur totale (Euros)")
          valeur_totale = Montant.new(valeur_str)

          puts "\nCalcul de la ventilation pour #{valeur_totale} € :"
          composants = []
          check_total = Montant.new(0)

          breakdown.each do |item|
            val = valeur_totale * (item.valeur / 100.0)
            check_total += val
            puts "  - #{item.nom.ljust(25)} : #{val} €"
            composants << Asset::Component.new(nom: item.nom, valeur: val, duree: item.duree)
          end

          # Rounding adjustment
          diff = valeur_totale - check_total
          unless diff.zero?
             # Find component with highest percent to adjust (simple heuristic)
             comp_name = DEFAULT_BREAKDOWN.max_by(&:valeur).nom
             puts "  (Ajustement arrondi : #{diff} € sur #{comp_name})"
             target = composants.find { |c| c.nom == comp_name }
             target.valeur = (Montant.new(target.valeur) + diff).to_f
          end

          new_asset = Asset.new(
            nom: nom,
            date_achat: date_str,
            date_mise_en_location: date_str,
            valeur_achat: valeur_totale.to_f,
            composants: composants
          )

          if existing_assets.any? { |a| a['nom'] == nom }
            puts "⚠️  Attention : Un bien nommé '#{nom}' existe déjà."
            return unless prompt("Ajouter quand même ? (o/N)").downcase == 'o'
          end

          if options[:valeur].nil?
            return unless prompt("\nConfirmer l'enregistrement ? (O/n)").downcase != 'n'
          end

          existing_assets << new_asset.to_h
          FileUtils.mkdir_p(File.dirname(immo_file))
          File.write(immo_file, existing_assets.to_yaml)
          puts "✅ Bien ajouté : #{immo_file}"
        end

        private

        def prompt(q, default: nil)
          label = default ? "#{q} [#{default}]: " : "#{q}: "
          print label
          input = STDIN.gets.chomp
          input = default if input.empty? && default
          input
        end
      end
    end
  end
end
