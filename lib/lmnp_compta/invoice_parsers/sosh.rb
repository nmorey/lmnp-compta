module LMNPCompta
    module InvoiceParser
        # Analyseur de factures Sosh / Orange.
        class Sosh < Base
            # Identifiant unique de l'analyseur.
            # @return [Symbol] l'identifiant `:sosh`
            def self.parser_name; :sosh; end

            # Vérifie si le contenu correspond à une facture Sosh ou Orange.
            # @param content [String] texte brut extrait de la facture
            # @return [Boolean] `true` si le texte correspond
            def self.match?(content)
                content.match?(/Sosh/i) || content.match?(/Orange/i)
            end

            # Renvoie le compte de charge pour les frais postaux et télécoms.
            # @return [String] numéro de compte comptable
            def charge_account; LMNPCompta::COMPTE["Frais postaux et télécoms"]; end

            # Extrait la référence interne de la facture.
            # @return [String] référence interne
            # @raise [ParsingError] si la référence est introuvable
            def extract_internal_ref
                if content.match(/n°?\s*de facture\s*:\s*(.*?)(?=\s*date de facture|\n|$)/i)
                    $1.strip.gsub(/date de facture.*/i, '').gsub(/ /, '').strip
                else
                    raise ParsingError, "Référence facture Sosh introuvable"
                end
            end

            # Génère une référence standardisée pour la facture.
            # @return [String] référence standardisée
            def extract_ref
                d = extract_date
                "SOSH-#{d.strftime('%m/%Y')}"
            end

            # Extrait la date de la facture.
            # @return [Date] date de la facture
            # @raise [ParsingError] si la date est introuvable
            def extract_date
                if content.match(/date de facture\s*:\s*(\d{2}\/\d{2}\/\d{2,4})/i)
                    parse_slash_date($1)
                else
                    raise ParsingError, "Date facture Sosh introuvable"
                end
            end

            # Extrait le montant total prélevé.
            # @return [Montant] montant total
            # @raise [ParsingError] si le montant est introuvable
            def extract_amount
                if cleaned_content.match(/total du montant prélevé.*?(\d+[,.]\d+)\s*€/i)
                    clean_amount($1)
                else
                    raise ParsingError, "Montant Sosh introuvable"
                end
            end

            # Génère le libellé descriptif pour l'écriture comptable.
            # @return [String] libellé descriptif
            def extract_label
                d = extract_date
                "Internet Sosh #{MOIS_INDICE[d.month]} #{d.year}"
            end
        end
    end
end
