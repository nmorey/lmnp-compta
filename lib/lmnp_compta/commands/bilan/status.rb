require 'lmnp_compta/commands/bilan/sub_command'
require 'lmnp_compta/fiscal_analyzer'
require 'lmnp_compta/journal'
require 'lmnp_compta/asset'
require 'lmnp_compta/stock'
require 'lmnp_compta/settings'
require 'lmnp_compta/cloture'
require 'yaml'

module LMNPCompta
    module Commands
        module Bilan
            class Status < SubCommand
                register 'status', 'Simuler la clôture et afficher la liasse fiscale (sans modification)'

                def execute
                    options = {}
                    parser = OptionParser.new do |opts|
                        opts.banner = "Usage: lmnp bilan status [options]"
                        opts.on("--year YEAR", Integer, "Année fiscale") do |v|
                            options[:year] = v
                        end
                        opts.on("-h", "--help", "Affiche l'aide") do
                            puts opts
                            exit 0
                        end
                    end
                    parser.parse!(@args)

                    settings = Settings.instance
                    if options[:year]
                        settings.annee = options[:year]
                    end
                    annee = settings.annee

                    # Load the journal in-memory mode
                    journal = LMNPCompta::Journal.new(settings.journal_file, year: annee, in_mem: true)

                    puts "==========================================================="
                    puts "       [SIMULATION] CLÔTURE DE L'EXERCICE #{annee}"
                    puts "==========================================================="

                    if journal.closed?
                        puts "⚠️  Le journal est déjà clôturé. Génération de la liasse sur les données existantes."
                    else
                        LMNPCompta::Cloture.cloturer(journal, annee)
                    end

                    puts "\n==========================================================="
                    puts "       [SIMULATION] GÉNÉRATION DE LA LIASSE (Année #{annee})"
                    puts "==========================================================="

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
                end
            end
        end
    end
end
