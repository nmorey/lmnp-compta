module LMNPCompta
    # --- CLASSE 2 : IMMOBILISATIONS (Actif) ---
    # ... et autres comptes
    PLAN_COMPTABLE = {
        # --- CLASSE 2 : IMMOBILISATIONS (Actif) ---
        "211000" => "Terrains",
        "212000" => "Agencements et aménagements de terrains",
        "213000" => "Constructions (Murs)",
        "218100" => "Installations générales (Cuisine, SDB)",
        "218300" => "Matériel de bureau et informatique",
        "218400" => "Mobilier (> 500€)",

        # --- AMORTISSEMENTS (Crédit) ---
        "281200" => "Amortissements des agencements",
        "281300" => "Amortissements des constructions",
        "281840" => "Amortissements du mobilier",

        # --- CLASSE 4 : TIERS ---
        "401000" => "Fournisseurs",
        "411000" => "Clients (Locataires)",
        "445000" => "État - TVA",
        "447000" => "Autres impôts, taxes",

        # --- CLASSE 5 : TRÉSORERIE ---
        "512000" => "Banque",
        "530000" => "Caisse",

        # --- CLASSE 6 : CHARGES ---
        "606100" => "Eau, Électricité, Gaz, Chauffage",
        "606300" => "Petit équipement et maintenance < 500€",
        "611000" => "Sous-traitance (Ménage, Conciergerie)",
        "614000" => "Charges locatives de copropriété",
        "615000" => "Entretien et réparations",
        "616000" => "Primes d'assurances (PNO, GLI)",
        "622600" => "Honoraires (Comptable, CGA, Agence)",
        "626000" => "Frais postaux et télécoms",
        "627000" => "Services bancaires",
        "635000" => "Impôts et taxes (Taxe Foncière, CFE)",
        "661000" => "Intérêts d'emprunt",
        "681100" => "Dotations aux amortissements",

        # --- CLASSE 7 : PRODUITS ---
        "706000" => "Prestations de services (Loyers)"
    }

    # Codes journaux autorisés
    JOURNAUX = {
        "BQ" => "Banque (Mouvements financiers)",
        "AC" => "Achats (Factures fournisseurs)",
        "VT" => "Ventes (Quittances de loyer)",
        "OD" => "Opérations Diverses (Amortissements, régularisations)"
    }

    def self.get_compte_lib(compte_num)
        PLAN_COMPTABLE[compte_num.to_s] || "Compte #{compte_num}"
    end
end
