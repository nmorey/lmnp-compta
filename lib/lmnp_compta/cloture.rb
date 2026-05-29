require 'yaml'
require 'date'
require 'lmnp_compta/montant'
require 'lmnp_compta/asset'
require 'lmnp_compta/amortization'
require 'lmnp_compta/trip'
require 'lmnp_compta/vehicle'
require 'lmnp_compta/settings'
require 'lmnp_compta/entry'

module LMNPCompta
    module Cloture
        def self.cloturer(journal, annee)
            step_amortissements(journal, annee)
            step_indemnites_km(journal, annee)
            step_solde_tresorerie(journal, annee)
        end

        def self.step_amortissements(journal, annee)
            puts "\n--- 1. Calcul des Amortissements ---"
            immo_file = Settings.instance.immo_file
            unless File.exist?(immo_file)
                puts "Aucun fichier d'immobilisations trouvé."
                return
            end

            assets_data = YAML.load_file(immo_file) || []
            assets = assets_data.map { |d| Asset.new(d) }

            total_dotation = Montant.new(0)
            lines = []

            assets.each do |asset|
                asset.composants.each do |component|
                    dotation = Amortization.calcul_dotation(
                        component.valeur, component.duree, asset.date_mise_en_location, annee
                    )

                    if dotation > Montant.new(0)
                        total_dotation += dotation
                        compte_amort = case component.nom.downcase
                                       when /mobilier/ then "281840"
                                       when /construction/, /gros oeuvre/, /façade/ then "281300"
                                       when /agencement/ then "281200"
                                       else "281840"
                                       end

                        lines << { compte: compte_amort, montant: dotation, libelle: "#{asset.nom} - #{component.nom}" }
                    end
                end
            end

            if total_dotation > Montant.new(0)
                ref = "DOTA#{annee}"
                if journal.entries.any? { |e| e.ref == ref }
                    puts "ℹ️  Écriture de dotation déjà présente (Ref: #{ref})."
                else
                    entry = Entry.new(
                        date: "#{annee}-12-31",
                        journal: "OD",
                        libelle: "Dotation aux amortissements #{annee}",
                        ref: ref
                    )
                    entry.add_debit("681100", total_dotation)
                    lines.each do |l|
                        entry.add_credit(l[:compte], l[:montant], l[:libelle])
                    end
                    journal.add_entry(entry)
                    journal.save!
                    puts "✅ Écriture de dotation générée : #{total_dotation} €"
                end
            else
                puts "Aucun amortissement à passer pour cette année."
            end
        end

        def self.step_indemnites_km(journal, annee)
            puts "\n--- 2. Calcul des Indemnités Kilométriques ---"
            trips = Trip.load_all(annee)
            if trips.empty?
                puts "Aucun trajet enregistré."
                return
            end

            by_vehicle = trips.group_by(&:vehicle_name)
            by_vehicle.each do |v_name, v_trips|
                vehicle = Vehicle.find(v_name)
                unless vehicle
                    puts "⚠️  Véhicule '#{v_name}' introuvable dans la configuration."
                    next
                end

                total_dist = v_trips.sum(&:distance_km)

                begin
                    require "lmnp_compta/fiscal/year_#{annee}"
                    fiscal_class = Object.const_get("LMNPCompta::Fiscal::Year#{annee}")
                    if fiscal_class.respond_to?(:calculate_mileage_allowance)
                        montant = fiscal_class.calculate_mileage_allowance(vehicle.fiscal_power, total_dist)
                    else
                        puts "⚠️  Calcul IK non supporté par le module fiscal #{annee}."
                        next
                    end
                rescue LoadError, NameError
                    puts "⚠️  Module fiscal #{annee} introuvable."
                    next
                end

                ref = "IK#{annee}-#{v_name.gsub(/[^a-zA-Z0-9]/, '')}"
                if journal.entries.any? { |e| e.ref == ref }
                    puts "ℹ️  Écriture IK '#{v_name}' déjà présente."
                    next
                end

                entry = Entry.new(
                    date: "#{annee}-12-31",
                    journal: "OD",
                    libelle: "Indemnités Km (#{v_name}: #{total_dist} km @ #{vehicle.fiscal_power} CV)",
                    ref: ref
                )
                entry.add_debit("625100", montant)
                entry.add_credit("108000", montant)
                journal.add_entry(entry)
                puts "✅ Ajout IK pour #{v_name} : #{total_dist} km -> #{montant} €"
            end
            journal.save!
        end

        def self.step_solde_tresorerie(journal, annee)
            puts "\n--- 3. Solde de Trésorerie ---"
            compte_banque = "512000"
            compte_exploitant = "108000"

            solde = Montant.new(0)
            journal.entries.each do |e|
                e.lines.each do |l|
                    if l[:compte].to_s == compte_banque
                        solde += (l[:debit] - l[:credit])
                    end
                end
            end

            puts "Solde actuel #{compte_banque} : #{solde} €"

            if solde.abs < Montant.new(0.01)
                puts "✅ Compte soldé."
                return
            end

            ref = "CLOTURE#{annee}"
            if journal.entries.any? { |e| e.ref == ref }
                puts "ℹ️  Écriture de clôture déjà présente."
                return
            end

            entry = Entry.new(
                date: "#{annee}-12-31",
                journal: "OD",
                libelle: "Virement solde trésorerie (Clôture)",
                ref: ref
            )

            mnt = solde.abs
            if solde > Montant.new(0)
                puts "👉 Virement du surplus vers compte personnel."
                entry.add_debit(compte_exploitant, mnt)
                entry.add_credit(compte_banque, mnt)
            else
                puts "👉 Constatation apport personnel."
                entry.add_debit(compte_banque, mnt)
                entry.add_credit(compte_exploitant, mnt)
            end

            journal.add_entry(entry, force: true)
            journal.save!(force: true)
            puts "✅ Écriture de solde générée."
        end
    end
end
