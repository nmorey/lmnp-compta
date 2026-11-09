module LMNPCompta
  module InvoiceParser
    # Parser pour les factures d'achat Amazon
    class Amazon < Base
      # @return [Symbol]
      def self.parser_name; :amazon; end

      # @param content [String]
      # @return [Boolean]
      def self.match?(content)
        content.match?(/amazon\.fr/i) || content.match?(/Amazon EU/i)
      end

      # @return [Date]
      def extract_date
        # Support "23.12.2025" or "23 décembre 2025"
        if content.match(/(?:Date de la commande|Date de la facture\/Date de la livraison)\s*(\d{1,2}[\. ]\d{2}[\. ]\d{4})/i)
          return Date.strptime($1.gsub(' ', '.'), "%d.%m.%Y")
        end

        if content.match(/(?:Date de la commande|Date de la facture\/Date de la livraison)\s*(\d{1,2}\s+[a-zéû]+\s+\d{4})/i)
          return parse_french_date_text($1)
        end

        scan_first_valid_date
      end

      # @return [String]
      def extract_amount
        if content.match(/Total à payer\s*([\d,]+)\s*€/i)
          return clean_amount($1)
        end
        # Fallback or other patterns
        raise ParsingError, "Montant non trouvé (Amazon)"
      end

      # @return [String]
      def extract_internal_ref
        if content.match(/Numéro de la facture\s*([A-Z0-9]+)/i)
          return $1
        else
            raise ParsingError, "Référence facture Amazon introuvable"
        end
      end

      # @return [String]
      def extract_ref
          "AMAZON-#{extract_date.strftime('%Y%m%d')}-#{extract_internal_ref}"
      end

      # @return [String]
      def extract_label
        "Achat Amazon #{extract_internal_ref}"
      end

      # @return [String]
      def charge_account
        LMNPCompta::COMPTE["Petit équipement et maintenance < 500€"]
      end
    end
  end
end
