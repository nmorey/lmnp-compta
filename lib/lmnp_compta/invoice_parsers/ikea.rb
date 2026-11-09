module LMNPCompta
  module InvoiceParser
    # Analyseur de factures pour Ikea.
    class Ikea < Base
      # Identifiant unique de l'analyseur.
      # @return [Symbol] l'identifiant `:ikea`
      def self.parser_name; :ikea; end

      # Vérifie si le contenu correspond à une facture Ikea.
      # @param content [String] texte brut extrait de la facture
      # @return [Boolean] `true` si le texte correspond
      def self.match?(content)
        content.match?(/IKEA/i) && (content.match?(/Meubles IKEA France/i) || content.match?(/Inter IKEA Systems/i))
      end

      # Extrait la date de la facture.
      # @return [Date] date de la facture
      # @raise [ParsingError] si aucune date valide n'est trouvée
      def extract_date
        if content.match(/Date de facture\s*:\s*(\d{2}\/\d{2}\/\d{4})/i)
          return Date.strptime($1, "%d/%m/%Y")
        end
        scan_first_valid_date
      end

      # Extrait le montant total de la facture.
      # @return [Montant] montant de la facture
      # @raise [ParsingError] si le montant ne peut pas être extrait
      def extract_amount
        if content.match(/Montant de la facture\s*:\s*([\d,]+)\s*€/i)
          return clean_amount($1)
        end
        # "Total à payer ... " ?
        scan_first_amount
      end

      # Extrait la référence interne de la facture.
      # @return [String] numéro de facture
      # @raise [ParsingError] si le numéro est introuvable
      def extract_internal_ref
        if content.match(/Numéro de facture\s*:\s*([A-Z0-9]+)/i)
          return $1
        end
        raise ParsingError, "Référence facture Ikea introuvable"
      end

      # Génère une référence standardisée pour la facture.
      # @return [String] référence standardisée
      def extract_ref
        "IKEA-#{extract_date.strftime('%Y%m%d')}-#{extract_internal_ref}"
      end

      # Génère un libellé descriptif pour l'écriture comptable.
      # @return [String] libellé descriptif
      def extract_label
        "Achat Ikea #{extract_internal_ref}"
      end

      # Renvoie le compte de charge par défaut.
      # @return [String] numéro de compte comptable
      def charge_account
        LMNPCompta::COMPTE["Petit équipement et maintenance < 500€"]
      end

      private

      # Recherche un montant de repli dans le contenu texte.
      # @return [Montant] montant extrait
      # @raise [ParsingError] si aucun montant n'est trouvé
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
