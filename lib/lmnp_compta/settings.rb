require 'yaml'
require 'date'

module LMNPCompta
    # Gestion de la configuration globale
    class Settings
        attr_reader :siren, :annee, :data_dir, :extra_invoice_dir

        # Charge la configuration
        # @param config_file [String] Chemin vers le fichier YAML de configuration
        def initialize(config_file = 'lmnp.yaml')
            config = {}
            if File.exist?(config_file)
                config = YAML.load_file(config_file) || {}
            end

            @siren = config['siren'] || "000000000"
            @annee = config['annee'] || Date.today.year
            @data_dir = config['data_dir'] || "data"
            @journal_file_setting = config['journal_file'] || "journal.yaml"
            @stock_file_setting = config['stock_file'] || "stock_fiscal.yaml"
            @immo_file_setting = config['immo_file'] || "immobilisations.yaml"
            @extra_invoice_dir = config['extra_invoice_dir']
        end

        def journal_file(annee: @annee)
            File.join(@data_dir, annee.to_s, @journal_file_setting)
        end

        def stock_file(annee: @annee)
            File.join(@data_dir, annee.to_s, @stock_file_setting)
        end

        def immo_file
            File.join(@data_dir, @immo_file_setting)
        end

        # Charge et stocke le singleton de configuration
        def self.load(config_file = 'lmnp.yaml')
            @instance = new(config_file)
        end

        # Accès au singleton
        def self.instance
            @instance ||= new
        end
    end
end
