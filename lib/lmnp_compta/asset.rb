module LMNPCompta
    # Représente un bien immobilier amortissable
    class Asset
        attr_accessor :nom, :date_achat, :date_mise_en_location, :valeur_achat, :composants

        # Initialise un nouveau bien
        # @param attrs [Hash] Attributs du bien
        def initialize(attrs = {})
            @nom = attrs['nom'] || attrs[:nom]
            @date_achat = attrs['date_achat'] || attrs[:date_achat]
            @date_mise_en_location = attrs['date_mise_en_location'] || attrs[:date_mise_en_location]
            @valeur_achat = (attrs['valeur_achat'] || attrs[:valeur_achat] || 0.0).to_f
            @composants = (attrs['composants'] || attrs[:composants] || []).map do |c|
                c.is_a?(Component) ? c : Component.new(c)
            end
        end

        # Convertit l'objet en Hash pour la sérialisation
        # @return [Hash]
        def to_h
            {
                'nom' => @nom,
                'date_achat' => @date_achat,
                'date_mise_en_location' => @date_mise_en_location,
                'valeur_achat' => @valeur_achat,
                'composants' => @composants.map(&:to_h)
            }
        end

        # Représente un composant d'un bien immobilier (ex: Gros Oeuvre, Façade)
        class Component
            attr_accessor :nom, :valeur, :duree

            # Initialise un composant
            # @param attrs [Hash] Attributs du composant
            def initialize(attrs = {})
                @nom = attrs['nom'] || attrs[:nom]
                @valeur = (attrs['valeur'] || attrs[:valeur] || 0.0).to_f
                @duree = (attrs['duree'] || attrs[:duree] || 0).to_i
            end

            # Convertit le composant en Hash
            # @return [Hash]
            def to_h
                {
                    'nom' => @nom,
                    'valeur' => @valeur,
                    'duree' => @duree
                }
            end
        end
    end
end
