module LMNPCompta
    module InvoiceParser
        class Menage < Base
            def self.parser_name; :menage; end
            def self.match?(content)
                content.match?(/LE GRAND BLANC/i)
            end

            def charge_account; "615000"; end

            def extract_internal_ref
                if content.match(/Numéro\s*:\s*([^\n\r]+)/i)
                    $1.strip
                else
                    raise ParsingError, "Numéro de facture Ménage introuvable"
                end
            end
            def extract_ref
                d = extract_date
                "MENAGE-#{d.strftime('%d/%m/%Y')}"
            end

            def extract_date
                if content.match(/Émise le\s*:\s*(\d{2}\/\d{2}\/\d{4})/i)
                    parse_slash_date($1)
                else
                    raise ParsingError, "Date facture Ménage introuvable"
                end
            end

            def extract_amount
                if cleaned_content.match(/TOTAL TTC\s*.*?([\d.,]+)\s*€/i)
                    clean_amount($1)
                else
                    raise ParsingError, "Montant Ménage introuvable"
                end
            end

            def extract_label
                d = extract_date
                n = extract_ref
                "Ménage #{MOIS_INDICE[d.month]} #{d.year} #{n.split(" ")[-1]}"
            end
        end
    end
end
