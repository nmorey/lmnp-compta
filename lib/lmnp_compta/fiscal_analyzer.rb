module LMNPCompta
    # Factory pour instancier le bon analyseur fiscal selon l'année
    class FiscalAnalyzer
        # Crée une instance de l'analyseur fiscal approprié
        # @param entries [Array<Entry>] Les écritures comptables
        # @param assets [Array<Asset>] Les immobilisations
        # @param stock [Hash] Les stocks fiscaux (déficits, ARD)
        # @param year [Integer] L'année fiscale
        def self.new(entries, assets, stock, year)
            # 1. Essayer de charger l'année spécifique
            begin
                require_relative "fiscal/year_#{year}"
                klass_name = "Fiscal::Year#{year}"
                return Object.const_get(klass_name).new(entries, assets, stock, year)
            rescue LoadError, NameError
                # 2. Repli sur la dernière année disponible
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

        # Détermine la dernière année fiscale disponible dans la gem
        # @return [Integer] L'année la plus récente
        def self.latest_available_year
            files = Dir.glob(File.join(__dir__, 'fiscal', 'year_*.rb'))
            years = files.map { |f| f.match(/year_(\d+)\.rb$/)[1].to_i }
            years.max
        end
    end
end
