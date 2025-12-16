require 'csv'
require 'lmnp_compta/command'

module LMNPCompta
    class StatusCommand < Command
        register :status, "Affiche un résumé des mouvements bancaires (compte 512000) pour l'année en cours"

        def execute
            # Charger les paramètres et le journal
            year = Settings.instance.annee
            journal_path = Settings.instance.journal_file

            unless File.exist?(journal_path)
                puts "Erreur : Le fichier journal #{journal_path} est introuvable."
                exit 1
            end

            journal = Journal.new(journal_path)

            # Filtrer les écritures de l'année et impliquant le compte 512000
            relevant_entries = journal.entries.select do |entry|
                # Filtrer par année (basé sur la date de l'écriture)
                entry_year = Date.parse(entry.date.to_s).year
                next false unless entry_year == year.to_i

                # Filtrer par compte 512000
                entry.lines.any? { |line| line[:compte].to_s == '512000' }
            end

            total_credit = Montant.new(0)
            total_debit = Montant.new(0)

            # Préparer la sortie CSV (séparateur tab)
            output = CSV.generate(col_sep: "\t") do |csv|
                # En-têtes
                csv << ["Date", "Ref", "Crédit", "Débit"]

                relevant_entries.sort_by { |e| e.date.to_s }.each do |entry|
                    # Trouver la/les ligne(s) 512000
                    # Note: Une écriture peut théoriquement avoir plusieurs lignes 512000, on les agrège ou on fait une ligne par occurrence ?
                    # Pour simplifier et rester "CSV compliant" par écriture, on va sommer les mouvements 512000 de l'écriture.

                    lines_512 = entry.lines.select { |l| l[:compte].to_s == '512000' }

                    lines_512.each do |line|
                        # On inverse ici. Dans le journal credit = debit du compte indiqué pour
                        # ajouter le montant dans la transaction
                        # Ici on veut une vue "compte". Donc un credit de journal est un debit de compte
                        credit = line[:debit]
                        debit = line[:credit]

                        # Mise à jour des totaux globaux
                        total_credit += credit
                        total_debit += debit

                        csv << [
                            entry.date.to_s,
                            entry.ref || "",
                            (credit > Montant.new(0) ? credit.to_s : ""),
                            (debit > Montant.new(0) ? debit.to_s : "")
                        ]
                    end
                end

                # Ligne de résumé finale
                # Format demandé: Current Date, Total, Sum(credits), Sum(Debits)
                # "Total" suppose le solde net (Débit - Crédit) pour le compte 512000 (Solde Banque)
                net_total = total_credit - total_debit

                csv << [] # Ligne vide pour séparation
                csv << [
                    Date.today.to_s,
                    "Total (Solde): #{net_total}",
                    "", # Colonne Montant vide
                    total_credit.to_s,
                    total_debit.to_s
                ]
            end

            puts output
        end
    end
end
