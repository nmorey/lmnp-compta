require 'lmnp_compta/command'
require 'yaml'
require 'optparse'

module LMNPCompta
  module Commands
    class Init < Command
      register 'init', 'Initialiser le projet avec un fichier de configuration lmnp.yaml'

      def execute
        options = {}
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lmnp init --siren SIREN --annee ANNEE [options]"

          opts.on("--siren SIREN", "Votre numéro SIREN (Obligatoire)") { |v| options[:siren] = v }
          opts.on("--annee ANNEE", Integer, "Année fiscale (Obligatoire)") { |v| options[:annee] = v }
          
          opts.on("--journal FILE", "Chemin du fichier journal") { |v| options[:journal_file] = v }
          opts.on("--stock FILE", "Chemin du fichier stock") { |v| options[:stock_file] = v }
          opts.on("--immo FILE", "Chemin du fichier immobilisations") { |v| options[:immo_file] = v }
          opts.on("-f", "--force", "Écraser le fichier existant") { options[:force] = true }
        end
        parser.parse!(@args)

        if options[:siren].nil? || options[:annee].nil?
          puts "❌ Erreur: Les arguments --siren et --annee sont obligatoires."
          puts parser
          exit 1
        end

        # Auto-compute defaults if not provided
        config = {
          'siren' => options[:siren],
          'annee' => options[:annee],
          'journal_file' => options[:journal_file] || "data/journal_#{options[:annee]}.yaml",
          'stock_file' => options[:stock_file] || "data/stock_fiscal.yaml",
          'immo_file' => options[:immo_file] || "data/immobilisations.yaml"
        }

        if File.exist?('lmnp.yaml') && !options[:force]
          puts "❌ Erreur: Le fichier 'lmnp.yaml' existe déjà. Utilisez --force pour l'écraser."
          exit 1
        end

        File.write('lmnp.yaml', config.to_yaml)
        puts "✅ Configuration sauvegardée dans 'lmnp.yaml'"
        
        # Create data directory if it doesn't exist, as the default paths use it
        Dir.mkdir('data') unless Dir.exist?('data')
        puts "📂 Dossier 'data/' vérifié."
      end
    end
  end
end
