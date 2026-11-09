require 'bigdecimal'

module LMNPCompta
    # Gestion précise des montants monétaires pour éviter les erreurs de virgule flottante
    class Montant
        include Comparable

        attr_reader :cents

        # Constructeur universel
        # @param value [Integer, Float, BigDecimal, String, Montant, NilClass] La valeur à convertir
        def initialize(value = 0)
            @cents = case value
                     when Montant
                         value.cents
                     when Integer
                         # Par défaut, un entier est considéré comme des Euros
                         # Montant.new(10) => 10.00 €
                         value * 100
                     when Float, BigDecimal, Rational
                         (value * 100).round
                     when String
                         # Nettoyage : "1 050,50" -> "1050.50"
                         clean_str = value.to_s.gsub(',', '.').gsub(/[^\d\.-]/, '')
                         return 0 if clean_str.empty?
                         (BigDecimal(clean_str) * 100).round
                     when NilClass
                         0
                     else
                         raise ArgumentError, "Type non supporté pour Montant: #{value.class}"
                     end
        end

        # --- Arithmétique ---

        # Additionne un montant ou une valeur numérique
        # @param other [Montant, Numeric] Montant ou nombre à ajouter
        # @return [Montant] Résultat de l'addition
        def +(other)
            Montant.from_cents(@cents + Montant.new(other).cents)
        end

        # Soustrait un montant ou une valeur numérique
        # @param other [Montant, Numeric] Montant ou nombre à soustraire
        # @return [Montant] Résultat de la soustraction
        def -(other)
            Montant.from_cents(@cents - Montant.new(other).cents)
        end

        # Négation unaire du montant
        # @return [Montant] Montant opposé (-self)
        def -@
            Montant.from_cents(-@cents)
        end

        # Multiplie le montant par un scalaire
        # @param other [Numeric, Montant] Multiplicateur
        # @return [Montant] Résultat de la multiplication
        def *(other)
            scalar = other.is_a?(Montant) ? other.to_f : other
            Montant.from_cents((@cents * scalar).round)
        end

        # Divise le montant par un scalaire
        # @param other [Numeric, Montant] Diviseur
        # @return [Montant] Résultat de la division
        # @raise [ZeroDivisionError] Si division par zéro
        def /(other) # /
            scalar = other.is_a?(Montant) ? other.to_f : other
            raise ZeroDivisionError if scalar == 0
            Montant.from_cents((@cents / scalar).round)
        end

        # --- Méthodes utilitaires ---

        # Retourne la valeur absolue (en objet Montant)
        # @return [Montant] Valeur absolue
        def abs
            Montant.from_cents(@cents.abs)
        end

        # Permet l'alignement à droite du texte (ex: "   10.50")
        # @param len [Integer] Longueur minimale
        # @param padstr [String] Chaîne de remplissage
        # @return [String] Chaîne alignée à droite
        def rjust(len, padstr=' ')
            to_s.rjust(len, padstr)
        end

        # Permet l'alignement à gauche du texte
        # @param len [Integer] Longueur minimale
        # @param padstr [String] Chaîne de remplissage
        # @return [String] Chaîne alignée à gauche
        def ljust(len, padstr=' ')
            to_s.ljust(len, padstr)
        end

        # Test si le montant est nul
        # @return [Boolean] true si zéro
        def zero?
            @cents.zero?
        end

        # --- Comparaisons ---

        # Compare le montant avec un autre montant ou valeur numérique
        # @param other [Object] Objet à comparer
        # @return [Integer, nil] -1, 0, 1 ou nil
        def <=>(other)
            return nil unless other.respond_to?(:to_f) || other.is_a?(Montant)
            other_cents = other.is_a?(Montant) ? other.cents : Montant.new(other).cents
            @cents <=> other_cents
        end

        # --- Coercition ---

        # Permet l'interopérabilité arithmétique avec les types numériques natifs
        # @param other [Numeric] Autre valeur
        # @return [Array(Montant, Montant)]
        def coerce(other)
            [Montant.new(other), self]
        end

        # --- Converters & Affichage ---

        # Convertit le montant en Float
        # @return [Float] Montant en euros
        def to_f
            @cents.to_f / 100
        end

        # Représentation textuelle du montant avec 2 décimales et virgule
        # @return [String]
        def to_s
            # Toujours 2 décimales, séparateur virgule
            format('%.2f', to_f).gsub('.', ',')
        end

        # Représentation d'inspection pour le débogage
        # @return [String]
        def inspect
            "#<Montant: #{to_s} €>"
        end

        # --- YAML ---

        # Méthode de sérialisation YAML
        # @param coder [Psych::Coder] Codeur YAML
        # @return [void]
        def encode_with(coder)
            coder.scalar = to_s
        end

        # --- Interne ---

        # Crée un Montant directement depuis un nombre de centimes
        # @param cents [Integer] Nombre de centimes
        # @return [Montant]
        def self.from_cents(cents)
            obj = allocate
            obj.instance_variable_set(:@cents, cents.to_i)
            obj
        end

        # Arrondit le montant à l'euro le plus proche
        # @return [RoundedMontant]
        def round
            RoundedMontant.new((to_f).round)
        end
    end

    # Représente un montant monétaire arrondi à l'euro entier
    class RoundedMontant
        include Comparable
        attr_reader :value

        # Initialise un nouveau montant arrondi
        # @param value [Integer, Numeric] Valeur entière en euros
        def initialize(value)
            @value = value.to_i
        end

        # Additionne deux montants arrondis
        # @param other [RoundedMontant] Montant à ajouter
        # @return [RoundedMontant]
        def +(other)
            check_type(other)
            RoundedMontant.new(@value + other.value)
        end

        # Soustrait deux montants arrondis
        # @param other [RoundedMontant] Montant à soustraire
        # @return [RoundedMontant]
        def -(other)
            check_type(other)
            RoundedMontant.new(@value - other.value)
        end

        # Négation unaire du montant arrondi
        # @return [RoundedMontant]
        def -@
            RoundedMontant.new(-@value)
        end

        # Compare deux montants arrondis
        # @param other [Object] Objet à comparer
        # @return [Integer, nil]
        def <=>(other)
            return nil unless other.is_a?(RoundedMontant)
            @value <=> other.value
        end

        # Test si le montant est nul
        # @return [Boolean]
        def zero?
            @value.zero?
        end

        # Valeur absolue du montant arrondi
        # @return [RoundedMontant]
        def abs
            RoundedMontant.new(@value.abs)
        end

        # Représentation textuelle entière
        # @return [String]
        def to_s
            @value.to_s
        end

        # Alignement à droite du texte
        # @param len [Integer] Longueur minimale
        # @param padstr [String] Caractère de remplissage
        # @return [String]
        def rjust(len, padstr=' ')
            to_s.rjust(len, padstr)
        end

        private

        # Valide le type de l'opérande pour les opérations arithmétiques
        # @param other [Object] Opérande à vérifier
        # @raise [ArgumentError] Si l'opérande n'est pas un RoundedMontant
        # @return [void]
        def check_type(other)
            if other.is_a?(Montant)
                raise ArgumentError, "Cannot mix RoundedMontant and Montant. Round the Montant first."
            end
            unless other.is_a?(RoundedMontant)
                raise ArgumentError, "Expected RoundedMontant, got #{other.class}"
            end
        end
    end
end
