require 'lmnp_compta/command'
require 'yaml'
require 'optparse'
require 'fileutils'

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

                    opts.on("--data-dir DIR", "Chemin du dossier de données (default: data)") { |v| options[:data_dir] = v }
                    opts.on("--journal FILE", "Nom du fichier journal (default: journal.yaml)") { |v| options[:journal_file] = v }
                    opts.on("--stock FILE", "Nom du fichier stock (default: stock_fiscal.yaml)") { |v| options[:stock_file] = v }
                    opts.on("--immo FILE", "Nom du fichier immobilisations (default: immobilisations.yaml)") { |v| options[:immo_file] = v }
                    opts.on("-f", "--force", "Écraser le fichier existant") { options[:force] = true }
                end
                parser.parse!(@args)

                if options[:siren].nil? || options[:annee].nil?
                    puts "❌ Erreur: Les arguments --siren et --annee sont obligatoires."
                    puts parser
                    exit 1
                end

                # Valeurs par défaut auto-calculées
                data_dir = options[:data_dir] || "data"
                config = {
                    'siren' => options[:siren],
                    'annee' => options[:annee],
                    'data_dir' => data_dir,
                    'journal_file' => options[:journal_file] || "journal.yaml",
                    'stock_file' => options[:stock_file] || "stock_fiscal.yaml",
                    'immo_file' => options[:immo_file] || "immobilisations.yaml"
                }

                if File.exist?('lmnp.yaml') && !options[:force]
                    puts "❌ Erreur: Le fichier 'lmnp.yaml' existe déjà. Utilisez --force pour l'écraser."
                    exit 1
                end

                File.write('lmnp.yaml', config.to_yaml)
                puts "✅ Configuration sauvegardée dans 'lmnp.yaml'"

                # Création du dossier de données
                FileUtils.mkdir_p(File.join(data_dir, options[:annee].to_s))
                puts "📂 Dossier '#{data_dir}/#{options[:annee]}/' vérifié."
            end
        end
    end
end
