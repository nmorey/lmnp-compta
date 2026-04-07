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

        # Vérifie si le journal a été clôturé
        def closed?
            @entries.any? { |e| e.ref.to_s.start_with?("CLOTURE") }
        end

        # Sauvegarde les entrées dans le fichier YAML
        def save!(force: false)
            if closed? && !force
                raise "ERREUR : Le journal est clôturé et ne peut plus être modifié."
            end
            # Sort by date
            sorted = @entries.sort_by { |e| e.id }
            FileUtils.mkdir_p(File.dirname(@file_path))
            File.write(@file_path, sorted.map(&:to_h).to_yaml)
        end

        # Ajoute une écriture au journal
        #
        # @param entry [Entry] L'écriture à ajouter
        # @param force [Boolean] Permet d'ignorer la vérification de clôture
        # @raise [RuntimeError] Si l'année ne correspond pas ou si la référence existe déjà
        def add_entry(entry, force: false)
            if closed? && !force
                raise "ERREUR : Le journal est clôturé et ne peut plus être modifié."
            end

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
        # @param force [Boolean] Permet d'ignorer la vérification de clôture
        def delete(id, force: false)
            if closed? && !force
                raise "ERREUR : Le journal est clôturé et ne peut plus être modifié."
            end
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

        def timestamp!(tsa_url: nil)
            require 'openssl'
            require 'net/http'
            require 'uri'
            require 'lmnp_compta/settings'

            tsa_url ||= LMNPCompta::Settings.instance.tsa_url
            uri = URI(tsa_url)

            return unless File.exist?(@file_path)

            file_data = File.read(@file_path)
            digest = OpenSSL::Digest.new('SHA256')
            hash = digest.digest(file_data)

            request = OpenSSL::Timestamp::Request.new
            request.version = 1
            request.algorithm = 'SHA256'
            request.message_imprint = hash
            request.nonce = OpenSSL::BN.rand(64)
            request.cert_requested = true

            req = Net::HTTP::Post.new(uri)
            req.content_type = "application/timestamp-query"
            req.body = request.to_der

            begin
                res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
                    http.request(req)
                end

                response = OpenSSL::Timestamp::Response.new(res.body)
                if response.status == 0
                    File.write("#{@file_path}.tsr", response.to_der)
                    puts "✅ Journal horodaté avec succès via RFC 3161."
                else
                    warn "⚠️  L'horodatage a échoué. Le serveur a répondu avec le statut : #{response.status}"
                end
            rescue => e
                warn "⚠️  Impossible d'horodater le journal (RFC 3161) : #{e.message}"
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
