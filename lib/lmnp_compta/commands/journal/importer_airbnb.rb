require 'lmnp_compta/commands/journal/sub_command'
require 'lmnp_compta/airbnb_importer'
require 'lmnp_compta/journal'
require 'lmnp_compta/settings'
require 'optparse'

module LMNPCompta
  module Commands
    module Journal
      class ImporterAirbnb < SubCommand
        register 'importer-airbnb', 'Importer depuis un CSV Airbnb'

        def execute
          options = {}
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp journal importer-airbnb -f listings.csv"
            opts.on("-f", "--file FILE", "Fichier CSV Airbnb") { |v| options[:file] = v }
            opts.on("--dry-run", "Simulation uniquement") { options[:dry_run] = true }
          end

          begin
            parser.parse!(@args)
          rescue OptionParser::InvalidOption => e
            puts "❌ Erreur: #{e.message}"
            return
          end

          unless options[:file]
            puts "❌ Erreur: Fichier requis (-f)"
            return
          end

          puts "📂 Lecture : #{options[:file]}"

          journal_path = Settings.instance.journal_file
          journal = LMNPCompta::Journal.new(journal_path, year: Settings.instance.annee)

          importer = LMNPCompta::AirbnbImporter.new(options[:file], journal)
          new_entries = importer.import

          if new_entries.empty?
            puts "⚠️  Aucune nouvelle entrée trouvée."
            return
          end

          if options[:dry_run]
            puts "DRY RUN : Simulation de l'importation"
            puts "Les #{new_entries.length} écritures suivantes seraient ajoutées :"
            new_entries.each do |e|
               puts "- #{e.libelle} (#{e.ref}) | #{e.date} | Net: #{e.balance} €"
            end
            puts "Simulation terminée. Aucune modification n'a été enregistrée."
          else
            new_entries.each { |e| journal.add_entry(e) }
            journal.save!
            puts "✅ Importation terminée. #{new_entries.length} écritures générées."
            puts "💾 Journal sauvegardé (#{journal_path})"
          end
        end
      end
    end
  end
end
