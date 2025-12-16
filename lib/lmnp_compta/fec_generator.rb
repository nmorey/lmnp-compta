require 'csv'
require 'date'

module LMNPCompta
    # Générateur de fichier FEC (Fichier des Écritures Comptables)
    class FECGenerator
        HEADERS = %w[
      JournalCode JournalLib EcritureNum EcritureDate CompteNum CompteLib CompAuxNum CompAuxLib
      PieceRef PieceDate EcritureLib Debit Credit EcritureLet DateLet ValidDate Montantdevise Idevise
    ]

        # Génère le contenu CSV du FEC
        # @param entries [Array<LMNPCompta::Entry>] Liste des écritures
        # @return [String] Contenu CSV
        def self.generate(entries)
            CSV.generate(col_sep: "\t") do |csv|
                csv << HEADERS
                entries.sort_by { |e| Date.parse(e.date.to_s) }.each do |entry|
                    process_entry(entry, csv)
                end
            end
        end

        private

        def self.process_entry(entry, csv)
            date_formatted = LMNPCompta.format_date(entry.date.to_s)
            ecriture_num = entry.id

            total_debit = Montant.new("0")
            total_credit = Montant.new("0")

            entry.lines.each do |ligne|
                debit = ligne[:debit]
                credit = ligne[:credit]

                total_debit += debit
                total_credit += credit

                journal_lib = LMNPCompta::JOURNAUX[entry.journal] || "Journal #{entry.journal}"
                compte_lib = LMNPCompta.get_compte_lib(ligne[:compte])

                row = [
                    entry.journal,
                    journal_lib,
                    ecriture_num, date_formatted,
                    ligne[:compte], compte_lib, nil, nil,
                    entry.ref, date_formatted, entry.libelle,
                    debit, credit,
                    nil, nil, date_formatted, nil, nil
                ]
                csv << row
            end

            if total_debit != total_credit
                raise "ERREUR: Écriture #{entry.id} déséquilibrée."
            end
        end
    end
end
