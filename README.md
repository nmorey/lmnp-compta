# LMNP Compta

Outil en ligne de commande (CLI) pour gérer une comptabilité LMNP (Loueur Meublé Non Professionnel) au régime réel simplifié.
Écrit en Ruby.

## Fonctionnalités

*   Saisie d'écritures comptables (manuel ou interactif).
*   Import automatique des transactions Airbnb (CSV).
*   Analyse de factures PDF (OCR/Text extraction) pour suggérer des écritures (EDF, Sosh, Copro, Amazon, Entrepôt du Bricolage, etc.).
*   Gestion des amortissements (calcul et génération des écritures de dotation).
*   Calcul et suivi des déficits et ARD (Amortissements Réputés Différés).
*   Génération des liasses fiscales (Aide au remplissage 2033 A/B/C/D).
*   Export FEC (Fichier des Écritures Comptables) conforme pour l'administration fiscale.

## Installation

Nécessite Ruby.
Nécessite `pdftotext` (package `poppler-utils` sur Debian/Ubuntu) pour l'analyse des factures.

1.  Cloner le dépôt.
2.  Construire et installer la gem (ou utiliser `bundle`).
3.  Rendre le binaire exécutable : `chmod +x bin/lmnp`

## Workflow

### 1. Initialisation

Pour commencer une nouvelle année ou un nouveau projet :

```bash
lmnp init --siren 123456789 --annee 2025
```
Cela crée un fichier `lmnp.yaml` et le dossier `data/` nécessaire.

Ensuite, créez votre fichier d'immobilisations :

```bash
lmnp creer-immo --nom "Appartement Mer" --valeur 150000 --date 2024-01-01
```
(Options de ventilation disponibles : `--terrain`, `--gros-oeuvre`, etc.)

### 2. Saisie courante

**Importer des factures (PDF) :**
```bash
lmnp importer-facture mon_fichier.pdf
```
Cela analyse le PDF et affiche une commande `lmnp ajouter ...` suggérée.
Si le format du PDF n'est pas reconnu :
1. L'outil vérifie si un fichier `.yaml` correspondant existe (ex: `mon_fichier.pdf.yaml`).
2. Sinon, il crée un modèle `mon_fichier.pdf.yaml.tpl`. Vous pouvez le remplir, le renommer en `.yaml` et relancer la commande.

**Importer Airbnb (CSV) :**
```bash
lmnp importer-airbnb -f listings.csv
```

**Saisie manuelle :**
```bash
lmnp ajouter
```
(Mode interactif)

Ou en ligne de commande :
```bash
lmnp ajouter -d 2025-01-27 -j AC -l "Facture X" -r "REF123" -f "facture.pdf" -c 606000 -s D -m 100 -c 512000 -s C -m 100
```

## Consultation / Rapports

### Afficher le statut des flux bancaires
```bash
lmnp status
```
Affiche un récapitulatif des entrées et sorties d'argent sur le compte bancaire (compte 512000) pour l'année fiscale en cours. Le résultat est affiché au format CSV (tab-séparé) pour faciliter l'analyse dans un tableur.

### 3. Fin d'année

**Calculer les amortissements :**
```bash
lmnp amortir
```
Utilise le fichier `data/immobilisations.yaml` pour générer l'écriture de dotation aux amortissements.

**Clôture de trésorerie :**
```bash
lmnp cloturer
```
Génère l'écriture de régularisation du compte bancaire (Apport personnel ou Prélèvement de l'exploitant).

**Génération de la liasse :**
```bash
lmnp liasse
```
Affiche les montants à reporter sur votre déclaration 2033 et met à jour les stocks de déficits/ARD dans `data/stock_fiscal.yaml`.

**Export FEC :**
```bash
lmnp export-fec
```
Génère le fichier texte pour l'administration fiscale.

## Configuration

Le fichier `lmnp.yaml` contient la configuration :

```yaml
siren: "952310852"
annee: 2025
data_dir: "data"
journal_file: "journal.yaml"
stock_file: "stock_fiscal.yaml"
immo_file: "immobilisations.yaml"
extra_invoice_dir: "my_parsers/" # Optionnel
```

## Structure des données

*   **Journal** (`data/YYYY/journal.yaml`) : Toutes les écritures comptables.
*   **Immobilisations** (`data/immobilisations.yaml`) : Liste des biens et composants amortissables.
*   **Stock** (`data/YYYY/stock_fiscal.yaml`) : Suivi des déficits reportables et ARD.

## Autocomplétion Bash

Sourcez le script de complétion pour bénéficier de l'autocomplétion des commandes :

```bash
source lmnp-completion.bash
```
