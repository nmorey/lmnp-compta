# LMNP Compta

Outil en ligne de commande (CLI) pour gérer une comptabilité LMNP (Loueur Meublé Non Professionnel) au régime réel simplifié.
Écrit en Ruby.

## Fonctionnalités

*   Saisie d'écritures comptables (manuel ou interactif).
*   Import automatique des transactions Airbnb (CSV).
*   Analyse de factures PDF (OCR/Text extraction) pour suggérer des écritures (EDF, Sosh, Copro, etc.).
*   Gestion des amortissements (calcul et génération des écritures de dotation).
*   Calcul et suivi des déficits et ARD (Amortissements Réputés Différés).
*   Génération des liasses fiscales (Aide au remplissage 2033 A/B/C/D).
*   Export FEC (Fichier des Écritures Comptables) conforme pour l'administration fiscale.

## Installation

Nécessite Ruby.
Nécessite `pdftotext` (package `poppler-utils` sur Debian/Ubuntu) pour l'analyse des factures.

1.  Cloner le dépôt.
2.  Rendre le binaire exécutable : `chmod +x bin/lmnp`
3.  Ajouter le dossier `bin` à votre PATH ou créer un alias.

## Workflow

### 1. Initialisation

Pour commencer une nouvelle année ou un nouveau projet :

```bash
./bin/lmnp init --siren 123456789 --annee 2025
```
Cela crée un fichier `lmnp.yaml` et le dossier `data/` nécessaire.

### 2. Saisie courante

**Importer des factures (PDF) :**
```bash
./bin/lmnp importer-facture mon_fichier.pdf
```
Cela analyse le PDF et affiche une commande `lmnp ajouter ...` suggérée. Vous pouvez la copier-coller ou l'ajuster.

**Importer Airbnb (CSV) :**
```bash
./bin/lmnp importer-airbnb -f listings.csv
```

**Saisie manuelle :**
```bash
./bin/lmnp ajouter
```
(Mode interactif)

### 3. Fin d'année

**Calculer les amortissements :**
```bash
./bin/lmnp amortir
```
Utilise le fichier `data/immobilisations.yaml` pour générer l'écriture de dotation aux amortissements.

**Clôture de trésorerie :**
```bash
./bin/lmnp cloturer
```
Génère l'écriture de régularisation du compte bancaire (Apport personnel ou Prélèvement de l'exploitant) pour solder la banque à 0 (si compte dédié non pro).

**Génération de la liasse :**
```bash
./bin/lmnp liasse
```
Affiche les montants à reporter sur votre déclaration 2033 et met à jour les stocks de déficits/ARD dans `data/stock_fiscal.yaml`.

**Export FEC :**
```bash
./bin/lmnp export-fec
```
Génère le fichier texte pour l'administration fiscale.

## Configuration

Le fichier `lmnp.yaml` contient la configuration :

```yaml
siren: "952310852"
annee: 2025
journal_file: "data/journal_2025.yaml"
stock_file: "data/stock_fiscal.yaml"
immo_file: "data/immobilisations.yaml"
```

## Structure des données

*   **Journal** (`data/journal_YYYY.yaml`) : Toutes les écritures comptables.
*   **Immobilisations** (`data/immobilisations.yaml`) : Liste des biens et composants amortissables.
*   **Stock** (`data/stock_fiscal.yaml`) : Suivi des déficits reportables et ARD.

## Autocomplétion Bash

Sourcez le script de complétion pour bénéficier de l'autocomplétion des commandes :

```bash
source lmnp-completion.bash
```