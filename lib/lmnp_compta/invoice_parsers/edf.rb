module LMNPCompta
    module InvoiceParser
        class Edf < Base
            def self.parser_name; :edf; end
            def self.match?(content)
                (content.match?(/EDF/i) && content.match?(/Facture du/i))
            end

            def charge_account; LMNPCompta::COMPTE["Eau, Électricité, Gaz, Chauffage"]; end

            def extract_date
                if content.match(/(?:Détail de la facture du)\s*(\d{1,2}\/\d{2}\/\d{4})/i)
                    return Date.strptime($1.gsub('/', '.'), "%d.%m.%Y")
                end
                raise ParsingError, "Date facture EDF introuvable"
            end

            def extract_amount
                if content.match(/Facture TTC\s*([\d,]+)\s*€/i)
                    return clean_amount($1)
                end
                # Fallback or other patterns
                raise ParsingError, "Montant non trouvé (EDF)"
            end

            def extract_internal_ref
                if content.match(/(?:Détail de la facture du\s*\d{1,2}\/\d{2}\/\d{4}\s*N°\s*)([0-9]+)/i)
                    return $1
                else
                    raise ParsingError, "Référence facture EDF introuvable"
                end
            end

            def extract_pdl
                if content.match(/(?:Point de livraison(?:\s*\(PDL\))?|N° de PDL|PDL)\s*:\s*(?:N°\s*)?([0-9][0-9 \t]{12,22}[0-9])/i)
                    digits = $1.gsub(/\s+/, '')
                    return digits if digits.match?(/^\d{14}$/)
                end

                if content.match(/(?:Point de livraison(?:\s*\(PDL\))?|N° de PDL|PDL)\s*:[^\n]*\n\s*(?:N°\s*)?([0-9][0-9 \t]{12,22}[0-9])/i)
                    digits = $1.gsub(/\s+/, '')
                    return digits if digits.match?(/^\d{14}$/)
                end

                nil
            end

            def extract_ref
                pdl = extract_pdl
                prefix = pdl ? "EDF-#{pdl}" : "EDF"
                "#{prefix}-FAC-#{extract_date.strftime('%Y%m%d')}-#{extract_internal_ref}"
            end
            def extract_label
                "Rattrapage EDF #{extract_date}"
            end
        end
    end
end
