require 'csv'
require 'date'
require_relative 'entry'
require_relative 'parsing_utils'
require_relative 'plan_comptable'

module LMNPCompta
    # Importateur pour les fichiers CSV d'export Airbnb
    class AirbnbImporter
        attr_reader :new_entries

        # @param file_path [String] Chemin vers le fichier CSV
        # @param journal [Journal] Instance du journal pour vérifier les doublons
        # @param blanchisserie_configs [Array<String>] Liste des ID ou Noms des configs blanchisserie
        def initialize(file_path, journal, blanchisserie_configs: nil)
            @file_path = file_path
            @journal = journal
            @new_entries = []
            @blanchisseries = []

            if blanchisserie_configs
                require_relative 'laundry'
                blanchisserie_configs.each do |config_id|
                    begin
                        l = LMNPCompta::Laundry.find(config_id)
                        if l
                            @blanchisseries << l
                        else
                            puts "⚠️  Configuration blanchisserie introuvable pour : #{config_id}"
                        end
                    rescue => e
                        puts "⚠️  Erreur lors du chargement de blanchisserie : #{e.message}"
                    end
                end
            end
        end

        # Exécute l'importation
        # @return [Array<Entry>] La liste des nouvelles écritures générées
        def import
            reservations_map = parse_csv
            generate_entries(reservations_map)
            @new_entries.sort_by! { |e| Date.parse(e.date) }
            @new_entries
        end

        private

        def parse_csv
            reservations_map = Hash.new { |h, k| h[k] = [] }
            current_payout_date = nil

            CSV.foreach(@file_path, headers: true) do |row|
                type = row['Type']

                if type == 'Payout'
                    current_payout_date = parse_date(row['Date'])
                    next
                end

                if type == 'Réservation'
                    code = row['Code de confirmation']
                    date_comptable = current_payout_date || parse_date(row['Date'])

                    reservations_map[code] << {
                        date_comptable: date_comptable,
                        csv_data: row
                    }
                    current_payout_date = nil
                end
            end
            reservations_map
        end

        def generate_entries(reservations_map)
            reservations_map.each do |code, items|
                items.sort_by! { |item| item[:date_comptable] }

                first_row = items.first[:csv_data]
                res_end_date_str = first_row['Date de départ'] || first_row[6]
                res_end_date = parse_date(res_end_date_str)
                counter=1
                items.each_with_index do |item, index|
                    date_virement = item[:date_comptable]
                    row = item[:csv_data]

                    start_period = parse_date(row['Date'])
                    if index < items.length - 1
                        next_payment_date = parse_date(items[index + 1][:csv_data]['Date'])
                        end_period = next_payment_date - 1
                    else
                        end_period = res_end_date
                    end

                    start_str = start_period ? start_period.strftime("%d/%m") : "??"
                    end_str   = end_period ? end_period.strftime("%d/%m") : "??"

                    # Vérification de l'année
                    if @journal.year && date_virement.year != @journal.year
                        puts "⚠️  Ignorée : Entrée Airbnb du #{date_virement} (Année #{date_virement.year} != #{@journal.year})"
                        next
                    end

                    full_ref = "#{code}-#{counter.to_s.rjust(2, '0')}"
                    entry = create_entry(full_ref, date_virement, row, start_str, end_str)

                    if (existing = find_duplicate(full_ref))
                        if entries_match?(existing, entry)
                            puts "⚠️  Transaction déjà présente : #{full_ref} (Ignorée)"
                        else
                            raise "Erreur conflit : La transaction #{full_ref} existe déjà mais diffère (Date: #{existing.date} vs #{entry.date}, Montant: #{existing.lines.first[:credit]} vs #{entry.lines.first[:credit]})"
                        end
                    else
                        @new_entries << entry
                    end
                    if index == items.length - 1 && @blanchisseries.any?
                        hebergement = row['Logement'] || row['Hébergement'] || row[6]
                        laundry = @blanchisseries.find { |l| l.nom_bien == hebergement }
                        if laundry
                            add_laundry_entry(laundry, code, res_end_date)
                        end
                    end

                    counter+=1
                end
            end
        end

        def add_laundry_entry(laundry, res_code, date)
            ref = "LNDRY-#{res_code}"

            # Use @journal because the entry might be saved already during previous runs,
            # but also check @new_entries in case it's added in this run (should be 1 max per res_code).
            existing = find_duplicate(ref)
            if existing
                 puts "⚠️  Frais de blanchisserie déjà présents : #{ref} (Ignoré)"
                 return
            end

            puts "Ajout blanchisserie pour réservation #{res_code}"
            cost = LMNPCompta::Montant.new(laundry.cost_per_wash)

            entry = LMNPCompta::Entry.new(
                date: date.to_s,
                journal: "OD",
                libelle: "Blanchisserie - #{laundry.nom_bien}",
                ref: ref,
                file: File.basename(@file_path)
            )

            entry.add_debit(LMNPCompta::COMPTE["Entretien et réparations"], cost, "Frais de blanchisserie")
            entry.add_credit(LMNPCompta::COMPTE["Compte de l'exploitant"], cost, "Frais avancés")

            @new_entries << entry
        end

        def find_duplicate(ref)
            @journal.entries.find { |e| e.ref == ref } ||
            @new_entries.find { |e| e.ref == ref }
        end

        def entries_match?(existing, new_entry)
            # Compare Date
            return false unless existing.date.to_s == new_entry.date.to_s

            # Compare Amounts (Total Credit of first line usually holds the gross revenue)
            # Or better, compare equality of amounts in lines.
            # Simplified: Check if total debit and total credit match
            return false unless existing.total_debit == new_entry.total_debit
            return false unless existing.total_credit == new_entry.total_credit

            true
        end

        def create_entry(code, date_virement, row, start_str, end_str)
            libelle = "Airbnb - #{code} (Période #{start_str} - #{end_str})"
            revenu_brut = ParsingUtils.parse_french_amount(row['Revenus bruts'])
            frais_service = ParsingUtils.parse_french_amount(row['Frais de service'])
            net_banque = revenu_brut - frais_service

            entry = Entry.new(
                date: date_virement.to_s,
                journal: "VT",
                libelle: libelle,
                ref: code,
                file: File.basename(@file_path)
            )

            entry.add_credit(LMNPCompta::COMPTE["Prestations de services (Loyers)"], revenu_brut, "Revenu Brut")

            if frais_service > Montant.new(0)
                entry.add_debit(LMNPCompta::COMPTE["Honoraires (Comptable, CGA, Agence)"], frais_service, "Commissions Airbnb")
            end

            if net_banque > Montant.new(0)
                entry.add_debit(LMNPCompta::COMPTE["Banque"], net_banque, "Virement Net")
            end

            entry
        end



        def parse_date(str)
            ParsingUtils.parse_us_date(str)
        end
    end
end
