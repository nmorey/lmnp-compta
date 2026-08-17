require_relative 'journal'
require_relative 'settings'

module LMNPCompta
    # Collection de l'ensemble des journaux d'écritures de tous les exercices fiscaux.
    class Journals
        # Initialise la collection de journaux en scannant le dossier de données.
        #
        # @param data_dir [String, nil] Dossier de données (par défaut Settings.instance.data_dir)
        def initialize(data_dir = nil)
            @data_dir = data_dir || LMNPCompta::Settings.instance.data_dir
            @journals = {}
            load_all_journals
        end

        # Renvoie tous les journaux chargés sous forme de tableau.
        #
        # @return [Array<Journal>] Liste des instances de Journal
        def all
            @journals.values
        end

        # Récupère le journal d'une année spécifique.
        #
        # @param year [Integer] L'année recherchée (ex: 2025)
        # @return [Journal, nil] Le journal correspondant ou nil s'il n'existe pas
        def find_by_year(year)
            @journals[year]
        end

        # Agrége et renvoie l'ensemble des écritures de tous les journaux chargés sous forme de tableau plat.
        # Note : des écritures provenant de différents exercices fiscaux peuvent partager le même ID
        # car la numérotation des écritures recommence généralement à 1 à chaque nouvel exercice.
        #
        # @return [Array<Entry>] Tableau plat de toutes les écritures de tous les journaux
        def entries
            @journals.values.flat_map(&:entries)
        end

        # Recherche une écriture par son ID au sein d'un exercice fiscal spécifique.
        #
        # @param year [Integer] L'année de l'exercice fiscal
        # @param id [Integer] L'ID de l'écriture
        # @return [Entry, nil] L'écriture trouvée ou nil
        def find(year, id)
            j = find_by_year(year)
            j ? j.find(id) : nil
        end

        # Lance la vérification d'intégrité cryptographique sur l'ensemble des journaux chargés.
        #
        # @raise [RuntimeError] Si une altération d'intégrité est détectée dans l'un des journaux
        # @return [void]
        def verify_integrity!
            @journals.values.each(&:verify_integrity!)
        end

        # Vérifie les doublons de référence à travers tous les journaux chargés.
        # Les références 'N/A', vides ou absentes sont ignorées.
        #
        # @raise [RuntimeError] Si une référence en double est détectée entre ou au sein des journaux
        # @return [void]
        def check_duplicate_refs
            refs = entries.map(&:ref).compact.reject { |r| r == 'N/A' || r.to_s.strip.empty? }
            return if refs.uniq.length == refs.length

            duplicates = refs.tally.select { |_, v| v > 1 }.keys
            raise "Erreur : Références en double détectées sur l'ensemble des journaux : #{duplicates.join(', ')}"
        end

        private

        # Scanne le dossier de données et charge les fichiers journaux existants
        # pour chaque sous-dossier correspondant à une année à 4 chiffres.
        # Les journaux sont chargés en mode mémoire seule (lecture seule).
        #
        # @return [void]
        def load_all_journals
            return unless File.directory?(@data_dir)

            Dir.glob(File.join(@data_dir, '[0-9]' * 4)).each do |year_dir|
                year = File.basename(year_dir).to_i
                journal_file = LMNPCompta::Settings.instance.journal_file(annee: year)
                if File.exist?(journal_file)
                    @journals[year] = LMNPCompta::Journal.new(journal_file, year: year, in_mem: true)
                end
            end
        end
    end
end
