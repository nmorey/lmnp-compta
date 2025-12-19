require 'lmnp_compta/command'
require 'lmnp_compta/journal'
require 'lmnp_compta/fec_generator'
require 'lmnp_compta/fiscal/opening_balance'
require 'lmnp_compta/entry'
require 'yaml'

module LMNPCompta
    module Commands
        class ExportFEC < Command
            register 'export-fec', 'Générer le fichier FEC (Fichier des Écritures Comptables)'

            def execute
                OptionParser.new do |opts|
                    opts.banner = "Usage: lmnp export-fec"
                end.parse!(@args)

                settings = Settings.instance
                siren = settings.siren
                annee = settings.annee
                journal_file = settings.journal_file
                immo_file = settings.immo_file

                output_file = "#{settings.data_dir}/#{annee}/#{siren}FEC#{annee}1231.txt"

                puts "Lecture du fichier #{journal_file}..."
                unless File.exist?(journal_file)
                    raise "Fichier source introuvable. Lancez d'abord la saisie."
                end

                journal = Journal.new(journal_file, year: annee)

                # --- Génération des A-Nouveaux ---
                puts "Calcul des A-Nouveaux (Ouverture)..."
                assets = Asset.load(immo_file)
                opening = Fiscal::OpeningBalance.new(assets, annee)

                an_entry = Entry.new(
                    id: 0,
                    date: "#{annee}-01-01",
                    journal: "AN",
                    libelle: "A-Nouveaux (Générés automatiquement)",
                    ref: "AN-#{annee}"
                )

                opening.fec_lines.each do |line|
                    if line[:debit] > Montant.new(0)
                        an_entry.add_debit(line[:compte], line[:debit], line[:libelle])
                    elsif line[:credit] > Montant.new(0)
                        an_entry.add_credit(line[:compte], line[:credit], line[:libelle])
                    end
                end

                all_entries = []
                # Ajouter les AN seulement s'ils ne sont pas vides
                all_entries << an_entry if an_entry.valid?
                all_entries += journal.entries

                puts "Génération du FEC..."

                begin
                    csv_content = FECGenerator.generate(all_entries)
                    File.write(output_file, csv_content)
                    puts "✅ Fichier FEC généré: #{output_file}"
                rescue => e
                    raise e.message
                end
            end
        end
    end
end
