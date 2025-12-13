require 'lmnp_compta/command'
require 'lmnp_compta/journal'
require 'lmnp_compta/fec_generator'

module LMNPCompta
  module Commands
    class ExportFEC < Command
      register 'export-fec', 'Générer le fichier FEC (Fichier des Écritures Comptables)'

      def execute
        OptionParser.new do |opts|
          opts.banner = "Usage: lmnp export-fec"
        end.parse!(@args)

        settings = LMNPCompta::Settings.instance
        siren = settings.siren
        annee = settings.annee
        journal_file = settings.journal_file

        output_file = "#{siren}FEC#{annee}1231.txt"

        puts "Lecture du fichier #{journal_file}..."
        unless File.exist?(journal_file)
          raise "Fichier source introuvable. Lancez d'abord la saisie."
        end

        journal = LMNPCompta::Journal.new(journal_file)

        puts "Génération du FEC..."

        begin
          csv_content = LMNPCompta::FECGenerator.generate(journal.entries)
          File.write(output_file, csv_content)
          puts "✅ Fichier FEC généré: #{output_file}"
        rescue => e
          raise e.message
        end
      end
    end
  end
end
