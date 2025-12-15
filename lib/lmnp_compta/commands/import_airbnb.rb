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
        end.parse!(@args)

        if options[:file].nil? || !File.exist?(options[:file])
          raise "Fichier introuvable ou option -f manquante."
        end

        # Ensure data directory exists
        Dir.mkdir('data') unless Dir.exist?('data')
        
        journal_file = LMNPCompta::Settings.instance.journal_file
        journal = LMNPCompta::Journal.new(journal_file, year: LMNPCompta::Settings.instance.annee)

        puts "📂 Lecture : #{options[:file]}"

        importer = LMNPCompta::AirbnbImporter.new(options[:file], journal)
        new_entries = importer.import

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
