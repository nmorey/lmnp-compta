require 'lmnp_compta/command'
require 'lmnp_compta/journal'
require 'lmnp_compta/entry'
require 'lmnp_compta/plan_comptable'
require 'readline'
require 'optparse'

module LMNPCompta
    module Commands
        class AddEntry < Command
            register 'ajouter', 'Ajouter une nouvelle écriture manuellement ou interactivement'

            VALIDATORS = {
                date: ->(input) {
                    begin
                        d = Date.parse(input)
                        return d.to_s
                    rescue Date::Error, ArgumentError
                        return nil
                    end
                },
                journal: ->(input) {
                    code = input.upcase
                    LMNPCompta::JOURNAUX.key?(code) ? code : nil
                },
                compte: ->(input) {
                    clean = input.to_s.gsub(/\s+/, "")
                    (clean.match?(/^\d+$/)) ? clean : nil
                },
                montant: ->(input) {
                    val = Montant.new(input)
                    val > Montant.new(0) ? val : nil
                },
                sens: ->(input) {
                    s = input.to_s.upcase
                    ["D", "C"].include?(s) ? s : nil
                },
                libelle: ->(input) {
                    input.length > 2 ? input : nil
                }
            }

            def execute
                options = { lines: [] }
                OptionParser.new do |opts|
                    opts.banner = "Usage: lmnp ajouter [options]"

                    opts.on("-d", "--date DATE", "Date (JJ/MM/AAAA)") { |v| options[:date] = v }
                    opts.on("-j", "--journal CODE", "Journal (BQ, HA...)") { |v| options[:journal] = v }
                    opts.on("-l", "--libelle TEXTE", "Libellé global") { |v| options[:libelle] = v }
                    opts.on("-r", "--ref REF", "Référence pièce") { |v| options[:ref] = v }

                    opts.on("-c", "--compte COMPTE", "Ajoute une ligne: Compte") do |v|
                        options[:lines] << { raw_compte: v }
                    end

                    opts.on("-m", "--montant MONTANT", "Ajoute une ligne: Montant") do |v|
                        raise "L'option -m doit être précédée d'un -c <compte>" if options[:lines].empty?
                        options[:lines].last[:raw_montant] = v
                    end

                    opts.on("-s", "--sens SENS", "Ajoute une ligne: Sens (D/C)") do |v|
                        raise "L'option -s doit être précédée d'un -c <compte>" if options[:lines].empty?
                        options[:lines].last[:raw_sens] = v
                    end
                end.parse!(@args)

                journal_file = LMNPCompta::Settings.instance.journal_file
                journal = LMNPCompta::Journal.new(journal_file, year: LMNPCompta::Settings.instance.annee)
                puts "\n=== NOUVELLE ÉCRITURE (ID: #{journal.next_id}) ==="

                entry = if options[:lines].any?
                            process_cli_mode(options)
                        else
                            process_interactive_mode(options)
                        end

                journal.add_entry(entry)
                journal.save!
                puts "\n✅ Écriture #{entry.id} enregistrée dans #{journal_file}."
            end

            private

            def prompt(q, default: nil, cast_to: nil, help: nil)
                suffix = help ? " (? pour aide)" : ""
                l = default ? "#{q} [#{default}]#{suffix}: " : "#{q}#{suffix}: "
                formatted_prompt = "\001\e[1m\002#{l}\001\e[0m\002"

                loop do
                    line = Readline.readline(formatted_prompt, true)
                    return nil if line.nil? # Ctrl+D

                    input = line.strip

                    if input == '?' && help
                        puts "\n  --- \e[34mAIDE DISPONIBLE\e[0m ---"
                        help.call
                        puts "  -------------------------"
                        next
                    end

                    input = default.to_s if input.empty? && default

                    if block_given?
                        is_valid = yield(input)
                        unless is_valid
                            next
                        end
                    end

                    return input
                end
            end

            def process_cli_mode(options)
                puts "⚙️  Mode Commande (Strict)"

                date_val = VALIDATORS[:date].call(options[:date] || Date.today.to_s)
                raise "Date invalide ou manquante." unless date_val

                journal_val = VALIDATORS[:journal].call(options[:journal] || "BQ")
                raise "Journal invalide (#{options[:journal]})." unless journal_val

                libelle_val = VALIDATORS[:libelle].call(options[:libelle] || "")
                raise "Le libellé est obligatoire et doit faire > 2 caractères." unless libelle_val

                ref_val = options[:ref] || "N/A"

                entry = LMNPCompta::Entry.new(
                    date: date_val,
                    journal: journal_val,
                    libelle: libelle_val,
                    ref: ref_val
                )

                options[:lines].each_with_index do |l, idx|
                    raise "Ligne #{idx+1}: Il manque des infos (Compte, Montant ET Sens obligatoires)." unless l[:raw_compte] && l[:raw_montant] && l[:raw_sens]

                    c_ok = VALIDATORS[:compte].call(l[:raw_compte])
                    raise "Ligne #{idx+1}: Compte '#{l[:raw_compte]}' invalide." unless c_ok

                    m_ok = VALIDATORS[:montant].call(l[:raw_montant])
                    raise "Ligne #{idx+1}: Montant '#{l[:raw_montant]}' invalide." unless m_ok

                    s_ok = VALIDATORS[:sens].call(l[:raw_sens])
                    raise "Ligne #{idx+1}: Sens '#{l[:raw_sens]}' invalide (D ou C)." unless s_ok

                    if s_ok == "D"
                        entry.add_debit(c_ok, m_ok)
                    else
                        entry.add_credit(c_ok, m_ok)
                    end

                    acc_name = LMNPCompta::PLAN_COMPTABLE[c_ok] ? "(#{LMNPCompta::PLAN_COMPTABLE[c_ok] })" : ""
                    puts "   Ligne #{idx+1}: #{c_ok} #{acc_name} | #{s_ok} | #{m_ok} €"
                end

                unless entry.balanced?
                    raise "L'écriture n'est pas équilibrée (Déséquilibre: #{entry.balance} €)."
                end

                entry
            end

            def process_interactive_mode(options)
                puts "🖐  Mode Interactif"

                d_def = options[:date] ? VALIDATORS[:date].call(options[:date]) : Date.today.strftime("%d/%m/%Y")
                date_in = prompt("Date (JJ/MM/AAAA)", default: d_def) do |input|
                    res = VALIDATORS[:date].call(input)
                    input.replace(res) if res
                    !!res
                end

                help_j = -> { LMNPCompta::JOURNAUX.each { |c, d| puts "  #{c}: #{d}" } }
                journal_in = prompt("Journal", default: (options[:journal] || "BQ"), help: help_j) do |input|
                    !!VALIDATORS[:journal].call(input)
                end.upcase

                libelle_in = prompt("Libellé", default: options[:libelle]) { |i| !!VALIDATORS[:libelle].call(i) }

                entry = LMNPCompta::Entry.new(
                    date: date_in,
                    journal: journal_in,
                    libelle: libelle_in,
                    ref: "N/A"
                )

                loop do
                    bal = entry.balance
                    if bal.zero? && !entry.lines.empty?
                        puts "\n--- \e[32mÉquilibré\e[0m ---"
                        break if prompt("Enregistrer ? (O/N)", default: "O") { |i| ["O","N"].include?(i.upcase) }.upcase == "O"
                    elsif !entry.lines.empty?
                        puts "\n--- Déséquilibre: \e[31m#{bal} €\e[0m ---"
                    end

                    help_c = -> { LMNPCompta::PLAN_COMPTABLE.sort.each { |n, nm| puts "  #{n}: #{nm}" } }
                    compte = prompt("Compte", help: help_c) do |input|
                        clean = VALIDATORS[:compte].call(input)
                        input.replace(clean) if clean
                        !!clean
                    end

                    if LMNPCompta::PLAN_COMPTABLE[compte]
                        puts "  -> \e[36m#{LMNPCompta::PLAN_COMPTABLE[compte]}\e[0m"
                    else
                        puts "  -> \e[33m(Nouveau compte)\e[0m"
                    end

                    def_sens = bal > Montant.new(0) ? "C" : "D"
                    type = prompt("D/C", default: def_sens) { |i| !!VALIDATORS[:sens].call(i) }.upcase

                    def_mnt = bal.zero? ? Montant.new(0) : bal.abs
                    montant = prompt("Montant", default: def_mnt, cast_to: nil) { |i| !!VALIDATORS[:montant].call(i) }

                    if type == "D"
                        entry.add_debit(compte, montant)
                    else
                        entry.add_credit(compte, montant)
                    end
                end

                entry
            end
        end
    end
end
