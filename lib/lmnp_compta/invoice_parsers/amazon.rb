module LMNPCompta
  module InvoiceParser
    class Amazon < Base
      def self.parser_name; :amazon; end
      def self.match?(content)
        content.match?(/amazon\.fr/i) || content.match?(/Amazon EU/i)
      end

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

      def extract_amount
        if content.match(/Total à payer\s*([\d,]+)\s*€/i)
          return clean_amount($1)
        end
        # Fallback or other patterns
        raise ParsingError, "Montant non trouvé (Amazon)"
      end

      def extract_internal_ref
        if content.match(/Numéro de la facture\s*([A-Z0-9]+)/i)
          return $1
        else
            raise ParsingError, "Référence facture Amazon introuvable"
        end
      end
      def extract_ref
          "AMAZON-#{extract_date.strftime('%Y%m%d')}-#{extract_internal_ref}"
      end
      def extract_label
        "Achat Amazon #{extract_internal_ref}"
      end

      def charge_account
        "606300"
      end
    end
  end
end
