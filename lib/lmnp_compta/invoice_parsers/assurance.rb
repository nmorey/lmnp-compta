module LMNPCompta
  module InvoiceParser
    class Assurance < Base
      def self.parser_name; :assurance; end
      def self.match?(content)
        content.match?(/Direct Assurance/i) || content.match?(/AVIS D'ÉCHÉANCE/i)
      end

      def charge_account; "616000"; end

      def extract_ref
        if content.match(/Contrat n°\s*(\d+)/i)
          "Contrat #{$1}"
        else
          raise ParsingError, "Numéro de contrat Assurance introuvable"
        end
      end

      def extract_date
        if content.match(/le\s+(\d{2}\/\d{2}\/\d{4})/i)
          parse_slash_date($1)
        else
          raise ParsingError, "Date contrat Assurance introuvable"
        end
      end

      def extract_amount
        if cleaned_content.match(/Montant annuel TTC à prélever.*?([\d.,]+)\s*€/i)
          clean_amount($1)
        else
          raise ParsingError, "Montant Assurance introuvable"
        end
      end

      def extract_label
        "Assurance Habitation PNO #{extract_date.year}"
      end
    end
  end
end
