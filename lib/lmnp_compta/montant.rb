require 'bigdecimal'

module LMNPCompta
  class Montant
    include Comparable

    attr_reader :cents

    # Constructeur universel
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

    def +(other)
      Montant.from_cents(@cents + Montant.new(other).cents)
    end

    def -(other)
      Montant.from_cents(@cents - Montant.new(other).cents)
    end

    def -@
      Montant.from_cents(-@cents)
    end

    def *(other)
      scalar = other.is_a?(Montant) ? other.to_f : other
      Montant.from_cents((@cents * scalar).round)
    end

    def /(other)
      scalar = other.is_a?(Montant) ? other.to_f : other
      raise ZeroDivisionError if scalar == 0
      Montant.from_cents((@cents / scalar).round)
    end

    # --- Méthodes requises pour votre script ---

    # Retourne la valeur absolue (en objet Montant)
    def abs
      Montant.from_cents(@cents.abs)
    end

    # Permet l'alignement du texte (ex: "   10.50")
    # Délègue simplement à la string formatée
    def rjust(len, padstr=' ')
      to_s.rjust(len, padstr)
    end
    
    def ljust(len, padstr=' ')
      to_s.ljust(len, padstr)
    end

    # Test si zéro
    def zero?
      @cents.zero?
    end

    # --- Comparaisons ---

    def <=>(other)
      return nil unless other.respond_to?(:to_f) || other.is_a?(Montant)
      other_cents = other.is_a?(Montant) ? other.cents : Montant.new(other).cents
      @cents <=> other_cents
    end

    # --- Coercition (Pour faire marcher [].sum sans erreur) ---
    
    # Permet à Ruby de faire : 0 + Montant
    def coerce(other)
      [Montant.new(other), self]
    end

    # --- Converters & Affichage ---

    def to_f
      @cents.to_f / 100
    end

    def to_s
      # Toujours 2 décimales, séparateur point
      format('%.2f', to_f)
    end
    
    # Pour l'affichage formaté français (optionnel, si besoin un jour)
    def to_s_fr
      format('%.2f', to_f).gsub('.', ',')
    end

    def inspect
      "#<LMNPCompta::Montant: #{to_s} €>"
    end

    # --- YAML ---
    
    def encode_with(coder)
      coder.scalar = to_s
    end

    # --- Interne ---
    
    def self.from_cents(cents)
      obj = allocate
      obj.instance_variable_set(:@cents, cents.to_i)
      obj
    end
  end
end
