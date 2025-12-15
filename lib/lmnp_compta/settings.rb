require 'yaml'
require 'date'

module LMNPCompta
    class Settings
        attr_reader :siren, :annee, :journal_file, :stock_file, :immo_file

        def initialize(config_file = 'lmnp.yaml')
            config = {}
            if File.exist?(config_file)
                config = YAML.load_file(config_file) || {}
            end

            @siren = config['siren'] || "000000000"
            @annee = config['annee'] || Date.today.year
            @journal_file = config['journal_file'] || "data/journal_#{@annee}.yaml"
            @stock_file = config['stock_file'] || "data/stock_fiscal.yaml"
            @immo_file = config['immo_file'] || "data/immobilisations.yaml"
        end

        def self.load(config_file = 'lmnp.yaml')
            @instance = new(config_file)
        end

        def self.instance
            @instance ||= new
        end
    end
end
