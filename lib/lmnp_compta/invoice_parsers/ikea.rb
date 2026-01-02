module LMNPCompta
  module InvoiceParser
    class Ikea < Base
      def self.parser_name; :ikea; end
      def self.match?(content)
        content.match?(/IKEA/i) && (content.match?(/Meubles IKEA France/i) || content.match?(/Inter IKEA Systems/i))
      end

      def extract_date
        if content.match(/Date de facture\s*:\s*(\d{2}\/\d{2}\/\d{4})/i)
          return Date.strptime($1, "%d/%m/%Y")
        end
        scan_first_valid_date
      end

      def extract_amount
        if content.match(/Montant de la facture\s*:\s*([\d,]+)\s*€/i)
          return clean_amount($1)
        end
        # "Total à payer ... " ?
        scan_first_amount
      end

      def extract_internal_ref
        if content.match(/Numéro de facture\s*:\s*([A-Z0-9]+)/i)
          return $1
        end
        raise ParsingError, "Référence facture Ikea introuvable"
      end
      def extract_ref
        "IKEA-#{extract_date.strftime('%Y%m%d')}-#{extract_internal_ref}"
      end

      def extract_label
        "Achat Ikea #{extract_internal_ref}"
      end

      def charge_account
        "606300"
      end

      private

      def scan_first_amount
         # Fallback generic amount finder if needed
         # But the specific regex is safer.
         # Let's try to match "Total TTC" or similar if specific fails.
         if content.match(/Montant TTC\s*([\d,]+)/i)
             return clean_amount($1)
         end
         raise ParsingError, "Montant non trouvé (Ikea)"
      end
    end
  end
end
