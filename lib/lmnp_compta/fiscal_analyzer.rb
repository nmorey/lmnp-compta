module LMNPCompta
    class FiscalAnalyzer
        def self.new(entries, assets, stock, year)
            # 1. Try to load specific year
            begin
                require_relative "fiscal/year_#{year}"
                klass_name = "LMNPCompta::Fiscal::Year#{year}"
                return Object.const_get(klass_name).new(entries, assets, stock, year)
            rescue LoadError, NameError
                # 2. Fallback to latest
                latest_year = self.latest_available_year
                if latest_year
                    puts "⚠️  Attention : Pas de module fiscal pour #{year}. Utilisation de la version #{latest_year}."
                    require_relative "fiscal/year_#{latest_year}"
                    klass_name = "LMNPCompta::Fiscal::Year#{latest_year}"
                    return Object.const_get(klass_name).new(entries, assets, stock, year)
                else
                    raise "Aucun module fiscal disponible."
                end
            end
        end

        def self.latest_available_year
            files = Dir.glob(File.join(__dir__, 'fiscal', 'year_*.rb'))
            years = files.map { |f| f.match(/year_(\d+)\.rb$/)[1].to_i }
            years.max
        end
    end
end
