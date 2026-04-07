require 'date'

module LMNPCompta
    module Amortization
        def self.calcul_dotation(valeur, duree, date_start, annee)
            return Montant.new(0) if duree <= 0
            val_mnt = Montant.new(valeur)
            taux = 1.0 / duree
            dotation = val_mnt * taux

            d_start = Date.parse(date_start.to_s)
            return Montant.new(0) if annee < d_start.year

            total_jours_amort = (duree * 360).to_i

            if annee == d_start.year
                jours_deja = 0
                max_jours = (30 - [d_start.day, 30].min + 1) + (12 - d_start.month) * 30
            else
                jours_an1 = (30 - [d_start.day, 30].min + 1) + (12 - d_start.month) * 30
                annees_pleines = annee - d_start.year - 1
                jours_deja = jours_an1 + (annees_pleines * 360)
                max_jours = 360
            end

            return Montant.new(0) if jours_deja >= total_jours_amort

            jours_restants = total_jours_amort - jours_deja
            jours_ex = [max_jours, jours_restants].min

            return Montant.new(0) if jours_ex <= 0

            jours_ex == 360 ? dotation : (dotation * (jours_ex.to_f / 360.0))
        end
    end
end
