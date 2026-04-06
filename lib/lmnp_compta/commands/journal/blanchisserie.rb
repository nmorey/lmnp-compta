require 'lmnp_compta/commands/journal/sub_command'
require 'lmnp_compta/laundry'
require 'lmnp_compta/journal'
require 'lmnp_compta/settings'
require 'date'

module LMNPCompta
  module Commands
    module Journal
      class Blanchisserie < SubCommand
        register 'blanchisserie', 'Ajouter ou lister les frais de blanchisserie'

        def execute
          require 'optparse'
          parser = OptionParser.new do |opts|
             opts.banner = "Usage: lmnp journal blanchisserie {ajouter|lister} [options]"
             opts.on("-h", "--help", "Affiche l'aide") do
                 puts opts
                 puts "\nSous-commandes :"
                 puts "  ajouter <id|nom> <YYYY-MM-DD>  Ajouter un frais de blanchisserie"
                 puts "  lister                         Lister les frais de l'année en cours"
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

          sub = @args.shift
          case sub
          when 'ajouter'
            ajouter_frais
          when 'lister'
            lister_frais
          else
            puts "Usage: lmnp journal blanchisserie ajouter <id|nom> <date_YYYY-MM-DD>"
            puts "       lmnp journal blanchisserie lister"
          end
        end

        private

        def ajouter_frais
          id_ou_nom = @args.shift
          date_str = @args.shift

          if id_ou_nom.nil? || date_str.nil?
            puts "❌ Erreur: Arguments manquants."
            puts "Usage: lmnp journal blanchisserie ajouter <id|nom> <YYYY-MM-DD>"
            return
          end

          laundry = LMNPCompta::Laundry.find(id_ou_nom)
          if laundry.nil?
            puts "❌ Erreur: Configuration de blanchisserie introuvable pour '#{id_ou_nom}'"
            return
          end

          begin
            date = Date.parse(date_str)
          rescue ArgumentError
            puts "❌ Erreur: Format de date invalide. Utilisez YYYY-MM-DD."
            return
          end

          journal_path = Settings.instance.journal_file
          journal = LMNPCompta::Journal.new(journal_path, year: Settings.instance.annee)

          if journal.year && date.year != journal.year
            puts "❌ Erreur: La date (#{date.year}) ne correspond pas à l'année comptable (#{journal.year})"
            return
          end

          cost = Montant.new(laundry.cost_per_wash)

          ref = "LNDRY-#{laundry.id}-#{date.strftime('%Y%m%d')}"

          base_ref = ref
          counter = 1
          while journal.entries.any? { |e| e.ref == ref }
            ref = "#{base_ref}-#{counter}"
            counter += 1
          end

          entry = Entry.new(
            date: date.to_s,
            journal: "OD",
            libelle: "Blanchisserie - #{laundry.nom_bien}",
            ref: ref
          )

          entry.add_debit(LMNPCompta::COMPTE["Entretien et réparations"], cost, "Frais de blanchisserie")
          entry.add_credit(LMNPCompta::COMPTE["Compte de l'exploitant"], cost, "Frais avancés")

          journal.add_entry(entry)
          journal.save!

          puts "✅ Frais de blanchisserie ajouté (#{cost} €) le #{date}"
          puts "💾 Journal sauvegardé (#{journal_path})"
        end

        def lister_frais
          journal_path = Settings.instance.journal_file
          journal = LMNPCompta::Journal.new(journal_path, year: Settings.instance.annee)

          entries = journal.entries.select { |e| e.ref.start_with?('LNDRY-') }
          if entries.empty?
            puts "Aucun frais de blanchisserie trouvé pour l'année #{journal.year}."
            return
          end

          total = Montant.new(0)
          puts "Frais de blanchisserie (#{journal.year}) :"
          entries.sort_by { |e| Date.parse(e.date) }.each do |e|
            amount = e.lines.first[:debit]
            total += amount
            puts "- #{e.date} | #{e.libelle} | #{amount} €"
          end
          puts "------------------------------------------------"
          puts "Total: #{total} €"
        end
      end
    end
  end
end
