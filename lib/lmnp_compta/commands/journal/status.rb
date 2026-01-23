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

        def execute
          year = Settings.instance.annee
          journal = LMNPCompta::Journal.new(Settings.instance.journal_file)

          relevant = journal.entries.select do |e|
              Date.parse(e.date.to_s).year == year.to_i && e.lines.any? { |l| l[:compte].to_s == '512000' }
          end

          total_credit = Montant.new(0)
          total_debit = Montant.new(0)

          puts ["Date", "Ref", "Crédit", "Débit"].join("\t")
          relevant.sort_by { |e| e.date.to_s }.each do |e|
              e.lines.select { |l| l[:compte].to_s == '512000' }.each do |l|
                  credit_releve = l[:debit]
                  debit_releve = l[:credit]

                  total_credit += credit_releve
                  total_debit += debit_releve
                  puts [e.date, e.ref, (credit_releve > Montant.new(0) ? credit_releve : '""'), (debit_releve > Montant.new(0) ? debit_releve : '""')].join("\t")
              end
          end
          puts ""
          puts [Date.today, "Total (Solde): #{total_credit - total_debit}", "", total_credit, total_debit].join("\t")
        end
      end
    end
  end
end
