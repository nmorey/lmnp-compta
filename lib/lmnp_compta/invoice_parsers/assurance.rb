module LMNPCompta
    module InvoiceParser
        # Parser pour les avis d'échéance et factures d'assurance (PNO)
        class Assurance < Base
            # @return [Symbol]
            def self.parser_name; :assurance; end

            # @param content [String]
            # @return [Boolean]
            def self.match?(content)
                content.match?(/Direct Assurance/i)
            end

            # @return [String]
            def charge_account; LMNPCompta::COMPTE["Primes d'assurances (PNO, GLI)"]; end

            # @return [String]
            def extract_ref
                if content.match(/Contrat n°\s*(\d+)/i)
                    "Contrat #{$1}"
                else
                    raise ParsingError, "Numéro de contrat Assurance introuvable"
                end
            end

            # @return [Date]
            def extract_date
                if content.match(/le\s+(\d{2}\/\d{2}\/\d{4})/i)
                    parse_slash_date($1)
                else
                    raise ParsingError, "Date contrat Assurance introuvable"
                end
            end

            # @return [String]
            def extract_amount
                if cleaned_content.match(/Montant annuel TTC à prélever.*?([\d.,]+)\s*€/i)
                    clean_amount($1)
                else
                    raise ParsingError, "Montant Assurance introuvable"
                end
            end

            # @return [String]
            def extract_label
                "Assurance Habitation PNO #{extract_date.year}"
            end
        end
    end
end
