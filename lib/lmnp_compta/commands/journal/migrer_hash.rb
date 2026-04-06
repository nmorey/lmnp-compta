require 'lmnp_compta/commands/journal/sub_command'
require 'lmnp_compta/journal'
require 'lmnp_compta/settings'
require 'open3'
require 'date'
require 'optparse'

module LMNPCompta
  module Commands
    module Journal
      class MigrerHash < SubCommand
        register 'migrer-hash', 'Migre un ancien journal vers le format cryptographique (Date ajout + SHA256)'

        def execute
          # Parse arguments
          options = {}
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp journal migrer-hash [options]"
            opts.on("--year YEAR", Integer, "Année fiscale") do |v|
              options[:year] = v
            end
          end
          parser.parse!(@args)

          if options[:year]
            Settings.instance.annee = options[:year]
          end

          journal_path = Settings.instance.journal_file
          unless File.exist?(journal_path)
            puts "❌ Erreur : Journal introuvable (#{journal_path})"
            return
          end

          puts "📂 Chargement du journal existant..."
          journal = LMNPCompta::Journal.new(journal_path, year: Settings.instance.annee)

          # Force reloading without integrity check just in case
          journal.load!(skip_integrity: true)

          if journal.entries.empty?
            puts "⚠️  Le journal est vide. Rien à migrer."
            return
          end

          puts "🔐 Migration des écritures et calcul des signatures cryptographiques..."

          modifications = 0

          journal.entries.each do |entry|
            # 1. Retrieve or set created_at
            unless entry.created_at
              entry.created_at = get_git_date(journal_path, entry.id)
            end

            # 2. Re-calculate hash using Journal's method
            # We recalculate even if it exists to ensure the chain is strictly perfect from beginning to end
            expected_hash = journal.generate_hash(entry)

            if entry.hash != expected_hash
              entry.hash = expected_hash
              modifications += 1
            end
          end

          if modifications > 0
            journal.save!
            puts "✅ Migration terminée avec succès !"
            puts "   #{modifications} écritures ont été scellées cryptographiquement."
            puts "   ⚠️  Pensez à faire un `git commit` pour valider ces modifications."
          else
            puts "✅ Le journal est déjà au format cryptographique (aucune modification nécessaire)."
          end
        end

        private

        def get_git_date(file_path, entry_id)
          # Utilise git log pour trouver la date du premier commit ajoutant cette écriture
          cmd = "git log --diff-filter=A -G \"^[ \t]*-?[ \t]*id: #{entry_id}[ \t]*$\" --format=%cs -- #{file_path} | tail -1"
          stdout, _stderr, status = Open3.capture3(cmd)

          date_str = stdout.strip

          if status.success? && !date_str.empty?
             return date_str
          end

          # Fallback si l'entrée n'est pas encore committée ou en l'absence de git
          Date.today.to_s
        end
      end
    end
  end
end