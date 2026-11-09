require 'date'
require_relative 'parsing_utils'
require_relative 'plan_comptable'

module LMNPCompta
    # Espace de nommage des parsers de factures PDF
    module InvoiceParser
        # Erreur survenue lors de l'analyse d'une facture
        class ParsingError < StandardError
            attr_accessor :ftype
        end

        # Classe de base pour tous les parsers de factures
        class Base
            @registry = []

            class << self
                attr_reader :registry

                # Enregistre automatiquement toute sous-classe dans le registre des parsers
                # @param subclass [Class] Sous-classe héritant de Base
                # @return [void]
                def inherited(subclass)
                    @registry << subclass
                end

                # Détermine si le contenu correspond à ce parser
                # @param content [String] Texte extrait du document
                # @return [Boolean]
                def match?(content)
                    false
                end

                # Nom canonique du parser (en minuscules)
                # @return [String, nil]
                def parser_name
                    nil
                end
            end

            attr_reader :content, :cleaned_content

            # Table de correspondance numéro de mois => libellé français
            # @return [Hash{Integer => String}]
            MOIS_INDICE = {
                1=>"Janvier", 2=>"Février", 3=>"Mars", 4=>"Avril", 5=>"Mai", 6=>"Juin",
                7=>"Juillet", 8=>"Août", 9=>"Septembre", 10=>"Octobre", 11=>"Novembre", 12=>"Décembre"
            }

            # Initialise le parser avec le texte du document
            # @param content [String] Contenu textuel de la facture
            def initialize(content)
                @content = content
                @cleaned_content = content.gsub(/\n/, ' ')
            end

            # Analyse le document et retourne un tableau de hachages représentant les échéances/écritures
            # @return [Array<Hash>] Liste des données extraites (:date, :ref, :montant, :libelle, :compte_charge, :compte_banque)
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

            # Numéro de compte de charge par défaut pour cette facture
            # @return [String] Numéro de compte
            def charge_account; LMNPCompta::COMPTE["Compte d'attente"]; end

            # Numéro de compte de contrepartie (trésorerie) par défaut
            # @return [String] Numéro de compte
            def credit_account; LMNPCompta::COMPTE["Banque"]; end

            protected

            # Nettoie une chaîne de montant pour le parsing
            # @param raw [String] Chaîne brute représentant le montant
            # @return [String] Montant normalisé
            # @raise [ParsingError] Si le montant est invalide
            def clean_amount(raw)
               ParsingUtils.clean_amount(raw)
            rescue ArgumentError => e
               raise ParsingError, e.message
            end

            def parse_slash_date(str)
                d = ParsingUtils.parse_french_date(str)
                raise ParsingError, "Date vide" if str.nil?
                raise ParsingError, "Impossible de lire la date : '#{str}'" unless d
                d
            end

            # Parse une date écrite en français textuel (ex. "15 janvier 2024")
            # @param str [String] Chaîne représentant la date
            # @return [Date]
            # @raise [ParsingError] Si la date est invalide ou le mois inconnu
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

        # Fabrique de parsers de factures
        class Factory
            # Instancie le parser adéquat selon le type forcé ou par détection automatique du contenu
            # @param type_arg [String, nil] Nom du parser forcé (ex. "edf", "sosh")
            # @param content [String] Texte extrait du document
            # @return [Base, nil] Instance du parser ou nil si non reconnu
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

    # Charge les parsers de factures personnalisés situés dans le dossier externe configuré
    # @return [void]
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
