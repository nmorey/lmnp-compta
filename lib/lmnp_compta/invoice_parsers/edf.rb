module LMNPCompta
    module InvoiceParser
        class Edf < Base
            def self.parser_name; :edf; end
            def self.match?(content)
                (content.match?(/EDF/i) && content.match?(/calendrier de paiement/i))
            end

            def charge_account; "606100"; end

            def parse
                entries = []
                doc_date = Date.today
                if content.match(/Date d'édition\s*:\s*(\d{2}\/\d{2}\/\d{4})/i)
                    doc_date = parse_slash_date($1)
                end

                # Regex explication :
                # Le\s+       : Commence par "Le "
                # (\d{2}\/..) : Capture la date
                # \s+         : Un ou plusieurs espaces
                # ([\d,]+)    : Capture le montant (chiffres et virgule)
                # \s*€        : Le symbole Euro
                matches = content.scan(/Le\s+(\d{2}\/\d{2}\/\d{4})\s+([\d,]+)\s*€/)

                matches.each do |match|
                    date_prelev = parse_slash_date(match[0])
                    montant = clean_amount(match[1])
                    ref_mois = "EDF-F#{doc_date.strftime('%m/%Y')}-P#{date_prelev.strftime('%m/%Y')}"

                    entries << {
                        date: date_prelev,
                        ref: ref_mois,
                        montant: montant,
                        libelle: "Echéance EDF #{MOIS_INDICE[date_prelev.month]} #{date_prelev.year}",
                        compte_charge: charge_account,
                        compte_banque: credit_account
                    }
                end

                if entries.empty?
                    raise ParsingError, "Aucune échéance trouvée dans le calendrier EDF"
                end
                entries
            end

            def extract_ref; ""; end
            def extract_date; Date.today; end
            def extract_amount; "0"; end
            def extract_label; ""; end
        end
    end
end
