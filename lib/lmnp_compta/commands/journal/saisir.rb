require 'lmnp_compta/commands/journal/sub_command'
require 'lmnp_compta/entry'
require 'lmnp_compta/montant'
require 'lmnp_compta/journal'
require 'lmnp_compta/settings'
require 'date'
require 'optparse'

module LMNPCompta
  module Commands
    module Journal
      # Sous-commande pour saisir une écriture comptable dans le journal (en mode interactif ou en ligne de commande).
      class Saisir < SubCommand
        register 'saisir', 'Saisir une écriture (interactif ou CLI)'

        # Exécute la saisie d'écriture en mode CLI ou interactif.
        # @return [void]
        def execute
          options = { lignes: [] }
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp journal saisir [options]"
            opts.on("-d", "--date DATE", "Date (AAAA-MM-JJ)") { |v| options[:date] = v }
            opts.on("-j", "--journal CODE", "Journal (AC, BQ, OD...)") { |v| options[:journal] = v }
            opts.on("-l", "--libelle LIB", "Libellé de l'écriture") { |v| options[:libelle] = v }
            opts.on("-r", "--ref REF", "Référence (Facultatif)") { |v| options[:ref] = v }
            opts.on("-f", "--file FILE", "Fichier source (Facultatif)") { |v| options[:file] = v }

            # Multiple lines management
            opts.on("-c", "--compte COMPTE", "Compte pour la ligne") do |v|
              commit_current_line(options) if options[:current_line]
              options[:current_line] = { compte: v }
            end
            opts.on("-s", "--sens SENS", "Sens (D/C)") do |v|
              ensure_current_line_started(options)
              raise "Sens déjà spécifié pour la ligne en cours (#{options[:current_line][:compte]})" if options[:current_line][:sens]
              val = v.upcase
              raise "Sens invalide : #{v} (doit être D ou C)" unless %w[D C].include?(val)
              options[:current_line][:sens] = val
            end
            opts.on("-m", "--montant MONTANT", "Montant") do |v|
              ensure_current_line_started(options)
              raise "Montant déjà spécifié pour la ligne en cours (#{options[:current_line][:compte]})" if options[:current_line][:montant]
              options[:current_line][:montant] = v
            end
            opts.on("-L", "--libelle-ligne LIB", "--libelle-line LIB", "Libellé de la ligne (Facultatif)") do |v|
              ensure_current_line_started(options)
              raise "Libellé de ligne déjà spécifié pour la ligne en cours (#{options[:current_line][:compte]})" if options[:current_line][:libelle_ligne]
              options[:current_line][:libelle_ligne] = v
            end
          end
          parser.parse!(@args)

          commit_current_line(options) if options[:current_line]

          if options[:lignes].any?
            run_cli_mode(options)
          else
            run_interactive_mode
          end
        end

        private

        # Vérifie qu'un compte a bien été spécifié avant de définir le sens ou montant de la ligne.
        # @param options [Hash] options de la commande
        # @return [void]
        def ensure_current_line_started(options)
          raise "Ligne non initialisée : spécifiez d'abord un compte avec -c/--compte" unless options[:current_line]
        end

        # Valide et ajoute la ligne comptable en cours à la liste des lignes de l'écriture.
        # @param options [Hash] options de la commande
        # @return [void]
        def commit_current_line(options)
          l = options[:current_line]
          unless l[:compte] && l[:sens] && l[:montant]
            raise "Ligne incomplète pour le compte #{l[:compte]} : sens (-s) et montant (-m) obligatoires"
          end
          options[:lignes] << l
          options[:current_line] = nil
        end

        # Traite la saisie directe d'écriture passée via les arguments de ligne de commande.
        # @param options [Hash] options de la commande
        # @return [void]
        def run_cli_mode(options)
          puts "⚙️  Mode Commande (Strict)"
          unless options[:date] && options[:journal] && options[:libelle]
            raise "Arguments manquants (--date, --journal, --libelle obligatoires en mode CLI)"
          end

          parsed_date = Date.parse(options[:date]).to_s

          entry = Entry.new(
            date: parsed_date,
            journal: options[:journal],
            libelle: options[:libelle],
            ref: options[:ref],
            file: options[:file]
          )

          options[:lignes].each do |l|
            mnt = Montant.new(l[:montant])
            if l[:sens] == 'D'
              entry.add_debit(l[:compte], mnt, l[:libelle_ligne])
            else
              entry.add_credit(l[:compte], mnt, l[:libelle_ligne])
            end
          end

          save_entry(entry)
        end

        # Lance la saisie interactive d'une écriture au terminal.
        # @return [void]
        def run_interactive_mode
          puts "=== NOUVELLE ÉCRITURE ==="
          date = prompt("Date", default: Date.today.to_s)
          journal_code = prompt("Journal (AC/BQ/OD)", default: "AC")
          libelle = prompt("Libellé")
          ref = prompt("Référence (Facultatif)")

          entry = Entry.new(date: date, journal: journal_code, libelle: libelle, ref: ref)

          loop do
            puts "\n--- Ligne ---"
            compte = prompt("Compte")
            break if compte.empty?

            sens = prompt("Sens (D/C)", default: "D").upcase
            montant = Montant.new(prompt("Montant"))
            libelle_ligne = prompt("Libellé de la ligne (Facultatif)")
            libelle_ligne = nil if libelle_ligne && libelle_ligne.strip.empty?

            if sens == 'D'
              entry.add_debit(compte, montant, libelle_ligne)
            else
              entry.add_credit(compte, montant, libelle_ligne)
            end

            puts "Solde actuel: #{entry.balance}"
            if entry.balanced? && entry.lines.any?
              print "Écriture équilibrée. Enregistrer ? (O/n/c pour continuer) "
              r = $stdin.gets.to_s.chomp.downcase
              break if r == 'o' || r == ''
            end
          end

          save_entry(entry)
        end

        # Enregistre l'écriture dans le journal correspondant à son année fiscale.
        # @param entry [Entry] écriture à sauvegarder
        # @return [void]
        def save_entry(entry)
          settings = Settings.instance
          entry_year = Date.parse(entry.date.to_s).year
          journal_path = settings.journal_file(annee: entry_year)
          journal = LMNPCompta::Journal.new(journal_path, year: entry_year)

          journal.add_entry(entry)
          journal.save!
          puts "✅ Écriture #{entry.id} enregistrée dans #{journal_path}."
        end

        # Affiche une invite de saisie au terminal.
        # @param q [String] question
        # @param default [String, nil] valeur par défaut
        # @return [String] saisie
        def prompt(q, default: nil)
          label = default ? "#{q} [#{default}]: " : "#{q}: "
          print label
          input = $stdin.gets.to_s.chomp
          input = default if input.empty? && default
          input
        end
      end
    end
  end
end
