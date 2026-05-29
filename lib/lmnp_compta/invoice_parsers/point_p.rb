module LMNPCompta
  module InvoiceParser
    class PointP < Base
      def self.parser_name; :point_p; end
      def self.match?(content)
        content.match?(/POINT\.P/i)
      end

      def extract_date
        if content.match(/(\d{1,2}\s+[a-zéû]+\s+\d{4})/i)
          return parse_french_date_text($1)
        end
        scan_first_valid_date
      end

      def extract_amount
        if content.match(/Total TTC\s*:\s*([\d,]+)\s*€/i)
          return clean_amount($1)
        end
        raise ParsingError, "Montant non trouvé (Point.P)"
      end

      def extract_internal_ref
        if content.match(/Facture N°\s*(\d+)/i)
          return $1
        end
        raise ParsingError, "Référence facture Point.P introuvable"
      end

      def extract_ref
        "POINTP-#{extract_date.strftime('%Y%m%d')}-#{extract_internal_ref}"
      end

      def extract_label
        "Achat Point.P"
      end

      def charge_account
        LMNPCompta::COMPTE["Petit équipement et maintenance < 500€"]
      end
    end
  end
end
