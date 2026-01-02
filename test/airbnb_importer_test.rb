require 'minitest/autorun'
require_relative '../lib/lmnp_compta/airbnb_importer'
require_relative '../lib/lmnp_compta/journal'
require_relative '../lib/lmnp_compta/entry'

class AirbnbImporterTest < Minitest::Test
  def setup
    @journal_file = "test_journal_airbnb.yaml"
    File.write(@journal_file, [].to_yaml)
    @journal = LMNPCompta::Journal.new(@journal_file)
    @csv_file = "test_airbnb_import.csv"
  end

  def teardown
    File.delete(@journal_file) if File.exist?(@journal_file)
    File.delete(@csv_file) if File.exist?(@csv_file)
  end

  def create_csv(content)
    File.write(@csv_file, content)
  end

  def test_import_nominal
    csv_content = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de départ,Nuits,Hébergement,Ménage,Frais de service,Revenus bruts,Devise
      Payout,01/05/2025,,,,,,,,,
      Réservation,01/01/2025,REF001,01/01/2025,01/05/2025,4,100.00,,0.00,100.00,EUR
    CSV
    create_csv(csv_content)

    importer = LMNPCompta::AirbnbImporter.new(@csv_file, @journal)
    entries = importer.import

    assert_equal 1, entries.length
    assert_equal "REF001-01", entries.first.ref
  end

  def test_duplicate_exact_match_ignored
    # 1. Add an existing entry to the journal
    entry = LMNPCompta::Entry.new(
      date: "2025-01-05",
      ref: "REF001-01",
      libelle: "Airbnb - REF001 (Période 01/01 - 04/01)",
      journal: "VT"
    )
    # Total credit/debit must match logic in Importer
    entry.add_credit("706000", LMNPCompta::Montant.new(100.0), "Revenu Brut")
    entry.add_debit("512000", LMNPCompta::Montant.new(100.0), "Virement Net")
    @journal.add_entry(entry)
    @journal.save!

    # 2. CSV with exact same transaction
    csv_content = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de départ,Nuits,Hébergement,Ménage,Frais de service,Revenus bruts,Devise
      Payout,01/05/2025,,,,,,,,,
      Réservation,01/01/2025,REF001,01/01/2025,01/05/2025,4,100.00,,0.00,100.00,EUR
    CSV
    create_csv(csv_content)

    importer = LMNPCompta::AirbnbImporter.new(@csv_file, @journal)

    out, err = capture_io do
      entries = importer.import
      assert_empty entries, "Should not generate new entries for duplicates"
    end
    assert_match /Transaction déjà présente : REF001-01/, out
  end

  def test_duplicate_conflict_raises_error
    # 1. Add an existing entry with DIFFERENT amount
    entry = LMNPCompta::Entry.new(
      date: "2025-01-05",
      ref: "REF001-01",
      libelle: "Airbnb - REF001",
      journal: "VT"
    )
    entry.add_credit("706000", LMNPCompta::Montant.new(50.0), "Revenu Brut") # 50 vs 100
    entry.add_debit("512000", LMNPCompta::Montant.new(50.0), "Virement Net")
    @journal.add_entry(entry)
    @journal.save!

    # 2. CSV with same ref but different amount (100.00)
    csv_content = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de départ,Nuits,Hébergement,Ménage,Frais de service,Revenus bruts,Devise
      Payout,01/05/2025,,,,,,,,,
      Réservation,01/01/2025,REF001,01/01/2025,01/05/2025,4,100.00,,0.00,100.00,EUR
    CSV
    create_csv(csv_content)

    importer = LMNPCompta::AirbnbImporter.new(@csv_file, @journal)

    assert_raises(RuntimeError) do
       importer.import
    end
  end
end
