module LMNPCompta
  module InvoiceParser
    class Sosh < Base
      def self.parser_name; :sosh; end
      def self.match?(content)
        content.match?(/Sosh/i) || content.match?(/Orange/i)
      end

      def charge_account; "626000"; end

      def extract_ref
        if content.match(/n°?\s*de facture\s*:\s*(.*?)(?=\s*date de facture|\n|$)/i)
          $1.strip.gsub(/date de facture.*/i, '').strip
        else
          raise ParsingError, "Référence facture Sosh introuvable"
        end
      end

      def extract_date
        if content.match(/date de facture\s*:\s*(\d{2}\/\d{2}\/\d{2,4})/i)
          parse_slash_date($1)
        else
          raise ParsingError, "Date facture Sosh introuvable"
        end
      end

      def extract_amount
        if cleaned_content.match(/total du montant prélevé.*?(\d+[,.]\d+)\s*€/i)
          clean_amount($1)
        else
          raise ParsingError, "Montant Sosh introuvable"
        end
      end

      def extract_label
        d = extract_date
        "Internet Sosh #{MOIS_INDICE[d.month]} #{d.year}"
      end
    end
  end
end
