module LMNPCompta
  module InvoiceParser
    # Analyseur de factures Point.P.
    class PointP < Base
      # Identifiant unique de l'analyseur.
      # @return [Symbol] l'identifiant `:point_p`
      def self.parser_name; :point_p; end

      # Vérifie si le contenu correspond à une facture Point.P.
      # @param content [String] texte brut extrait de la facture
      # @return [Boolean] `true` si le texte correspond
      def self.match?(content)
        content.match?(/POINT\.P/i)
      end

      # Extrait la date de la facture.
      # @return [Date] date de la facture
      # @raise [ParsingError] si aucune date valide n'est trouvée
      def extract_date
        if content.match(/(\d{1,2}\s+[a-zéû]+\s+\d{4})/i)
          return parse_french_date_text($1)
        end
        scan_first_valid_date
      end

      # Extrait le montant total TTC de la facture.
      # @return [Montant] montant total TTC
      # @raise [ParsingError] si le montant n'est pas trouvé
      def extract_amount
        if content.match(/Total TTC\s*:\s*([\d,]+)\s*€/i)
          return clean_amount($1)
        end
        raise ParsingError, "Montant non trouvé (Point.P)"
      end

      # Extrait la référence interne de la facture.
      # @return [String] numéro de facture
      # @raise [ParsingError] si le numéro est introuvable
      def extract_internal_ref
        if content.match(/Facture N°\s*(\d+)/i)
          return $1
        end
        raise ParsingError, "Référence facture Point.P introuvable"
      end

      # Génère la référence standardisée de la facture.
      # @return [String] référence standardisée
      def extract_ref
        "POINTP-#{extract_date.strftime('%Y%m%d')}-#{extract_internal_ref}"
      end

      # Génère le libellé descriptif pour l'écriture comptable.
      # @return [String] libellé descriptif
      def extract_label
        "Achat Point.P #{extract_internal_ref}"
      end

      # Renvoie le compte de charge par défaut.
      # @return [String] numéro de compte comptable
      def charge_account
        LMNPCompta::COMPTE["Petit équipement et maintenance < 500€"]
      end
    end
  end
end
