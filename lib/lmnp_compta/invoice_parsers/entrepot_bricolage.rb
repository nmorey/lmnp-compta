module LMNPCompta
  module InvoiceParser
    class EntrepotBricolage < Base
      def self.parser_name; :entrepot_bricolage; end
      def self.match?(content)
        content.match?(/ENTREP(?:Ô|O)T DU BRICOLAGE/i)
      end

      def extract_date
        if content.match(/le\s+(\d{2}\/\d{2}\/\d{4})\s+\d{2}:\d{2}:\d{2}/i)
          return Date.strptime($1, "%d/%m/%Y")
        end
        scan_first_valid_date
      end

      def extract_amount
        if content.match(/TOTAL TTC\s*:\s*([\d,]+)\s*€/i)
          return clean_amount($1)
        end
        raise ParsingError, "Montant non trouvé (Entrepôt du Bricolage)"
      end

      def extract_internal_ref
        # Trying to find a number, otherwise fallback to date
        if content.match(/Facture N°\s*(\d+)/i)
            return $1
        end
        # The barcode number observed was 900...
        if content.match(/(\d{10,})/)
            return $1
        end
        raise ParsingError, "Référence facture Entrepot du Bricolage introuvable"
      end
      def extract_ref
        "ENTREPOT-#{extract_date.strftime('%Y%m%d')}-#{extract_internal_ref}"
      end

      def extract_label
        "Achat Entrepôt du Bricolage"
      end

      def charge_account
        "606300"
      end
    end
  end
end
