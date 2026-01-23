require 'lmnp_compta/commands/bilan/sub_command'
require 'lmnp_compta/fec_generator'
require 'lmnp_compta/journal'
require 'lmnp_compta/settings'
require 'fileutils'

module LMNPCompta
  module Commands
    module Bilan
      class Fec < SubCommand
        register 'fec', 'Exporter le Fichier des Écritures Comptables'

                def execute

                  journal = LMNPCompta::Journal.new(Settings.instance.journal_file)

                  content = FECGenerator.generate(journal.entries)



                  filename = "#{Settings.instance.siren}FEC#{Settings.instance.annee}1231.txt"


          file_path = File.join(Settings.instance.data_dir, Settings.instance.annee.to_s, filename)

          FileUtils.mkdir_p(File.dirname(file_path))
          File.write(file_path, content)
          puts "✅ Fichier FEC généré: #{file_path}"
        end
      end
    end
  end
end
