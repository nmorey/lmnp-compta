require 'lmnp_compta/command'
require 'lmnp_compta/journal'
require 'lmnp_compta/entry'
require 'lmnp_compta/trip'
require 'lmnp_compta/vehicle'

module LMNPCompta
    module Commands
        class CloseYear < Command
            register 'cloturer', 'Générer l\'écriture de clôture de trésorerie'

            COMPTE_BANQUE = "512000"
            COMPTE_EXPLOITANT = "108000"
            COMPTE_VOYAGES = "625100"

            def execute
                OptionParser.new do |opts|
                    opts.banner = "Usage: lmnp cloturer"
                end.parse!(@args)

                settings = Settings.instance
                journal_file = settings.journal_file
                annee = settings.annee

                journal = Journal.new(journal_file, year: annee)

                puts "==========================================================="
                puts "       CLÔTURE ANNUELLE (Année #{annee})"
                puts "==========================================================="

                calculate_mileage_allowances(journal, annee)

                puts "--- Vérification Trésorerie ---"

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

                new_entry = Entry.new(
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

            private

            def calculate_mileage_allowances(journal, annee)
                puts "--- Calcul des Indemnités Kilométriques ---"

                trips = Trip.load_all(annee)
                if trips.empty?
                    puts "Aucun trajet trouvé pour #{annee}."
                    return
                end

                # Group by vehicle name
                by_vehicle = trips.group_by(&:vehicle_name)

                by_vehicle.each do |v_name, v_trips|
                    vehicle = Vehicle.find(v_name)
                    unless vehicle
                        puts "⚠️  Attention: Le véhicule '#{v_name}' est utilisé dans les trajets mais n'est pas défini dans le stock de véhicules."
                        puts "   Calcul impossible pour ces trajets."
                        next
                    end

                    total_dist = v_trips.sum(&:distance_km)

                    # Dynamic Fiscal Year loading
                    begin
                        require "lmnp_compta/fiscal/year_#{annee}"
                        fiscal_class_name = "LMNPCompta::Fiscal::Year#{annee}"
                        fiscal_class = Object.const_get(fiscal_class_name)

                        if fiscal_class.respond_to?(:calculate_mileage_allowance)
                             montant = fiscal_class.calculate_mileage_allowance(vehicle.fiscal_power, total_dist)
                        else
                             puts "⚠️  Attention: Le module fiscal pour #{annee} ne supporte pas le calcul automatique des IK."
                             next
                        end
                    rescue LoadError, NameError
                        puts "⚠️  Attention: Impossible de charger le module fiscal pour l'année #{annee}. Calcul IK impossible."
                        next
                    end

                    ref = "IK#{annee}-#{v_name.gsub(/[^a-zA-Z0-9]/, '')}"

                    # Check existence
                    if journal.entries.any? { |e| e.ref == ref }
                        puts "ℹ️  L'écriture pour '#{v_name}' existe déjà (Ref: #{ref}). Ignorée."
                        next
                    end

                    entry = Entry.new(
                        date: "#{annee}-12-31",
                        journal: "OD",
                        libelle: "Indemnités Km (#{v_name}: #{total_dist} km @ #{vehicle.fiscal_power} CV)",
                        ref: ref
                    )

                    entry.add_debit(COMPTE_VOYAGES, montant)
                    entry.add_credit(COMPTE_EXPLOITANT, montant)

                    journal.add_entry(entry)
                    puts "✅ Ajout IK pour #{v_name} : #{total_dist} km -> #{montant} €"
                end
                journal.save!
                puts "Mise à jour du journal effectuée."
                puts ""
            end
        end
    end
end
