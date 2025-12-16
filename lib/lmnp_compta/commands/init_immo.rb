require 'lmnp_compta/command'
require 'lmnp_compta/montant'
require 'lmnp_compta/asset'
require 'yaml'
require 'date'
require 'readline'
require 'optparse'
require 'fileutils'

module LMNPCompta
    module Commands
        class InitImmo < Command
            register 'creer-immo', 'Générer le fichier d\'immobilisations avec une ventilation par défaut'

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
                    opts.banner = "Usage: lmnp creer-immo [options]"
                    opts.on("--valeur MONTANT", "Valeur totale du bien (frais de notaire inclus si activable)") { |v| options[:valeur] = v }
                    opts.on("--date DATE", "Date d\'achat/Mise en location (AAAA-MM-JJ)") { |v| options[:date] = v }
                    opts.on("--nom NOM", "Nom du bien (ex: 'Appartement Lyon')") { |v| options[:nom] = v }

                    # Options de ventilation personnalisée
                    opts.on("--terrain PERCENT", Integer, "Pourcentage Terrain") { |v| overrides['Terrain'] = v }
                    opts.on("--gros-oeuvre PERCENT", Integer, "Pourcentage Gros Oeuvre") { |v| overrides['Gros Oeuvre'] = v }
                    opts.on("--facade PERCENT", Integer, "Pourcentage Façade") { |v| overrides['Façade'] = v }
                    opts.on("--installations PERCENT", Integer, "Pourcentage Installations Générales") { |v| overrides['Installations Générales'] = v }
                    opts.on("--agencements PERCENT", Integer, "Pourcentage Agencements Intérieurs") { |v| overrides['Agencements Intérieurs'] = v }
                end
                parser.parse!(@args)

                settings = Settings.instance
                immo_file = settings.immo_file

                # Load existing assets or initialize empty list
                existing_assets = []
                if File.exist?(immo_file)
                    existing_assets = YAML.load_file(immo_file) || []
                end

                # Apply overrides to breakdown
                breakdown = DEFAULT_BREAKDOWN.map do |item|
                    Asset::Component.new(nom: item.nom,
                                         valeur: overrides[item.nom] || item.valeur,
                                         duree: item.duree)
                end

                # Validation: Total must be 100% if customized
                total_percent = breakdown.sum { |i| i.valeur }
                if overrides.any? && total_percent != 100
                    raise "Erreur: Le total des pourcentages doit être égal à 100% (Actuel: #{total_percent}%). Veuillez ajuster les options."
                end

                # Interactive Mode if missing args
                unless options[:valeur] && options[:date] && options[:nom]
                    puts "=== Création du fichier d'immobilisations ==="
                    puts "Ventilation appliquée :"
                    breakdown.each do |c|
                        duration = c.duree == 0 ? "Non amortissable" : "#{c.duree} ans"
                        puts "  - #{c.nom.ljust(25)} : #{c.valeur}% (#{duration})"
                    end
                    puts ""
                end

                nom = options[:nom] || prompt("Nom du bien")
                date_str = options[:date] || prompt("Date d'achat (AAAA-MM-JJ)", default: Date.today.to_s)

                valeur_str = options[:valeur]
                unless valeur_str
                    valeur_str = prompt("Valeur totale du bien (Euros)")
                end
                valeur_totale = Montant.new(valeur_str)

                puts "\nCalcul de la ventilation pour une valeur de #{valeur_totale} € :"

                composants = []
                check_total = Montant.new(0)

                breakdown.each do |item|
                    # Montant * Percent / 100
                    valeur_compo = valeur_totale * (item.valeur / 100.0)
                    check_total += valeur_compo

                    puts "  - #{item.nom.ljust(25)} : #{valeur_compo} €"

                    composants << Asset::Component.new(
                        nom: item.nom,
                        valeur: valeur_compo,
                        duree: item.duree
                    )
                end

                # Adjust rounding errors
                diff = valeur_totale - check_total
                unless diff.zero?
                    max_comp_name = breakdown.max_by { |b| b[:percent] }[:name]
                    puts "  (Ajustement arrondi : #{diff} € sur #{max_comp_name})"
                    comp_to_adjust = composants.find { |c| c.nom == max_comp_name }
                    comp_to_adjust.valeur = (Montant.new(comp_to_adjust.valeur) + diff).to_f
                end

                # New asset structure
                new_asset = Asset.new(
                    nom: nom,
                    date_achat: date_str,
                    date_mise_en_location: date_str,
                    valeur_achat: valeur_totale.to_f,
                    composants: composants
                )

                # Check for duplicates by name
                if existing_assets.any? { |a| a['nom'] == nom }
                    puts "⚠️  Attention : Un bien nommé '#{nom}' existe déjà."
                    print "Voulez-vous l'ajouter quand même ? (o/N) "
                    r = STDIN.gets.chomp.downcase
                    return unless r == 'o'
                end

                # Confirm write in interactive mode
                if options[:valeur].nil?
                    print "\nConfirmer l'enregistrement ? (O/n) "
                    r = STDIN.gets.chomp.downcase
                    return if r == 'n'
                end

                # Append serialized hash
                existing_assets << new_asset.to_h

                FileUtils.mkdir_p(File.dirname(immo_file))
                File.write(immo_file, existing_assets.to_yaml)
                puts "✅ Bien ajouté au fichier : #{immo_file}"            end

            private

            def prompt(question, default: nil, cast_to: nil)
                label = default ? "#{question} [#{default}]: " : "#{question}: "
                print label
                input = STDIN.gets.chomp
                input = default if input.empty? && default
                return input if input.nil?

                return input.send(cast_to) if cast_to
                input
            end
        end
    end
end
