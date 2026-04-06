require 'lmnp_compta/commands/journal/sub_command'
require 'lmnp_compta/journal'
require 'lmnp_compta/montant'
require 'lmnp_compta/settings'
require 'date'
require 'csv'

module LMNPCompta
    module Commands
        module Journal
            class Status < SubCommand
                register 'status', 'État de la trésorerie'


                def entreprise_view(e)
                    entry_credit = Montant.new(0)
                    entry_debit = Montant.new(0)

                    line_512 = e.lines.find { |l| l[:compte].to_s ==  LMNPCompta::COMPTE["Banque"] }
                    if line_512
                        e.lines.each do |l|
                            next if l[:compte] ==  LMNPCompta::COMPTE["Banque"]
                            entry_credit += l[:credit]
                            entry_debit += l[:debit]
                        end
                    else
                        has_immo = e.lines.any? { |l| l[:compte].to_s.start_with?('2') }
                        if has_immo
                            return Montant.new(0), Montant.new(0)
                        end

                        line_108 = e.lines.find { |l|
                            l[:compte].to_s ==  LMNPCompta::COMPTE["Compte de l'exploitant"]
                        }
                        if line_108 && line_108[:debit] > Montant.new(0)
                            warn "Warning: 108000 is a debit line in entry #{e.ref}"
                        end

                        e.lines.each do |l|
                            next if l[:compte].to_s == '108000'
                            if l[:debit] > Montant.new(0)
                                entry_debit += l[:debit]
                            end
                        end
                    end

                    if entry_credit > Montant.new(0) || entry_debit > Montant.new(0)

                        c_str = entry_credit > Montant.new(0) ? "+#{entry_credit}" : ""
                        d_str = entry_debit > Montant.new(0) ? "-#{entry_debit}" : ""
                        puts format("%-12s %-20s %12s %12s", e.date, e.ref[0..19], c_str, d_str)
                        return entry_credit, entry_debit
                    end
                    return Montant.new(0), Montant.new(0)
                end
                def account_view(e)
                    total_credit = Montant.new(0)
                    total_debit = Montant.new(0)

                    e.lines.select { |l| l[:compte].to_s ==  LMNPCompta::COMPTE["Banque"] }.each do |l|
                        credit_releve = l[:debit]
                        debit_releve = l[:credit]

                        total_credit += credit_releve
                        total_debit += debit_releve

                        c_str = credit_releve > Montant.new(0) ? "+#{credit_releve}" : ""
                        d_str = debit_releve > Montant.new(0) ? "-#{debit_releve}" : ""

                        puts format("%-12s %-20s %12s %12s", e.date, e.ref[0..19], c_str, d_str)
                    end
                    return total_credit, total_debit
                end

                def execute
                    require 'optparse'
                    full_mode = false

                    parser = OptionParser.new do |opts|
                        opts.banner = "Usage: lmnp journal status [options]"
                        opts.on("--full", "Affiche une vue complète (incluant le compte de l'exploitant)") do
                            full_mode = true
                        end
                        opts.on("-h", "--help", "Affiche l'aide") do
                            puts opts
                            exit 0
                        end
                    end

                    begin
                        parser.parse!(@args)
                    rescue OptionParser::InvalidOption => e
                        puts e
                        puts parser
                        exit 1
                    end

                    year = Settings.instance.annee
                    journal = LMNPCompta::Journal.new(Settings.instance.journal_file, year: year)

                    relevant = journal.entries.select do |e|
                        is_current_year = Date.parse(e.date.to_s).year == year.to_i
                        next false unless is_current_year
                        next false if e.ref.to_s.start_with?("CLOTURE")

                        if full_mode
                            e.lines.any? { |l| %w[512000 108000].include?(l[:compte].to_s) }
                        else
                            e.lines.any? { |l| l[:compte].to_s ==  LMNPCompta::COMPTE["Banque"] }
                        end
                    end

                    total_credit = Montant.new(0)
                    total_debit = Montant.new(0)

                    puts format("%-12s %-20s %12s %12s", "Date", "Ref", "Crédit", "Débit")
                    puts "-" * 60

                    relevant.sort_by { |e| e.date.to_s }.each do |e|
                        credit = debit = 0
                        if full_mode
                            credit, debit = entreprise_view(e)
                        else
                            credit, debit = account_view(e)
                        end
                        total_credit += credit
                        total_debit += debit
                    end
                    puts "-" * 60
                    solde = total_credit - total_debit
                    solde_str = solde > Montant.new(0) ? "💰 +#{solde}" : "🔻 #{solde}"
                    puts format("%-33s %12s %12s", "Total", total_credit, total_debit)
                    puts "Solde: #{solde_str}"
                end
            end
        end
    end
end
