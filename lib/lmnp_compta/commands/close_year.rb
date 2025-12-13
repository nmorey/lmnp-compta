require 'lmnp_compta/command'
require 'lmnp_compta/journal'
require 'lmnp_compta/entry'

module LMNPCompta
  module Commands
    class CloseYear < Command
      register 'cloturer', 'Générer l\'écriture de clôture de trésorerie'

      COMPTE_BANQUE = "512000"
      COMPTE_EXPLOITANT = "108000"

      def execute
        OptionParser.new do |opts|
          opts.banner = "Usage: lmnp cloturer"
        end.parse!(@args)

        settings = LMNPCompta::Settings.instance
        journal_file = settings.journal_file
        annee = settings.annee

        journal = LMNPCompta::Journal.new(journal_file)

        puts "==========================================================="
        puts "       CLÔTURE ANNUELLE DE TRÉSORERIE (Année #{annee})"
        puts "==========================================================="

        solde_banque = Montant.new("0")

        journal.entries.each do |e|
          e.lines.each do |l|
            if l[:compte].to_s == COMPTE_BANQUE
              debit = l[:debit]
              credit = l[:credit]
              solde_banque += (debit - credit)
            end
          end
        end

        puts "Solde actuel du compte #{COMPTE_BANQUE} : #{solde_banque} €"

        if solde_banque.abs < Montant.new(0.01)
          puts "✅ Le compte est déjà à zéro (ou presque). Aucune écriture nécessaire."
          return
        end

        montant_abs = solde_banque.abs

        new_entry = LMNPCompta::Entry.new(
          date: "#{annee}-12-31",
          journal: "OD",
          libelle: "Virement solde trésorerie vers compte privé (Clôture)",
          ref: "CLOTURE#{annee}"
        )

        if solde_banque > Montant.new(0)
          puts "👉 Action : Virement du surplus vers votre compte personnel."
          new_entry.add_debit(COMPTE_EXPLOITANT, montant_abs)
          new_entry.add_credit(COMPTE_BANQUE, montant_abs)
        else
          puts "👉 Action : Constatation de votre apport personnel pour combler le déficit."
          new_entry.add_debit(COMPTE_BANQUE, montant_abs)
          new_entry.add_credit(COMPTE_EXPLOITANT, montant_abs)
        end

        journal.add_entry(new_entry)
        journal.save!

        puts ""
        puts "✅ Écriture générée avec succès :"
        new_entry.lines.each do |l|
          mnt = l[:debit] > Montant.new(0) ? "Débit: #{l[:debit]} €" : "Crédit: #{l[:credit]} €"
          puts "   - Compte #{l[:compte]} | #{mnt}"
        end
        puts "-----------------------------------------------------------"
        puts "Le compte #{COMPTE_BANQUE} est maintenant soldé à 0.00 € pour le bilan."
      end
    end
  end
end
