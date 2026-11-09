module LMNPCompta
    # Représente un bien immobilier amortissable
    class Asset
        attr_accessor :nom, :date_achat, :date_mise_en_location, :valeur_achat, :composants,
                      :surface_totale, :surface_louee, :pleine_annee
        attr_writer :prorata_surface

        # Charge les biens immobiliers depuis un fichier YAML
        # @param file [String] Chemin vers le fichier YAML des immobilisations
        # @return [Array<Asset>] Liste des biens chargés
        def self.load(file)
            data = (File.exist?(file) ? YAML.load_file(file) : [])
            array = data || []
            array.map { |x| Asset.new(x) }
        end

        # Recherche un bien par son nom
        # @param name [String] Nom du bien recherché
        # @param file [String] Chemin vers le fichier YAML (utilise Settings par défaut)
        # @return [Asset, nil] Bien trouvé ou nil
        def self.find(name, file = Settings.instance.immo_file)
            assets = load(file)
            assets.find { |a| a.nom == name } ||
                assets.find { |a| a.nom.to_s.downcase == name.to_s.downcase }
        end

        # Initialise un nouveau bien
        # @param attrs [Hash] Attributs du bien
        def initialize(attrs = {})
            @nom = attrs['nom'] || attrs[:nom]
            @date_achat = attrs['date_achat'] || attrs[:date_achat]
            @date_mise_en_location = attrs['date_mise_en_location'] || attrs[:date_mise_en_location]
            @valeur_achat = (attrs['valeur_achat'] || attrs[:valeur_achat] || 0.0).to_f
            @surface_totale = (attrs['surface_totale'] || attrs[:surface_totale])&.to_f
            @surface_louee = (attrs['surface_louee'] || attrs[:surface_louee])&.to_f
            explicit_prorata = attrs['prorata_surface'] || attrs[:prorata_surface]
            @prorata_surface = explicit_prorata ? explicit_prorata.to_f : nil
            @pleine_annee = attrs['pleine_annee'] == true || attrs[:pleine_annee] == true
            @composants = (attrs['composants'] || attrs[:composants] || []).map do |c|
                c.is_a?(Component) ? c : Component.new(c)
            end
        end

        # Indique si le bien est considéré loué en pleine année
        # @return [Boolean]
        def pleine_annee?
            !!@pleine_annee
        end

        # Retourne le prorata de surface déductible
        # @return [Float, nil]
        def prorata_surface
            if @prorata_surface && @prorata_surface > 0
                return @prorata_surface > 1.0 ? @prorata_surface / 100.0 : @prorata_surface
            end
            if @surface_totale && @surface_louee && @surface_totale > 0
                return @surface_louee / @surface_totale
            end
            nil
        end

        # Convertit l'objet en Hash pour la sérialisation
        # @return [Hash]
        def to_h
            h = {
                'nom' => @nom,
                'date_achat' => @date_achat,
                'date_mise_en_location' => @date_mise_en_location,
                'valeur_achat' => @valeur_achat,
                'composants' => @composants.map(&:to_h)
            }
            h['surface_totale'] = @surface_totale if @surface_totale
            h['surface_louee'] = @surface_louee if @surface_louee
            h['prorata_surface'] = @prorata_surface if @prorata_surface
            h['pleine_annee'] = true if @pleine_annee
            h
        end

        # Représente un composant d'un bien immobilier (ex: Gros Oeuvre, Façade)
        class Component
            attr_accessor :nom, :valeur, :duree

            # Initialise un composant
            # @param attrs [Hash] Attributs du composant
            def initialize(attrs = {})
                @nom = attrs['nom'] || attrs[:nom]
                @valeur = Montant.new((attrs['valeur'] || attrs[:valeur] || 0.0))
                @duree = (attrs['duree'] || attrs[:duree] || 0).to_i
            end

            # Convertit le composant en Hash
            # @return [Hash]
            def to_h
                {
                    'nom' => @nom,
                    'valeur' => @valeur.to_s,
                    'duree' => @duree
                }
            end
        end
    end
end
