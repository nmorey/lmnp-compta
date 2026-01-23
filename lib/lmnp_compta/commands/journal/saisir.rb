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
      class Saisir < SubCommand
        register 'saisir', 'Saisir une écriture (interactif ou CLI)'

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
              options[:current_line] ||= {}
              options[:current_line][:compte] = v
              check_line_complete(options)
            end
            opts.on("-s", "--sens SENS", "Sens (D/C)") do |v|
              options[:current_line] ||= {}
              options[:current_line][:sens] = v.upcase
              check_line_complete(options)
            end
            opts.on("-m", "--montant MONTANT", "Montant") do |v|
              options[:current_line] ||= {}
              options[:current_line][:montant] = v
              check_line_complete(options)
            end
          end
          parser.parse!(@args)

          if options[:lignes].any?
            run_cli_mode(options)
          else
            run_interactive_mode
          end
        end

        private

        def check_line_complete(options)
          l = options[:current_line]
          if l[:compte] && l[:sens] && l[:montant]
            options[:lignes] << l
            options[:current_line] = {}
          end
        end

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
              entry.add_debit(l[:compte], mnt)
            else
              entry.add_credit(l[:compte], mnt)
            end
          end

          save_entry(entry)
        end

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

            if sens == 'D'
              entry.add_debit(compte, montant)
            else
              entry.add_credit(compte, montant)
            end

            puts "Solde actuel: #{entry.balance}"
            if entry.balanced? && entry.lines.any?
              print "Écriture équilibrée. Enregistrer ? (O/n/c pour continuer) "
              r = STDIN.gets.chomp.downcase
              break if r == 'o' || r == ''
            end
          end

          save_entry(entry)
        end

        def save_entry(entry)
          settings = Settings.instance
          entry_year = Date.parse(entry.date.to_s).year
          journal_path = settings.journal_file(annee: entry_year)
          journal = LMNPCompta::Journal.new(journal_path, year: entry_year)

          journal.add_entry(entry)
          journal.save!
          puts "✅ Écriture #{entry.id} enregistrée dans #{journal_path}."
        end

        def prompt(q, default: nil)
          label = default ? "#{q} [#{default}]: " : "#{q}: "
          print label
          input = STDIN.gets.chomp
          input = default if input.empty? && default
          input
        end
      end
    end
  end
end
