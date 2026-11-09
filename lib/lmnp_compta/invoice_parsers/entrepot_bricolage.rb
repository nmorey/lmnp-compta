module LMNPCompta
  module InvoiceParser
    # Analyseur de factures pour l'Entrepôt du Bricolage.
    class EntrepotBricolage < Base
      # Identifiant unique de l'analyseur.
      # @return [Symbol] l'identifiant `:entrepot_bricolage`
      def self.parser_name; :entrepot_bricolage; end

      # Vérifie si le contenu correspond à une facture de l'Entrepôt du Bricolage.
      # @param content [String] texte brut extrait de la facture
      # @return [Boolean] `true` si le texte correspond
      def self.match?(content)
        content.match?(/ENTREP(?:Ô|O)T DU BRICOLAGE/i)
      end

      # Extrait la date de la facture.
      # @return [Date] date de la facture
      # @raise [ParsingError] si aucune date valide n'est trouvée
      def extract_date
        if content.match(/le\s+(\d{2}\/\d{2}\/\d{4})\s+\d{2}:\d{2}:\d{2}/i)
          return Date.strptime($1, "%d/%m/%Y")
        end
        scan_first_valid_date
      end

      # Extrait le montant total TTC de la facture.
      # @return [Montant] montant total TTC
      # @raise [ParsingError] si le montant ne peut pas être extrait
      def extract_amount
        if content.match(/TOTAL TTC\s*:\s*([\d,]+)\s*€/i)
          return clean_amount($1)
        end
        raise ParsingError, "Montant non trouvé (Entrepôt du Bricolage)"
      end

      # Extrait la référence interne de la facture (numéro de facture ou code-barres).
      # @return [String] référence interne
      # @raise [ParsingError] si la référence est introuvable
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

      # Génère une référence standardisée pour la facture.
      # @return [String] référence standardisée
      def extract_ref
        "ENTREPOT-#{extract_date.strftime('%Y%m%d')}-#{extract_internal_ref}"
      end

      # Génère un libellé descriptif pour l'écriture comptable.
      # @return [String] libellé descriptif
      def extract_label
        "Achat Entrepôt du Bricolage #{extract_internal_ref}"
      end

      # Renvoie le compte de charge par défaut.
      # @return [String] numéro de compte comptable
      def charge_account
        LMNPCompta::COMPTE["Petit équipement et maintenance < 500€"]
      end
    end
  end
end
