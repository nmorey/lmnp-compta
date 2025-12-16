require 'date'

module LMNPCompta
    module InvoiceParser
        class ParsingError < StandardError
            attr_accessor :ftype
        end

        class Base
            @registry = []

            class << self
                attr_reader :registry

                def inherited(subclass)
                    @registry << subclass
                end

                def match?(content)
                    false
                end

                def parser_name
                    nil
                end
            end

            attr_reader :content, :cleaned_content

            MOIS_INDICE = {
                1=>"Janvier", 2=>"Février", 3=>"Mars", 4=>"Avril", 5=>"Mai", 6=>"Juin",
                7=>"Juillet", 8=>"Août", 9=>"Septembre", 10=>"Octobre", 11=>"Novembre", 12=>"Décembre"
            }

            def initialize(content)
                @content = content
                @cleaned_content = content.gsub(/\n/, ' ')
            end

            def parse
                [{
                     date: extract_date,
                     ref: extract_ref,
                     montant: extract_amount,
                     libelle: extract_label,
                     compte_charge: charge_account,
                     compte_banque: credit_account
                 }]
            end

            def extract_ref; raise NotImplementedError; end
            def extract_date; raise NotImplementedError; end
            def extract_amount; raise NotImplementedError; end
            def extract_label; raise NotImplementedError; end
            def charge_account; "471000"; end
            def credit_account; "512000"; end

            protected

            def clean_amount(raw)
                raise ParsingError, "Montant nul ou vide détecté" if raw.nil? || raw.strip.empty?
                val = raw.gsub(/\s/, '').gsub(',', '.')
                raise ParsingError, "Format de montant invalide : #{raw}" unless val.match?(/^\d+(\.\d+)?$/)
                val
            end

            def parse_slash_date(str)
                raise ParsingError, "Date vide" if str.nil?
                fmt = str.length > 8 ? "%d/%m/%Y" : "%d/%m/%y"
                Date.strptime(str, fmt)
            rescue Date::Error, TypeError
                raise ParsingError, "Impossible de lire la date : '#{str}'"
            end

            def parse_french_date_text(str)
                raise ParsingError, "Date texte vide" if str.nil?
                mois_fr = {
                    "janvier"=>1, "fevrier"=>2, "février"=>2, "mars"=>3, "avril"=>4,
                    "mai"=>5, "juin"=>6, "juillet"=>7, "aout"=>8, "août"=>8,
                    "septembre"=>9, "octobre"=>10, "novembre"=>11, "decembre"=>12, "décembre"=>12
                }

                parts = str.split(' ')
                raise ParsingError, "Format date texte invalide : '#{str}'" if parts.length < 3

                day = parts[0]
                month_str = parts[1]
                year = parts[2]

                month_int = mois_fr[month_str.downcase]
                raise ParsingError, "Mois inconnu dans la date : '#{month_str}'" unless month_int

                Date.new(year.to_i, month_int, day.to_i)
            rescue ArgumentError
                raise ParsingError, "Date invalide (jour/année incorrects) : '#{str}'"
            end

            def scan_first_valid_date
                matches = content.scan(/(\d{2}\/\d{2}\/\d{4})/)
                matches.each do |match|
                    begin
                        d = Date.strptime(match[0], "%d/%m/%Y")
                        if d.year >= Date.today.year - 2 && d.year <= Date.today.year + 1
                            return d
                        end
                    rescue
                        next
                    end
                end
                raise ParsingError, "Aucune date valide trouvée dans le document"
            end
        end

        class Factory
            def self.build(type_arg, content)
                if type_arg
                    klass = Base.registry.find { |k| k.parser_name == type_arg }
                    return klass.new(content) if klass
                end

                match_klass = Base.registry.find { |k| k.match?(content) }
                return match_klass.new(content) if match_klass
                nil
            end
        end
    end

    def self.load_external_parsers
        dir = Settings.instance.extra_invoice_dir
        if dir && Dir.exist?(dir)
            Dir.glob(File.join(dir, '*.rb')).each do |file|
                require file
            end
        end
    end
end

# Auto-load all parsers from the 'invoice_parsers' directory
Dir.glob(File.join(__dir__, 'invoice_parsers', '*.rb')).each do |file|
    require file
end
