require 'date'
require_relative 'montant'

module LMNPCompta
    module ParsingUtils
        module_function

        # Parse a French amount string (e.g., "1 050,50 EUR") into a Montant object
        def parse_french_amount(str)
            return Montant.new(0) if str.nil? || str.empty?
            cleaned = str.gsub('EUR', '').gsub(/[[:space:]]/, '')
            cleaned = cleaned.gsub(',', '.') # French decimal separator
            Montant.new(cleaned)
        end

        # Clean an amount string for basic parsing, raising error if invalid
        def clean_amount(raw)
            raise ArgumentError, "Montant nul ou vide" if raw.nil? || raw.strip.empty?
            val = raw.gsub(/\s/, '').gsub(',', '.')
            raise ArgumentError, "Format de montant invalide : #{raw}" unless val.match?(/^\d+(\.\d+)?$/)
            val
        end

        # Parse a date string in MM/DD/YYYY format (common in exports like Airbnb)
        def parse_us_date(str)
            return nil if str.nil? || str.empty?
            Date.strptime(str, "%m/%d/%Y")
        rescue Date::Error, TypeError
            nil
        end

        # Parse a standard French date (DD/MM/YYYY)
        def parse_french_date(str)
            return nil if str.nil? || str.empty?
            fmt = str.length > 8 ? "%d/%m/%Y" : "%d/%m/%y"
            Date.strptime(str, fmt)
        rescue Date::Error, TypeError
            nil
        end
    end
end
