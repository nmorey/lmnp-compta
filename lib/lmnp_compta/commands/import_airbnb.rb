require 'lmnp_compta/command'
require 'lmnp_compta/journal'
require 'lmnp_compta/airbnb_importer'
require 'optparse'

module LMNPCompta
    module Commands
        class ImportAirbnb < Command
            register 'importer-airbnb', 'Importer les transactions depuis un export CSV Airbnb'

            def execute
                options = {}
                OptionParser.new do |opts|
                    opts.banner = "Usage: lmnp importer-airbnb [options]"
                    opts.on("-f", "--file FICHER", "Chemin vers le fichier CSV Airbnb") { |f| options[:file] = f }
                    opts.on("--dry-run", "Simuler l'import sans sauvegarder") { options[:dry_run] = true }
                end.parse!(@args)

                if options[:file].nil? || !File.exist?(options[:file])
                    raise "Fichier introuvable ou option -f manquante."
                end

                # Ensure data directory exists
                Dir.mkdir('data') unless Dir.exist?('data')

                journal_file = Settings.instance.journal_file
                journal = Journal.new(journal_file, year: Settings.instance.annee)

                puts "📂 Lecture : #{options[:file]}"

                importer = AirbnbImporter.new(options[:file], journal)
                new_entries = importer.import

                if options[:dry_run]
                    puts "\n🔎 DRY RUN : Simulation de l'importation."
                    if new_entries.any?
                        puts "Les #{new_entries.length} écritures suivantes seraient ajoutées :"
                        new_entries.each do |e|
                            puts "   [#{e.date}] #{e.libelle} (Ref: #{e.ref}) - Net: #{e.balance} € (Solde)"
                            e.lines.each do |l|
                                amount = l[:debit] > Montant.new(0) ? "D: #{l[:debit]} €" : "C: #{l[:credit]} €"
                                puts "      -> #{l[:compte]} : #{amount} (#{l[:libelle_ligne] || '?'})"
                            end
                        end
                    else
                        puts "Aucune nouvelle écriture détectée."
                    end
                    puts "\n🚫 Aucune modification n'a été enregistrée (Mode Dry Run)."
                    return
                end

                puts "\n✅ Importation terminée. #{new_entries.length} écritures générées."

                if new_entries.any?
                    new_entries.each do |e|
                        journal.add_entry(e)
                    end

                    journal.save!
                    puts "💾 Journal sauvegardé (#{journal_file})"
                else
                    puts "Aucune nouvelle écriture à sauvegarder (Doublons ou fichier vide)."
                end
            end
        end
    end
end
