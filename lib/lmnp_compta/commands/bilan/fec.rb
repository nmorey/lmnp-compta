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
          # Parse arguments
          options = {}
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp bilan fec [options]"
            opts.on("--year YEAR", Integer, "Année fiscale") do |v|
              options[:year] = v
            end
          end
          parser.parse!(@args)

          if options[:year]
            Settings.instance.annee = options[:year]
          end

          journal = LMNPCompta::Journal.new(Settings.instance.journal_file, year: Settings.instance.annee)

                  content = FECGenerator.generate(journal.entries)



                  filename = "#{Settings.instance.siren}FEC#{Settings.instance.annee}1231.txt"


          file_path = File.join(Settings.instance.data_dir, Settings.instance.annee.to_s, filename)

          FileUtils.mkdir_p(File.dirname(file_path))
          File.write(file_path, content)

          require 'digest'
          sha256 = Digest::SHA256.hexdigest(content)
          File.write("#{file_path}.sha256", sha256)

          puts "✅ Fichier FEC généré: #{file_path}"
          puts "🔒 Signature SHA-256 (Inaltérabilité) générée: #{file_path}.sha256"
        end
      end
    end
  end
end
