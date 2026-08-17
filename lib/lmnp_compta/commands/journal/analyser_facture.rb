require 'lmnp_compta/commands/journal/sub_command'
require 'lmnp_compta/invoice'
require 'optparse'

module LMNPCompta
  module Commands
    module Journal
      class AnalyserFacture < SubCommand
        register 'analyser-facture', 'Analyser des PDF pour suggérer des écritures'

        def execute
           options = { type: nil, interactive: true }
           parser = OptionParser.new do |opts|
               opts.banner = "Usage: lmnp journal analyser-facture [options] <pdf>..."
               opts.on("-t", "--type TYPE", "Forcer le type") { |t| options[:type] = t.downcase.to_sym }
               opts.on("--amortize-duration N", Integer) { |n| options[:amortize_duration] = n }
               opts.on("--no-amortize") { options[:no_amortize] = true }
           end
           parser.parse!(@args)

           if @args.empty?
               puts parser
               return
           end

           errors = 0
           entries_list = []

           @args.each do |file_path|
               process_file(file_path, options, entries_list)
           rescue => e
               entry = Entry.new(
                   file: File.basename(file_path),
                   libelle: "Error: #{file_path}",
                   error: "# ❌ #{e.message.gsub(/\n/, "\n# ")}"
               )
               add_or_merge_entry(entries_list, entry)
               errors += 1
           end
           entries_list.sort_by! { |x| "#{x.source_file}-#{x.date.to_s().split('/').reverse.join("/")}" }
           entries_list.each { |e| puts format_invoice_entry(e) }
           puts "# #{entries_list.length} transactions, #{errors} erreurs."
        end

        private

        def process_file(file_path, options, entries_list)
            parsed_entries = LMNPCompta::Invoice.parse(file_path, options)
            parsed_entries.each do |entry|
                add_or_merge_entry(entries_list, entry)
            end
        end

        def add_or_merge_entry(list, new_e)
            existing_idx = list.find_index { |e| e.libelle == new_e.libelle }

            if existing_idx
                old_entry = list[existing_idx]
                old_entry.warnings ||= []

                new_e.warnings = old_entry.warnings
                new_e.warnings << "# ⚠️ Warning: Remplacement de la transaction '#{old_entry.libelle}'\n"
                new_e.warnings << "# \t Originale venant de #{old_entry.source_file}\n"
                new_e.warnings << "# \t Remplacante venant de #{new_e.source_file}\n"

                list[existing_idx] = new_e
            else
                list << new_e
            end
        end

        def format_invoice_entry(entry)
            str = "# #{entry.source_file}\n" if entry.source_file
            str ||= ""
            str += entry.error.to_s + "\n" if entry.error
            entry.warnings.each { |msg| str += msg } if entry.warnings
            if entry.valid?
                str += generate_invoice_command(entry)
            end
            str
        end

        def generate_invoice_command(entry)
            cmd_lines = []
            entry.lines.each do |l|
                if l[:debit] > Montant.new(0)
                    cmd_lines << "-c #{l[:compte]} -s D -m #{l[:debit]}"
                elsif l[:credit] > Montant.new(0)
                    cmd_lines << "-c #{l[:compte]} -s C -m #{l[:credit]}"
                end
            end

            date_str = ""
            begin
                date_obj = if entry.date.is_a?(Date)
                    entry.date
                elsif entry.date.to_s.include?('/')
                    parts = entry.date.to_s.split('/')
                    Date.new(parts[2].to_i, parts[1].to_i, parts[0].to_i)
                else
                    Date.parse(entry.date.to_s)
                end
                date_str = date_obj.strftime('%Y-%m-%d')
            rescue
                date_str = entry.date.to_s
            end

            ref_str = (entry.ref && !entry.ref.to_s.strip.empty? && entry.ref != "N/A") ? "-r \"#{entry.ref}\" " : ""

            [
                "lmnp journal saisir",
                "-d #{date_str}",
                "-j #{entry.journal}",
                "-l \"#{entry.libelle}\"",
                ref_str + "-f \"#{entry.source_file}\"",
                cmd_lines.join(" ")
            ].join(" ")
        end
      end
    end
  end
end
