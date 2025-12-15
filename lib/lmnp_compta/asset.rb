module LMNPCompta
    class Asset
        attr_accessor :nom, :date_achat, :date_mise_en_location, :valeur_achat, :composants

        def initialize(attrs = {})
            @nom = attrs['nom'] || attrs[:nom]
            @date_achat = attrs['date_achat'] || attrs[:date_achat]
            @date_mise_en_location = attrs['date_mise_en_location'] || attrs[:date_mise_en_location]
            @valeur_achat = Montant.new(attrs['valeur_achat'] || attrs[:valeur_achat] || 0.0)
            @composants = (attrs['composants'] || attrs[:composants] || []).map do |c|
                c.is_a?(Component) ? c : Component.new(c)
            end
        end
        def to_h
            {
                'nom' => @nom,
                'date_achat' => @date_achat,
                'date_mise_en_location' => @date_mise_en_location,
                'valeur_achat' => @valeur_achat.to_s,
                'composants' => @composants.map(&:to_h)
            }
        end

        class Component
            attr_accessor :nom, :valeur, :duree

            def initialize(attrs = {})
                @nom = attrs['nom'] || attrs[:nom]
                @valeur = Montant.new(attrs['valeur'] || attrs[:valeur] || 0.0)
                @duree = (attrs['duree'] || attrs[:duree] || 0).to_i
            end

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
