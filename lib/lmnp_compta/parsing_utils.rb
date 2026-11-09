require 'date'
require_relative 'montant'

module LMNPCompta
    # Utilitaires de parsing pour les montants et dates dans divers formats.
    module ParsingUtils
        module_function

        # Parse une chaîne de montant au format français (ex. "1 050,50 EUR") en objet Montant.
        #
        # @param str [String, nil] Chaîne représentant le montant
        # @return [Montant] Montant parsé
        def parse_french_amount(str)
            return Montant.new(0) if str.nil? || str.empty?
            cleaned = str.gsub('EUR', '').gsub(/[[:space:]]/, '')
            cleaned = cleaned.gsub(',', '.') # French decimal separator
            Montant.new(cleaned)
        end

        # Nettoie une chaîne de montant pour le parsing, lève une exception si invalide.
        #
        # @param raw [String, nil] Chaîne brute représentant le montant
        # @return [String] Chaîne normalisée avec point décimal
        # @raise [ArgumentError] Si le montant est vide ou invalide
        def clean_amount(raw)
            raise ArgumentError, "Montant nul ou vide" if raw.nil? || raw.strip.empty?
            val = raw.gsub(/\s/, '').gsub(',', '.')
            raise ArgumentError, "Format de montant invalide : #{raw}" unless val.match?(/^\d+(\.\d+)?$/)
            val
        end

        # Parse une date au format américain MM/DD/YYYY (courant dans les exports Airbnb).
        #
        # @param str [String, nil] Chaîne représentant la date
        # @return [Date, nil] Date parsée ou nil si invalide
        def parse_us_date(str)
            return nil if str.nil? || str.empty?
            Date.strptime(str, "%m/%d/%Y")
        rescue Date::Error, TypeError
            nil
        end

        # Parse une date au format français (JJ/MM/AAAA ou JJ/MM/AA).
        #
        # @param str [String, nil] Chaîne représentant la date
        # @return [Date, nil] Date parsée ou nil si invalide
        def parse_french_date(str)
            return nil if str.nil? || str.empty?
            fmt = str.length > 8 ? "%d/%m/%Y" : "%d/%m/%y"
            Date.strptime(str, fmt)
        rescue Date::Error, TypeError
            nil
        end
    end
end
