module LMNPCompta
    module InvoiceParser
        class Copro < Base
            def self.parser_name; :copro; end
            def self.match?(content)
                content.match?(/APPEL DE FONDS/i)
            end

            def charge_account; "614000"; end

            def extract_ref
                if content.match(/Appel, Du\s+(\d{2}\/\d{2}\/\d{4})/i)
                    "Appel #{$1}"
                else
                    "Appel Fonds"
                end
            end

            def extract_date
                if content.match(/le\s+(\d{1,2}\s+[a-zA-Zéû]+\s+\d{4})/i)
                    parse_french_date_text($1)
                else
                    raise ParsingError, "Date Appel de fonds introuvable"
                end
            end

            def extract_amount
                if cleaned_content.match(/Total appel\s*([\d\s.,]+)/i)
                    clean_amount($1)
                else
                    raise ParsingError, "Montant Appel de fonds introuvable"
                end
            end

            def extract_label
                d = extract_date
                "Charges Copro (Appel #{d.month}/#{d.year})"
            end
        end
    end
end
