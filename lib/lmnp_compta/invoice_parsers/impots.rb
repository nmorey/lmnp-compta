module LMNPCompta
    module InvoiceParser
        # Analyseur d'avis d'imposition (Taxe Foncière, Taxe d'Habitation).
        class Impots < Base
            # Identifiant unique de l'analyseur.
            # @return [Symbol] l'identifiant `:impots`
            def self.parser_name; :impots; end

            # Vérifie si le contenu correspond à un avis d'imposition.
            # @param content [String] texte brut extrait du document
            # @return [Boolean] `true` si le texte correspond
            def self.match?(content)
                content.match?(/Taxes foncières/i) || content.match?(/Taxe d'habitation/i)
            end

            # Renvoie le compte de charge associé aux impôts et taxes.
            # @return [String] numéro de compte comptable
            def charge_account; LMNPCompta::COMPTE["Impôts et taxes (Taxe Foncière, CFE)"]; end

            # Indique si le document concerne les taxes foncières.
            # @return [Boolean] `true` si taxe foncière
            def is_foncier?()
                content.match?(/Taxes foncières/i)
            end

            # Indique si le document concerne la taxe d'habitation.
            # @return [Boolean] `true` si taxe d'habitation
            def is_habitation?()
                content.match?(/Taxe d'habitation/i)
            end

            # Extrait la référence standardisée de l'avis d'impôt.
            # @return [String] référence standardisée
            # @raise [ParsingError] si la référence est introuvable
            def extract_ref
                r = is_foncier?() ? "FONCIER-" : "HABITATION-"
                if content.match(/Référence de l'avis\s*:\s*([\d\s]+)/i)
                    r += $1.gsub(/\s/, '')
                elsif content.match(/\(C\)\s*:[^\n]*\n\s*([\d\s]+\d+)/i)
                    r += $1.gsub(/\s/, '')
                else
                    raise ParsingError, "Référence Avis Impôt introuvable"
                end
                r
            end

            # Extrait la date d'établissement de l'avis.
            # @return [Date] date de l'avis
            # @raise [ParsingError] si aucune date valide n'est trouvée
            def extract_date
                if content.match(/Date d'établissement\s*:\s.*?(\d{2}\/\d{2}\/\d{4})/m)
                    return parse_slash_date($1)
                end
                scan_first_valid_date
            end

            # Extrait le montant total de l'impôt à payer.
            # @return [Montant] montant total
            # @raise [ParsingError] si le montant est introuvable
            def extract_amount
                if cleaned_content.match(/Montant de vos taxes foncières\s*([\d\s.,]+)\s*€/i)
                    clean_amount($1)
                elsif cleaned_content.match(/Montant de votre taxe d'habitation\s*([\d\s.,]+)\s*€?/i)
                    clean_amount($1)
                else
                    raise ParsingError, "Montant Impôt introuvable"
                end
            end

            # Génère le libellé descriptif pour l'écriture comptable.
            # @return [String] libellé descriptif
            # @raise [ParsingError] si le type d'impôt est inconnu
            def extract_label
                year = extract_date.year
                return "Taxe Foncière #{year}" if content.match?(/Taxes foncières/i)
                return "Taxe Habitation #{year}" if content.match?(/Taxe d'habitation/i)
                raise ParsingError, "Type d'impôt inconnu"
            end
        end
    end
end
