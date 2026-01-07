require_relative 'base'

require_relative '../amortization'
require_relative 'opening_balance'

module LMNPCompta
    module Fiscal
        class Year2025 < Base
            def initialize(entries, assets, stock, year)
                super
                @opening = OpeningBalance.new(assets, year)
                categorize_accounts
            end

            # --- BILAN (2033-A) ---

            def tresorerie
                sum_prefix('5')
            end

            # Actif : Clients et Comptes rattachés (Box 068)
            def creances_clients
                @creances_clients
            end

            # Actif : Autres créances (Box 072)
            def autres_creances
                @autres_creances
            end

            # Passif : Emprunts (Box 156)
            def emprunts
                -sum_prefix('16')
            end

            # Passif : Fournisseurs (Box 166)
            def dettes_fournisseurs
                @dettes_fournisseurs
            end

            # Passif : Dettes fiscales et sociales (Box 169)
            def dettes_fiscales_sociales
                @dettes_fiscales_sociales
            end

            # Passif : Autres dettes (Box 172)
            def autres_dettes
                @autres_dettes
            end

            def capital
                # Capital Fin = Capital Début (calculé par OpeningBalance) + Mouvements de l'exploitant (108)
                mouvements_exploitant = sum_prefix('108')
                @opening.capital_start - mouvements_exploitant
            end

            # --- COMPTE DE RÉSULTAT (2033-B) ---

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

            def chiffre_affaires
                -sum_prefix('70')
            end

            def achats_matieres
                # Box 238: Achats de marchandises (607) et matières premières (601)
                sum_prefix('60') - sum_prefix('606')
            end

            def autres_charges_externes
                # Box 242: Autres charges externes (606 + 61 + 62)
                sum_prefix('606') + sum_prefix('61') + sum_prefix('62')
            end

            def impots_taxes
                sum_prefix('63')
            end

            # --- IMMOBILISATIONS ---

            def immo_brut
                total = Montant.new(0)
                @assets.each do |asset_data|
                    comps = asset_data.is_a?(Hash) ? asset_data['composants'] : asset_data.composants
                    comps.each do |c|
                        val = c.is_a?(Hash) ? c['valeur'] : c.valeur
                        total += val
                    end
                end
                total
            end

            def amort_cumules
                dotation_annee = Montant.new(0)
                @assets.each do |asset_data|
                    start_date = asset_data.date_mise_en_location
                    comps = asset_data.composants
                    comps.each do |c|
                        valeur = c.valeur
                        duree = c.duree
                        dotation_annee += Amortization.calcul_dotation(valeur, duree, start_date, @year)
                    end
                end
                @opening.amort_cumules_start + dotation_annee
            end

            # --- ANALYSE FISCALE ---

            def analyze
                return @analysis_result if @analysis_result

                # 1. Résultat Comptable avant amortissement
                resultat_avant_amort = recettes - (charges_exploit + charges_fi)

                # 2. Limite de déduction des amortissements
                limite_deduction = [resultat_avant_amort, Montant.new(0)].max
                amort_deductible = [limite_deduction, dotations].min

                ard_cree = dotations - amort_deductible
                resultat_fiscal_intermediaire = resultat_avant_amort - amort_deductible

                # 3. Utilisation des stocks
                ard_utilise = Montant.new(0)
                stock_ard_dispo = @stock.ard

                if resultat_fiscal_intermediaire > Montant.new(0) && stock_ard_dispo > Montant.new(0)
                    ard_utilise = [resultat_fiscal_intermediaire, stock_ard_dispo].min
                    resultat_fiscal_intermediaire -= ard_utilise
                end

                deficit_utilise = Montant.new(0)
                stock_deficit_dispo = @stock.deficit

                # Résultat Fiscal AVANT Imputation des Déficits (Box 352/354)
                # Note : ARD utilisé est déduit AVANT le déficit.
                resultat_avant_deficit = resultat_fiscal_intermediaire

                if resultat_avant_deficit > Montant.new(0) && stock_deficit_dispo > Montant.new(0)
                    deficit_utilise = [resultat_avant_deficit, stock_deficit_dispo].min
                    resultat_fiscal_intermediaire -= deficit_utilise
                end

                # 4. Nouveaux stocks
                @nouveau_stock_ard = stock_ard_dispo + ard_cree - ard_utilise

                deficit_cree = (resultat_avant_amort < Montant.new(0)) ? resultat_avant_amort.abs : Montant.new(0)
                @nouveau_stock_deficit = stock_deficit_dispo + deficit_cree - deficit_utilise

                @resultat_fiscal_final = resultat_fiscal_intermediaire

                @analysis_result = {
                    resultat_avant_amort: resultat_avant_amort,
                    limite_deduction: limite_deduction,
                    amort_deductible: amort_deductible,
                    ard_cree: ard_cree,
                    ard_utilise: ard_utilise,
                    resultat_avant_deficit: resultat_avant_deficit,
                    deficit_utilise: deficit_utilise,
                    deficit_cree: deficit_cree,
                    stock_ard_debut: stock_ard_dispo,
                    stock_deficit_debut: stock_deficit_dispo,
                    stock_ard_fin: @nouveau_stock_ard,
                    stock_deficit_fin: @nouveau_stock_deficit,
                    resultat_fiscal: @resultat_fiscal_final
                }
            end

            def stock_update_data
                analyze unless @analysis_result
                Stock.new({
                    'ard' => @nouveau_stock_ard.to_f,
                    'deficit' => @nouveau_stock_deficit.to_f
                })
            end

            def generate_report
                result = analyze
                doc = Reporting::Document.new("AIDE À LA DÉCLARATION LMNP (Année #{@year})")

                # --- 2033-A (BILAN) ---
                form_a = Reporting::Form.new("FORMULAIRE 2033-A (Bilan Actif / Passif)")

                actif = Reporting::Section.new("ACTIF")
                val_immo_brut = immo_brut.round
                val_amort_cumules = amort_cumules.round
                actif.add_box("028", "Immobilisations Corporelles (Brut)", val_immo_brut)
                actif.add_box("030", "Amortissements corporelles (à déduire)", val_amort_cumules)

                val_immo_net = val_immo_brut - val_amort_cumules
                actif.add_box("032", "Immobilisations Corporelles (Net)", val_immo_net)

                tresorerie_r = tresorerie.round
                creances_clients_r = @creances_clients.round
                autres_creances_r = @autres_creances.round

                actif.add_box("084", "Trésorerie & Disponibilités (Banque)", tresorerie_r)
                actif.add_box("068", "Créances clients et comptes rattachés", creances_clients_r) if @creances_clients > Montant.new(0)
                actif.add_box("072", "Autres créances (TVA, État...)", autres_creances_r) if @autres_creances > Montant.new(0)

                total_actif_brut = val_immo_brut + tresorerie_r + creances_clients_r + autres_creances_r
                total_actif_net = val_immo_net + tresorerie_r + creances_clients_r + autres_creances_r

                actif.add_text("--- TOTAUX ACTIF ---")
                actif.add_box("110", "Total Général ACTIF (Brut)", total_actif_brut)
                actif.add_box("112", "Total Général ACTIF (Net)", total_actif_net)
                form_a.add_section(actif)

                passif = Reporting::Section.new("PASSIF (Avant répartition du résultat)")

                # Capital
                mouv_expl = sum_prefix('108')
                passif.add_text("  > Capital Initial (Au 01/01) .... : #{@opening.capital_start.round.rjust(10)} €")
                passif.add_text("  > Apports / Retraits (108) ...... : -#{mouv_expl.round.rjust(10)} €")

                capital_r = capital.round
                passif.add_box("120", "Capital & Report à nouveau", capital_r)

                # Résultat
                rc = resultat_comptable.round
                passif.add_box("136", "Résultat de l'exercice (Bénéfice ou Perte)", rc)

                total_capitaux = capital_r + rc
                passif.add_box("142", "Total Capitaux Propres", total_capitaux)

                # Dettes
                emprunts_r = emprunts.round
                dettes_fournisseurs_r = @dettes_fournisseurs.round
                dettes_fiscales_sociales_r = @dettes_fiscales_sociales.round
                autres_dettes_r = @autres_dettes.round

                passif.add_box("156", "Emprunts et dettes assimilées", emprunts_r)
                passif.add_box("166", "Fournisseurs et comptes rattachés", dettes_fournisseurs_r) if @dettes_fournisseurs > Montant.new(0)
                passif.add_box("169", "Dettes fiscales et sociales", dettes_fiscales_sociales_r) if @dettes_fiscales_sociales > Montant.new(0)
                passif.add_box("172", "Autres dettes", autres_dettes_r) if @autres_dettes > Montant.new(0)

                total_dettes = emprunts_r + dettes_fournisseurs_r + dettes_fiscales_sociales_r + autres_dettes_r
                total_passif = total_capitaux + total_dettes

                passif.add_text("--- TOTAUX PASSIF ---")
                passif.add_box("180", "Total Général PASSIF", total_passif)
                form_a.add_section(passif)
                doc.add_form(form_a)

                # --- 2033-B (COMPTE DE RESULTAT) ---
                form_b = Reporting::Form.new("FORMULAIRE 2033-B (Compte de résultat)")
                res = Reporting::Section.new("A. RÉSULTAT COMPTABLE")

                ca = chiffre_affaires.round
                res.add_box("218", "Chiffre d'affaires (Loyers)", ca)
                res.add_box("232", "Total produits d'exploitation hors TVA", ca)

                achats = achats_matieres.round
                ext = autres_charges_externes.round
                imp = impots_taxes.round
                dot = dotations.round

                res.add_box("238", "Achats de matières/approvisionnements", achats)
                res.add_box("242", "Autres charges externes", ext)
                res.add_box("244", "Impôts et Taxes", imp)
                res.add_box("254", "Dotations aux amortissements", dot)

                total_charges_exploit = achats + ext + imp + dot
                res.add_box("264", "Total charges d'exploitation", total_charges_exploit)

                res_exploit = ca - total_charges_exploit
                res.add_box("270", "Résultat d'exploitation", res_exploit)

                charges_fi_r = charges_fi.round
                res.add_box("294", "Charges financières (Intérêts)", charges_fi_r)

                if rc >= RoundedMontant.new(0)
                    res.add_box("310", "RÉSULTAT COMPTABLE (Bénéfice)", rc)
                    # Report à la section B
                    fiscal = Reporting::Section.new("B. RÉSULTAT FISCAL")
                    fiscal.add_box("312", "Reporter le bénéfice comptable col. 1", rc)
                else
                    res.add_box("310", "RÉSULTAT COMPTABLE (Perte)", rc.abs)
                    # Report à la section B
                    fiscal = Reporting::Section.new("B. RÉSULTAT FISCAL")
                    fiscal.add_box("314", "Reporter le déficit comptable col. 2", rc.abs)
                end
                form_b.add_section(res)

                # Suite Section Fiscale

                # Réintégrations
                reint = result[:ard_cree].round
                fiscal.add_box("318", "Réintégrations (Amort. excédentaires / ARD créés)", reint) if reint > RoundedMontant.new(0)

                # Déductions
                deduc = result[:ard_utilise].round
                fiscal.add_box("350", "Déductions (Divers / ARD utilisés)", deduc) if deduc > RoundedMontant.new(0)

                # Résultat avant déficit
                res_avant_def = result[:resultat_avant_deficit].round
                if res_avant_def >= RoundedMontant.new(0)
                    fiscal.add_box("352", "Résultat fiscal avant imputation déficits (Bénéfice)", res_avant_def)
                else
                    fiscal.add_box("354", "Résultat fiscal avant imputation déficits (Déficit)", res_avant_def.abs)
                end

                # Déficit imputé
                def_imp = result[:deficit_utilise].round
                fiscal.add_box("360", "Déficits antérieurs imputés", def_imp) if def_imp > RoundedMontant.new(0)

                # Final
                final_val = result[:resultat_fiscal].round
                if final_val >= RoundedMontant.new(0)
                    fiscal.add_box("370", "BÉNÉFICE FISCAL FINAL", final_val)
                else
                    fiscal.add_box("372", "DÉFICIT FISCAL FINAL", final_val.abs)
                end
                form_b.add_section(fiscal)
                doc.add_form(form_b)

                # --- 2033-C (IMMOBILISATIONS) ---
                form_c = Reporting::Form.new("FORMULAIRE 2033-C (Immobilisations & Amortissements)")

                generate_form_c_content(form_c)
                doc.add_form(form_c)

                # --- 2033-D (DEFICITS) ---
                form_d = Reporting::Form.new("FORMULAIRE 2033-D (Suivi des Déficits)")

                s_def = Reporting::Section.new("II. Suivi des Déficits")
                s_def.add_box("982", "Déficits reportables au début de l'exercice", result[:stock_deficit_debut].round)
                s_def.add_box("983", "Déficits imputés sur le résultat (Box 360)", result[:deficit_utilise].round)
                if result[:deficit_cree] > Montant.new(0)
                     s_def.add_box("860", "Déficits de l'exercice (Si Box 354)", result[:deficit_cree].round)
                end
                s_def.add_box("984", "Déficits reportables en fin d'exercice", result[:stock_deficit_fin].round)
                form_d.add_section(s_def)

                # Divers (Box 399)
                s_div = Reporting::Section.new("III. DIVERS")
                if mouv_expl > Montant.new(0)
                    s_div.add_box("399", "Montant des prélèvements personnels", mouv_expl.round)
                end
                form_d.add_section(s_div)

                doc.add_form(form_d)

                # --- ANNEXE ARD ---
                form_ard = Reporting::Form.new("ANNEXE - SUIVI DES ARD (Hors Liasse)")
                s_ard = Reporting::Section.new("Stocks d'Amortissements Réputés Différés")
                s_ard.add_info("Stock ARD début exercice", result[:stock_ard_debut].round)
                s_ard.add_info("+ ARD créé (Box 318)", result[:ard_cree].round)
                s_ard.add_info("- ARD utilisé (Box 350)", result[:ard_utilise].round)
                s_ard.add_info("= STOCK ARD FIN D'EXERCICE", result[:stock_ard_fin].round, "<-- À conserver pour l'an prochain")
                form_ard.add_section(s_ard)
                doc.add_form(form_ard)

                doc
            end

            private

            def categorize_accounts
                @creances_clients = Montant.new(0)
                @autres_creances = Montant.new(0)
                @dettes_fournisseurs = Montant.new(0)
                @dettes_fiscales_sociales = Montant.new(0)
                @autres_dettes = Montant.new(0)

                @balances.each do |compte, solde|
                    s = compte.to_s
                    next unless s.start_with?('4')

                    if solde > Montant.new(0)
                        # Solde DEBITEUR -> ACTIF (Créance)
                        if s.start_with?('41')
                            @creances_clients += solde
                        else
                            @autres_creances += solde
                        end
                    elsif solde < Montant.new(0)
                        # Solde CREDITEUR -> PASSIF (Dette)
                        val = solde.abs
                        if s.start_with?('40')
                            @dettes_fournisseurs += val
                        elsif s.start_with?('42') || s.start_with?('43') || s.start_with?('44')
                            @dettes_fiscales_sociales += val
                        else
                            @autres_dettes += val
                        end
                    end
                end
            end

            def generate_form_c_content(form_c)
                data_c = {
                    terrains: { label: "Terrains (211)", codes: %w[420 422 426 510 512 516] },
                    constructions: { label: "Constructions (213)", codes: %w[430 432 436 520 522 526] },
                    inst_tech: { label: "Inst. Techniques (215)", codes: %w[440 442 446 530 532 536] },
                    inst_gen: { label: "Inst. Générales (2181/212)", codes: %w[450 452 456 540 542 546] },
                    autres: { label: "Autres / Mobilier (2184)", codes: %w[470 472 476 560 562 566] }
                }

                data_c.each do |k, v|
                    v[:brute_start] = Montant.new(0)
                    v[:brute_aug] = Montant.new(0)
                    v[:amort_start] = Montant.new(0)
                    v[:dotation] = Montant.new(0)
                end

                @assets.each do |asset_data|
                    start_date = asset_data.date_mise_en_location
                    comps = asset_data.composants

                    acquisition_year = Date.parse(start_date.to_s).year

                    comps.each do |c|
                        nom = (c.nom).to_s.downcase
                        valeur = c.valeur
                        duree = c.duree

                        cat = :inst_gen
                        if nom.include?('terrain')
                            cat = :terrains
                        elsif nom.include?('gros oeuvre') || nom.include?('façade') || nom.include?('mur') || nom.include?('toiture')
                             cat = :constructions
                        elsif nom.include?('technique') || nom.include?('industriel')
                             cat = :inst_tech
                        elsif nom.include?('meuble') || nom.include?('mobilier')
                             cat = :autres
                        end

                        if acquisition_year == @year
                            data_c[cat][:brute_aug] += valeur
                        else
                            data_c[cat][:brute_start] += valeur
                        end

                        if duree > 0
                            start_year_amort = Date.parse(start_date.to_s).year
                            (start_year_amort...@year).each do |y|
                                data_c[cat][:amort_start] += Amortization.calcul_dotation(valeur, duree, start_date, y)
                            end
                            data_c[cat][:dotation] += Amortization.calcul_dotation(valeur, duree, start_date, @year)
                        end
                    end
                end

                # Totalization variables
                total_brut_debut = RoundedMontant.new(0)
                total_brut_fin = RoundedMontant.new(0)

                cadre_i = Reporting::Section.new("I - IMMOBILISATIONS (Valeur Brute)")
                data_c.each do |k, v|
                    next if v[:brute_start] == Montant.new(0) && v[:brute_aug] == Montant.new(0)

                    # Rounding
                    brute_start_r = v[:brute_start].round
                    brute_aug_r = v[:brute_aug].round
                    brute_fin_r = brute_start_r + brute_aug_r

                    total_brut_debut += brute_start_r
                    total_brut_fin += brute_fin_r

                    cadre_i.add_text("--- #{v[:label]} ---")
                    cadre_i.add_box(v[:codes][0], "Valeur brute début", brute_start_r)
                    cadre_i.add_box(v[:codes][1], "Augmentations", brute_aug_r) if brute_aug_r > RoundedMontant.new(0)
                    cadre_i.add_box(v[:codes][2], "Valeur brute fin", brute_fin_r)
                end

                cadre_i.add_text("--- TOTAUX ---")
                cadre_i.add_box("490", "Total Valeur brute début", total_brut_debut)
                cadre_i.add_box("496", "Total Valeur brute fin", total_brut_fin)

                form_c.add_section(cadre_i)

                cadre_ii = Reporting::Section.new("II - AMORTISSEMENTS")
                total_amort_start = RoundedMontant.new(0)
                total_dotation = RoundedMontant.new(0)

                data_c.each do |k, v|
                    next if v[:amort_start] == Montant.new(0) && v[:dotation] == Montant.new(0)

                    amort_start_r = v[:amort_start].round
                    dotation_r = v[:dotation].round
                    amort_fin_r = amort_start_r + dotation_r

                    total_amort_start += amort_start_r
                    total_dotation += dotation_r

                    cadre_ii.add_text("--- #{v[:label]} ---")
                    cadre_ii.add_box(v[:codes][3], "Amortissements début", amort_start_r)
                    cadre_ii.add_box(v[:codes][4], "Dotations", dotation_r)
                    cadre_ii.add_box(v[:codes][5], "Amortissements fin", amort_fin_r)
                end

                cadre_ii.add_text("--- TOTAL ---")
                cadre_ii.add_box("570", "Total Amort. Début", total_amort_start)
                cadre_ii.add_box("572", "Total Dotations", total_dotation)
                cadre_ii.add_box("576", "Total Amort. Fin", total_amort_start + total_dotation)

                form_c.add_section(cadre_ii)
            end
        end
    end
end
