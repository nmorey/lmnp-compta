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
        def load!
            data = YAML.load_file(@file_path) || []
            @entries = data.map { |d| Entry.new(d) }
            check_duplicate_refs
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
