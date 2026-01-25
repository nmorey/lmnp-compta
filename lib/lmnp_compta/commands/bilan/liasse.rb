require 'lmnp_compta/commands/bilan/sub_command'
require 'lmnp_compta/fiscal_analyzer'
require 'lmnp_compta/journal'
require 'lmnp_compta/asset'
require 'lmnp_compta/stock'
require 'lmnp_compta/settings'
require 'yaml'
require 'fileutils'

module LMNPCompta
  module Commands
    module Bilan
      class Liasse < SubCommand
        register 'liasse', 'Afficher les données pour la liasse fiscale (2033)'

        def execute
          # Parse arguments
          options = {}
          parser = OptionParser.new do |opts|
            opts.banner = "Usage: lmnp bilan liasse [options]"
            opts.on("--year YEAR", Integer, "Année fiscale") do |v|
              options[:year] = v
            end
          end
          parser.parse!(@args)

          settings = Settings.instance
          if options[:year]
            settings.annee = options[:year]
          end
          annee = settings.annee

          journal = LMNPCompta::Journal.new(settings.journal_file, year: annee)

                    assets_data = File.exist?(settings.immo_file) ? YAML.load_file(settings.immo_file) : []

          assets = assets_data.map { |d| Asset.new(d) }

          stock_data = File.exist?(settings.stock_file) ? YAML.load_file(settings.stock_file) : {}
          stock = Stock.new(stock_data)

          analyzer = FiscalAnalyzer.new(
              journal.entries,
              assets,
              stock,
              annee
          )
          report = analyzer.generate_report
          puts report

          stock_file = settings.stock_file(annee: annee + 1)
          new_stock_data = analyzer.stock_update_data

          FileUtils.mkdir_p(File.dirname(stock_file))
          File.write(stock_file, new_stock_data.to_h.to_yaml)
          puts "💾 Fichier #{stock_file} mis à jour pour l'an prochain."
        end
      end
    end
  end
end
