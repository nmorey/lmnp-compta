require 'yaml'
require 'date'
require 'fileutils'
require_relative 'entry'

module LMNPCompta
    # Gère le fichier journal (chargement, sauvegarde, ajout d'écritures)
    class Journal
        attr_reader :file_path, :entries, :year

        # Initialise un nouveau Journal
        #
        # @param file_path [String] Chemin vers le fichier YAML du journal
        # @param year [Integer, nil] Année fiscale attendue (optionnel)
        def initialize(file_path, year: nil)
            @file_path = file_path
            @year = year
            @entries = []
            load! if File.exist?(file_path)
        end

        # Charge les entrées depuis le fichier YAML
        # Vérifie l'unicité des références après chargement
        def load!(skip_integrity: false)
            data = YAML.load_file(@file_path) || []
            @entries = data.map { |d| Entry.new(d) }
            check_duplicate_refs
            verify_integrity! unless skip_integrity
        end

        # Sauvegarde les entrées dans le fichier YAML
        def save!
            # Sort by date
            sorted = @entries.sort_by { |e| e.id }
            FileUtils.mkdir_p(File.dirname(@file_path))
            File.write(@file_path, sorted.map(&:to_h).to_yaml)
        end

        # Ajoute une écriture au journal
        #
        # @param entry [Entry] L'écriture à ajouter
        # @raise [RuntimeError] Si l'année ne correspond pas ou si la référence existe déjà
        def add_entry(entry)
            entry.id = next_id if entry.id.nil?

            # Validation de la date
            entry_date = Date.parse(entry.date.to_s)
            if @year && entry_date.year != @year
                raise "Erreur de date : L'écriture du #{entry.date} ne correspond pas à l'année du journal #{@year}"
            end

            # Validation de l'équilibre
            unless entry.balanced?
                raise "Impossible d'ajouter une écriture déséquilibrée : #{entry.libelle} (Solde : #{entry.balance})"
            end

            # Validation de l'unicité de la référence
            if entry.ref && entry.ref != "N/A" && !entry.ref.empty?
                if @entries.any? { |e| e.ref == entry.ref }
                    raise "Erreur : La référence '#{entry.ref}' existe déjà dans le journal."
                end
            end

            # Inaltérabilité
            entry.created_at ||= Date.today.to_s

            # The hash generation must happen *after* pushing to @entries or we won't find it to index?
            # Wait, `generate_hash` uses `idx = @entries.index { |e| e.id == entry.id }` which might be nil.
            # If it's nil, it's just about to be added, so it gets the hash of `@entries.last`.
            entry.hash = generate_hash(entry)

            @entries << entry
        end

        # Calcule le prochain ID disponible
        # @return [Integer] Le prochain ID
        def next_id
            max_id = @entries.map { |e| e.id.to_i }.max || 0
            max_id + 1
        end

        # Trouve une écriture par son ID
        # @param id [Integer] L'ID de l'écriture
        # @return [Entry, nil] L'écriture trouvée
        def find(id)
            @entries.find { |e| e.id == id }
        end

        # Supprime une écriture par son ID
        # @param id [Integer] L'ID de l'écriture à supprimer
        def delete(id)
            @entries.reject! { |e| e.id == id }
        end

        def generate_hash(entry)
            require 'digest'
            # Find previous entry
            idx = @entries.index { |e| e.id == entry.id }
            prev_hash = ""
            if idx && idx > 0
                prev_hash = @entries[idx - 1].hash.to_s
            elsif idx.nil? && @entries.any?
                prev_hash = @entries.last.hash.to_s
            else
                # Very first entry: load previous year's journal if exists
                if @year
                    require 'lmnp_compta/settings'
                    prev_year = @year - 1
                    # Avoid instantiating Journal fully to prevent loops/integrity checks
                    prev_year_file = LMNPCompta::Settings.instance.journal_file(annee: prev_year)
                    if File.exist?(prev_year_file)
                        data = YAML.load_file(prev_year_file) || []
                        if data.any?
                            prev_hash = data.last['hash'].to_s
                        end
                    end
                end
            end

            data_str = [
                prev_hash,
                entry.id.to_s,
                entry.date.to_s,
                entry.created_at.to_s,
                entry.journal.to_s,
                entry.ref.to_s,
                entry.libelle.to_s,
                entry.lines.map { |l| "#{l[:compte]}:#{l[:debit]}:#{l[:credit]}:#{l[:libelle_ligne]}" }.join("|")
            ].join("||")

            ::Digest::SHA256.hexdigest(data_str)
        end

        def verify_integrity!
            return if @entries.empty?

            # On skip if the very first entry doesn't have a hash (meaning it's an old journal before migration)
            return if @entries.first.hash.nil?
            @entries.each do |entry|
                next if entry.hash.nil? # Tolerant for migration purposes, but full check happens if hashes are present
                expected_hash = generate_hash(entry)
                if entry.hash != expected_hash
                    raise "ERREUR CRITIQUE D'INTÉGRITÉ : Le journal a été altéré ! L'écriture #{entry.id} (#{entry.libelle}) est invalide."
                end
            end
        end

        private

        # Vérifie les doublons de référence dans le journal chargé
        def check_duplicate_refs
            refs = @entries.map(&:ref).compact.reject { |r| r == 'N/A' || r.to_s.strip.empty? }
            return if refs.uniq.length == refs.length

            duplicates = refs.tally.select { |_, v| v > 1 }.keys
            raise "Erreur : Références en double détectées dans le journal : #{duplicates.join(', ')}"
        end
    end
end
