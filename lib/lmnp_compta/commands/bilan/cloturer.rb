require 'lmnp_compta/commands/bilan/sub_command'
require 'lmnp_compta/journal'
require 'lmnp_compta/entry'
require 'lmnp_compta/asset'
require 'lmnp_compta/amortization'
require 'lmnp_compta/trip'
require 'lmnp_compta/vehicle'
require 'lmnp_compta/settings'
require 'date'

module LMNPCompta
  module Commands
    module Bilan
      class Cloturer < SubCommand
        register 'cloturer', 'Générer les écritures de fin d\'année'

        def execute
          require 'optparse'
          timestamp_only = false
          skip_timestamp = false

          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp bilan cloturer [options]"
            opts.on("--timestamp", "--timestamp-only", "Horodater uniquement le journal (sans générer d'écritures)") do
              timestamp_only = true
            end
            opts.on("--no-timestamp", "Ne pas horodater le journal à la fin de la clôture (pour tests/debug)") do
              skip_timestamp = true
            end
            opts.on("-h", "--help", "Affiche l'aide") do
              puts opts
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

          puts "==========================================================="
          puts "       CLÔTURE DE L'EXERCICE #{Settings.instance.annee}"
          puts "==========================================================="

          journal_path = Settings.instance.journal_file
          annee = Settings.instance.annee
          journal = LMNPCompta::Journal.new(journal_path, year: annee)

          if timestamp_only
            puts "\n👉 Mode horodatage uniquement."
            journal.verify_integrity!
            journal.timestamp! unless skip_timestamp
            return
          end

          if journal.closed?
            puts "⚠️  Le journal est déjà clôturé. Il ne peut plus être modifié."
            return
          end

          LMNPCompta::Cloture.cloturer(journal, annee)

          journal.save!(force: true)
          journal.verify_integrity!
          journal.timestamp! unless skip_timestamp

          puts "\n✅ Clôture terminée. Toutes les écritures ont été générées."
        end
      end
    end
  end
end
