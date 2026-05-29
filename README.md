# LMNP Compta

Outil en ligne de commande (CLI) pour gérer une comptabilité LMNP (Loueur Meublé Non Professionnel) au régime réel simplifié.
Écrit en Ruby.

## Fonctionnalités

*   Saisie d'écritures comptables (manuel ou interactif).
*   Import automatique des transactions Airbnb (CSV).
*   Analyse de factures PDF (OCR/Text extraction) pour suggérer des écritures.
*   Gestion des amortissements (calcul et génération des écritures de dotation).
*   Calcul et suivi des déficits et ARD (Amortissements Réputés Différés).
*   Gestion des indemnités kilométriques (véhicules, trajets, calcul fiscal).
*   Génération des liasses fiscales (Aide au remplissage 2033 A/B/C/D).
*   Export FEC (Fichier des Écritures Comptables).

## Installation

Nécessite Ruby.
Nécessite `pdftotext` (package `poppler-utils`) pour l'analyse des factures.

1.  Cloner le dépôt.
2.  Construire/Installer la gem.
3.  `chmod +x bin/lmnp`

## Workflow

### 1. Configuration (`configurer`)

Pour commencer un nouveau projet :

```bash
lmnp configurer init --siren 123456789 --annee 2025
```

Créer une immobilisation :
```bash
lmnp configurer immo --nom "Appartement Mer" --valeur 150000 --date 2024-01-01
```

Gérer les véhicules :
```bash
lmnp configurer vehicules ajouter "Ma Voiture" 5
```

Gérer la blanchisserie :
```bash
lmnp configurer blanchisserie ajouter 1 --nom-bien "Appartement Mer" --conso-eau 0.05 --prix-eau 4.0 --conso-kwh 1.0 --prix-kwh 0.25 --prix-produit 0.5
```

### 2. Journal & Saisie (`journal`)

**Saisie manuelle :**
```bash
lmnp journal saisir
# Ou en ligne de commande
lmnp journal saisir -d 2025-01-27 -j AC -l "Facture X" -m 100 ...
```

**Importer Airbnb (CSV) :**
```bash
lmnp journal importer-airbnb -f listings.csv
# Avec automatisation des écritures de blanchisserie :
lmnp journal importer-airbnb -f listings.csv --blanchisserie 1
```

**Analyser des factures (PDF) :**
```bash
lmnp journal analyser-facture mon_fichier.pdf
```
Génère une commande `lmnp journal saisir ...` à copier-coller.

**Gérer les trajets :**
```bash
lmnp journal trajets ajouter 2025-01-20 "Ma Voiture" 45 "Visite locataire"
```

**Saisie de la blanchisserie :**
```bash
lmnp journal blanchisserie ajouter 1 2025-01-20
```

**Voir le solde bancaire :**
```bash
lmnp journal status
```

### 3. Bilan & Clôture (`bilan`)

**Clôture annuelle :**
```bash
lmnp bilan cloturer
```
Cette commande unique effectue :
1.  Le calcul et l'écriture des **amortissements**.
2.  Le calcul et l'écriture des **indemnités kilométriques**.
3.  Le calcul et l'écriture du **solde de trésorerie** (Compte courant exploitant).
4.  La **vérification d'intégrité** et l'**horodatage RFC 3161** du journal.

Pour exécuter uniquement l'horodatage RFC 3161 du journal sans modifier ni générer d'écritures :
```bash
lmnp bilan cloturer --timestamp-only
```

**Simulation de clôture (Mock mode) :**
```bash
lmnp bilan status
# Pour une année spécifique
lmnp bilan status --year 2024
```
Simule l'exécution de `bilan cloturer` (sans horodatage) et de `bilan liasse` sans modifier aucun fichier.

**Liasse fiscale :**
```bash
lmnp bilan liasse
# Pour une année spécifique (ex: 2024 au lieu de l'année configurée)
lmnp bilan liasse --year 2024
```
Affiche les montants pour la déclaration 2031-SD et 2033 (A/B/C/D) et met à jour le stock de déficits.

**Export FEC :**
```bash
lmnp bilan fec
# Optionnel : --year YYYY
lmnp bilan fec --year 2024
```

## Structure des données

*   **Journal** (`data/YYYY/journal.yaml`) : Toutes les écritures.
*   **Immobilisations** (`data/immobilisations.yaml`) : Liste des biens.
*   **Véhicules** (`data/vehicles.yaml`) : Liste des véhicules.
*   **Trajets** (`data/YYYY/trips.yaml`) : Liste des trajets.

## Autocomplétion Bash

Sourcez le script pour l'autocomplétion :
```bash
source lmnp-completion.bash
```

## Développement

Règles à suivre pour contribuer au projet :

1.  **Langues** :
    *   Interface Utilisateur (CLI, Aide, Sorties) : **Français**.
    *   Code interne (Variables, Commentaires, Commits) : **Anglais**.
2.  **Tests** :
    *   Toujours lancer `rake` pour exécuter la suite de tests.
    *   Tout ajout de fonctionnalité doit être couvert par un test.
3.  **Documentation** :
    *   Mettre à jour le `README.md`.
    *   Mettre à jour l'autocomplétion.
4.  **Style de code** :
    *   Pas d'indentation sur les lignes vides (trailing whitespace).