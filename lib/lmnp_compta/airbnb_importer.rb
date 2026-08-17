require 'csv'
require 'date'
require_relative 'entry'
require_relative 'parsing_utils'
require_relative 'plan_comptable'

module LMNPCompta
    # Importateur pour les fichiers CSV d'export Airbnb
    class AirbnbImporter
        SUPPORTED_TYPES = {
            'Réservation' => :create_booking_entry,
            'Versement de résolution' => :create_resolution_entry
        }

        attr_reader :new_entries

        # @param file_path [String] Chemin vers le fichier CSV
        # @param journal [Journal] Instance du journal pour vérifier les doublons
        # @param blanchisserie_configs [Array<String>] Liste des ID ou Noms des configs blanchisserie
        def initialize(file_path, journal, blanchisserie_configs: nil)
            @file_path = file_path
            @journal = journal
            @new_entries = []
            @blanchisseries = []
            require_relative 'journals'
            @journals = LMNPCompta::Journals.new

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

        def parse_csv
            reservations_map = Hash.new { |h, k| h[k] = [] }
            current_payout_date = nil

            CSV.foreach(@file_path, headers: true) do |row|
                type = row['Type']

                if type == 'Payout'
                    current_payout_date = parse_date(row['Date'])
                    next
                end

                if SUPPORTED_TYPES.key?(type)
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

        def parse_date(str)
            ParsingUtils.parse_us_date(str)
        end

        # Retrouve toutes les écritures existantes pour un code et un type de réservation donnés
        # à travers les écritures de cet import, le journal en cours et les autres exercices fiscaux.
        #
        # @param code [String] Code de confirmation de la réservation
        # @param type [String] Type d'opération (Réservation ou Versement de résolution)
        # @return [Array<Entry>] Les écritures existantes trouvées
        def find_existing_entries(code, type)
            pattern = if type == 'Versement de résolution'
                /^#{Regexp.escape(code)}-RES-\d+$/
            else
                /^#{Regexp.escape(code)}-\d+$/
            end

            # 1. Écritures déjà générées durant cet import
            found = @new_entries.select { |e| e.ref =~ pattern }

            # 2. Écritures déjà enregistrées dans le journal de l'exercice en cours
            found += @journal.select { |e| e.ref.to_s =~ pattern }

            # 3. Écritures enregistrées dans les autres exercices fiscaux (en évitant les doublons)
            found += @journals.select { |e| e.ref.to_s =~ pattern }.reject { |e| @journal.year && Date.parse(e.date).year == @journal.year }

            found.uniq(&:ref)
        end

        # Calcule le prochain index de séquence disponible pour une réservation
        # en inspectant les écritures existantes.
        #
        # @param existing_entries [Array<Entry>] Liste des écritures existantes
        # @return [Integer] Le prochain index (ex: 2 si REF-01 existe déjà)
        def next_available_index(existing_entries)
            return 1 if existing_entries.empty?

            max_index = existing_entries.map do |e|
                e.ref.split('-').last.to_i
            end.max

            max_index + 1
        end

        # Génère une écriture pour une ligne unique du CSV de manière isolée
        #
        # @param row [CSV::Row] La ligne du CSV
        # @param date_comptable [Date] La date comptable associée (tenant compte du Payout contextuel)
        # @param full_ref [String] La référence calculée
        # @return [Entry] L'écriture générée
        def entry_for_row(row, date_comptable, full_ref)
            start_period = parse_date(row['Date'])
            res_end_date_str = row['Date de fin'] || row['Date de départ'] || row[6]
            res_end_date = parse_date(res_end_date_str)

            start_str = start_period ? start_period.strftime("%d/%m") : "??"
            end_str = res_end_date ? res_end_date.strftime("%d/%m") : "??"

            create_entry(full_ref, date_comptable, row, start_str, end_str)
        end

        private

        def generate_entries(reservations_map)
            reservations_map.each do |code, items|
                items.sort_by! { |item| item[:date_comptable] }

                first_row = items.first[:csv_data]
                res_end_date_str = first_row['Date de départ'] || first_row[6]
                res_end_date = parse_date(res_end_date_str)

                # Keep track of matched entries in the current CSV import loop
                matched_existing_entries = []

                items.each_with_index do |item, index|
                    date_virement = item[:date_comptable]
                    row = item[:csv_data]
                    type = row['Type']

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

                    # 1. Retrieve all existing entries for this reservation across all years and new entries
                    existing_entries = find_existing_entries(code, type)

                    # 2. Build candidate entry to match dates and amounts
                    candidate_entry = create_entry("#{code}-TEMP", date_virement, row, start_str, end_str)

                    # 3. Check if there is an unmatched existing entry that matches our candidate
                    existing_match = existing_entries.find do |existing|
                        !matched_existing_entries.include?(existing) && entries_match?(existing, candidate_entry)
                    end

                    if existing_match
                        matched_existing_entries << existing_match
                        puts "⚠️  Transaction déjà présente : #{existing_match.ref} (Ignorée)"
                    else
                        # It is a new payment, allocate the next sequence index
                        idx = next_available_index(existing_entries)
                        suffix = (type == 'Versement de résolution') ? "-RES-#{idx.to_s.rjust(2, '0')}" : "-#{idx.to_s.rjust(2, '0')}"
                        full_ref = "#{code}#{suffix}"

                        # Create the actual entry with the correct unique reference
                        entry = create_entry(full_ref, date_virement, row, start_str, end_str)
                        @new_entries << entry
                    end

                    if index == items.length - 1 && @blanchisseries.any?
                        hebergement = row['Logement'] || row['Hébergement'] || row[6]
                        laundry = @blanchisseries.find { |l| l.nom_bien == hebergement }
                        if laundry
                            add_laundry_entry(laundry, code, res_end_date)
                        end
                    end
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
            @new_entries.find { |e| e.ref == ref } ||
            @journal.select { |e| e.ref == ref }.first ||
            @journals.select { |e| e.ref == ref }.first
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
            creator_method = SUPPORTED_TYPES[row['Type']]
            if creator_method
                send(creator_method, code, date_virement, row, start_str, end_str)
            else
                raise "Type d'écriture non supporté : #{row['Type']}"
            end
        end

        def create_booking_entry(code, date_virement, row, start_str, end_str)
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

        def create_resolution_entry(code, date_virement, row, start_str, end_str)
            details = row['Détails'] || "Résolution du dossier"
            libelle = "Airbnb - Résolution #{code} (#{details})"

            revenu_brut = ParsingUtils.parse_french_amount(row['Revenus bruts'] || row['Montant'])
            frais_service = ParsingUtils.parse_french_amount(row['Frais de service'])
            net_banque = revenu_brut - frais_service

            entry = Entry.new(
                date: date_virement.to_s,
                journal: "VT",
                libelle: libelle,
                ref: code,
                file: File.basename(@file_path)
            )

            entry.add_credit(LMNPCompta::COMPTE["Produits divers de gestion courante"], revenu_brut, "Dédommagement")

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
