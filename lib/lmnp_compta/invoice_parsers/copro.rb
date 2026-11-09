module LMNPCompta
    module InvoiceParser
        # Parser pour les appels de fonds de copropriété
        class Copro < Base
            # @return [Symbol]
            def self.parser_name; :copro; end

            # @param content [String]
            # @return [Boolean]
            def self.match?(content)
                content.match?(/APPEL DE FONDS/i)
            end

            # @return [String]
            def charge_account; LMNPCompta::COMPTE["Charges locatives de copropriété"]; end

            # @return [String]
            def extract_ref
                if content.match(/Appel, Du\s+(\d{2}\/\d{2}\/\d{4})/i)
                    "COPRO-#{$1}"
                else
                     raise ParsingError, "Date d'appel introuvable"
                end
            end

            # @return [Date]
            def extract_date
                if content.match(/le\s+(\d{1,2}\s+[a-zA-Zéû]+\s+\d{4})/i)
                    parse_french_date_text($1)
                else
                    raise ParsingError, "Date Appel de fonds introuvable"
                end
            end

            # @return [String]
            def extract_amount
                if cleaned_content.match(/Total appel\s*([\d\s.,]+)/i)
                    clean_amount($1)
                else
                    raise ParsingError, "Montant Appel de fonds introuvable"
                end
            end

            # @return [String]
            def extract_label
                d = extract_date
                "Charges Copro (Appel #{d.month}/#{d.year})"
            end
        end
    end
end
