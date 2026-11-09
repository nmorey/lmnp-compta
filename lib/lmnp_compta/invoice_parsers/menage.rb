module LMNPCompta
    module InvoiceParser
        # Analyseur de factures de ménage (Le Grand Blanc).
        class Menage < Base
            # Identifiant unique de l'analyseur.
            # @return [Symbol] l'identifiant `:menage`
            def self.parser_name; :menage; end

            # Vérifie si le contenu correspond à une facture de ménage.
            # @param content [String] texte brut extrait de la facture
            # @return [Boolean] `true` si le texte correspond
            def self.match?(content)
                content.match?(/LE GRAND BLANC/i)
            end

            # Renvoie le compte de charge pour l'entretien et les réparations.
            # @return [String] numéro de compte comptable
            def charge_account; LMNPCompta::COMPTE["Entretien et réparations"]; end

            # Extrait la référence interne de la facture.
            # @return [String] référence interne
            # @raise [ParsingError] si le numéro est introuvable
            def extract_internal_ref
                if content.match(/Numéro\s*:\s*([^\n\r]+)/i)
                    $1.strip
                else
                    raise ParsingError, "Numéro de facture Ménage introuvable"
                end
            end

            # Génère une référence standardisée pour la facture.
            # @return [String] référence standardisée
            def extract_ref
                d = extract_date
                "MENAGE-#{d.strftime('%d/%m/%Y')}"
            end

            # Extrait la date d'émission de la facture.
            # @return [Date] date d'émission
            # @raise [ParsingError] si la date est introuvable
            def extract_date
                if content.match(/Émise le\s*:\s*(\d{2}\/\d{2}\/\d{4})/i)
                    parse_slash_date($1)
                else
                    raise ParsingError, "Date facture Ménage introuvable"
                end
            end

            # Extrait le montant total TTC de la facture.
            # @return [Montant] montant total TTC
            # @raise [ParsingError] si le montant est introuvable
            def extract_amount
                if cleaned_content.match(/TOTAL TTC\s*.*?([\d.,]+)\s*€/i)
                    clean_amount($1)
                else
                    raise ParsingError, "Montant Ménage introuvable"
                end
            end

            # Génère le libellé descriptif pour l'écriture comptable.
            # @return [String] libellé descriptif
            def extract_label
                d = extract_date
                n = extract_ref
                "Ménage #{MOIS_INDICE[d.month]} #{d.year} #{n.split(" ")[-1]}"
            end
        end
    end
end
