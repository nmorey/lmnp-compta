require 'lmnp_compta/command'
require 'lmnp_compta/journal'
require 'lmnp_compta/fiscal_analyzer'
require 'lmnp_compta/stock'
require 'yaml'
require 'fileutils'

module LMNPCompta
    module Commands
        class Report < Command
            register 'liasse', 'Générer la liasse fiscale (2033) et mettre à jour les stocks'

            def execute
                OptionParser.new do |opts|
                    opts.banner = "Usage: lmnp liasse"
                end.parse!(@args)

                settings = Settings.instance
                journal_file = settings.journal_file
                immo_file = settings.immo_file
                stock_file = settings.stock_file
                annee = settings.annee

                unless File.exist?(journal_file)
                    raise "Fichier journal introuvable (#{journal_file})"
                end

                journal = Journal.new(journal_file, year: annee)
                entries = journal.entries
                assets = Asset.load(immo_file)
                stock = Stock.load(stock_file)

                analyzer = FiscalAnalyzer.new(entries, assets, stock, annee)

                # Génération et affichage du rapport
                report_doc = analyzer.generate_report
                puts report_doc.to_s

                # Sauvegarde des stocks pour l'année suivante
                analyzer.stock_update_data.save!(stock_file)
                puts "💾 Fichier #{stock_file} mis à jour pour l'an prochain."
            end
        end
    end
end
