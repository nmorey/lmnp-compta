module LMNPCompta
  module InvoiceParser
    class Impots < Base
      def self.parser_name; :impots; end
      def self.match?(content)
        content.match?(/Taxes foncières/i) || content.match?(/Taxe d'habitation/i)
      end

      def charge_account; "635000"; end

      def extract_ref
        if content.match(/Référence de l'avis\s*:\s*([\d\s]+)/i)
          $1.gsub(/\s/, '')
        elsif content.match(/\(C\)\s*:[^\n]*\n\s*([\d\s]+\d+)/i)
          $1.gsub(/\s/, '')
        else
          raise ParsingError, "Référence Avis Impôt introuvable"
        end
      end

      def extract_date
        if content.match(/Date d'établissement\s*:\s.*?(\d{2}\/\d{2}\/\d{4})/m)
          return parse_slash_date($1)
        end
        scan_first_valid_date
      end

      def extract_amount
        if cleaned_content.match(/Montant de vos taxes foncières\s*([\d\s.,]+)\s*€/i)
          clean_amount($1)
        elsif cleaned_content.match(/Montant de votre taxe d'habitation\s*([\d\s.,]+)\s*€?/i)
          clean_amount($1)
        else
          raise ParsingError, "Montant Impôt introuvable"
        end
      end

      def extract_label
        year = extract_date.year
        return "Taxe Foncière #{year}" if content.match?(/Taxes foncières/i)
        return "Taxe Habitation #{year}" if content.match?(/Taxe d'habitation/i)
        raise ParsingError, "Type d'impôt inconnu"
      end
    end
  end
end
