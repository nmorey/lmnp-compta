require_relative 'base'

module LMNPCompta
    module Fiscal
        class Year2025 < Base
            def tresorerie
                sum_prefix('5')
            end

            def creances
                sum_prefix('4')
            end

            def capital
                -sum_prefix('10') - sum_prefix('11')
            end

            def emprunts
                -sum_prefix('16')
            end

            def dettes_fournisseurs
                -sum_prefix('40')
            end

            def recettes
                -(sum_prefix('70') + sum_prefix('75') + sum_prefix('79'))
            end

            def charges_exploit
                sum_prefix('60') + sum_prefix('61') + sum_prefix('62') +
                    sum_prefix('63') + sum_prefix('64') + sum_prefix('65')
            end

            def charges_fi
                sum_prefix('66')
            end

            def dotations
                sum_prefix('68')
            end

            def immo_brut
                sum_prefix('20') + sum_prefix('21')
            end

            def amort_cumules
                -sum_prefix('28')
            end

            def analyze
                # 1. Résultat Comptable avant amortissement
                resultat_avant_amort = recettes - (charges_exploit + charges_fi)

                # 2. Limite de déduction des amortissements
                limite_deduction = [resultat_avant_amort, Montant.new(0)].max
                amort_deductible = [limite_deduction, dotations].min

                ard_cree = dotations - amort_deductible
                resultat_fiscal_intermediaire = resultat_avant_amort - amort_deductible

                # 3. Utilisation des stocks
                ard_utilise = Montant.new(0)
                stock_ard_dispo = Montant.new(@stock['stock_ard'].to_s)

                if resultat_fiscal_intermediaire > Montant.new(0) && stock_ard_dispo > Montant.new(0)
                    ard_utilise = [resultat_fiscal_intermediaire, stock_ard_dispo].min
                    resultat_fiscal_intermediaire -= ard_utilise
                end

                deficit_utilise = Montant.new(0)
                stock_deficit_dispo = Montant.new(@stock['stock_deficit'].to_s)

                if resultat_fiscal_intermediaire > Montant.new(0) && stock_deficit_dispo > Montant.new(0)
                    deficit_utilise = [resultat_fiscal_intermediaire, stock_deficit_dispo].min
                    resultat_fiscal_intermediaire -= deficit_utilise
                end

                # 4. Nouveaux stocks
                @nouveau_stock_ard = stock_ard_dispo + ard_cree - ard_utilise

                deficit_cree = (resultat_avant_amort < Montant.new(0)) ? resultat_avant_amort.abs : Montant.new(0)
                @nouveau_stock_deficit = stock_deficit_dispo + deficit_cree - deficit_utilise

                @resultat_fiscal_final = resultat_fiscal_intermediaire

                {
                    resultat_avant_amort: resultat_avant_amort,
                    limite_deduction: limite_deduction,
                    amort_deductible: amort_deductible,
                    ard_cree: ard_cree,
                    ard_utilise: ard_utilise,
                    deficit_utilise: deficit_utilise,
                    deficit_cree: deficit_cree,
                    stock_ard_debut: stock_ard_dispo,
                    stock_deficit_debut: stock_deficit_dispo,
                    stock_ard_fin: @nouveau_stock_ard,
                    stock_deficit_fin: @nouveau_stock_deficit,
                    resultat_fiscal: @resultat_fiscal_final
                }
            end
        end
    end
end
