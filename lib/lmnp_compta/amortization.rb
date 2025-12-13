require 'date'

module LMNPCompta
  module Amortization
    def self.calcul_dotation(valeur, duree, date_start, annee)
      return Montant.new(0) if duree <= 0
      val_mnt = Montant.new(valeur)
      taux = 1.0 / duree
      dotation = val_mnt * taux
      
      d_start = Date.parse(date_start.to_s)
      d_fin_amort = d_start.next_year(duree)
      d_debut_ex = Date.new(annee, 1, 1)
      d_fin_ex = Date.new(annee, 12, 31)
    
      return Montant.new(0) if d_fin_amort <= d_debut_ex || d_start > d_fin_ex
    
      debut_calc = [d_start, d_debut_ex].max
      fin_calc = [d_fin_amort, d_fin_ex].min
      nb_jours = (fin_calc - debut_calc).to_i + 1
      nb_jours_an = (d_fin_ex - d_debut_ex).to_i + 1 # Gère les années bissextiles
    
      (nb_jours == nb_jours_an) ? dotation : (dotation * (nb_jours.to_f / nb_jours_an))
    end
  end
end
