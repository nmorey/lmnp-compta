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

  def test_duplicate_amount_generates_new_suffix
    # 1. Add an existing entry with DIFFERENT amount (50.00)
    entry = LMNPCompta::Entry.new(
      date: "2025-01-05",
      ref: "REF001-01",
      libelle: "Airbnb - REF001",
      journal: "VT"
    )
    entry.add_credit("706000", LMNPCompta::Montant.new(50.0), "Revenu Brut")
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
    entries = importer.import

    # Instead of raising an error, it should dynamically assign the -02 suffix!
    assert_equal 1, entries.length
    assert_equal "REF001-02", entries.first.ref
  end

  # Test importing multiple payments for the same reservation in the same CSV
  #
  # @return [void]
  def test_import_multi_payment_same_csv
    csv_content = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de fin,Nuits,Logement,Frais de service,Revenus bruts,Devise
      Réservation,06/16/2026,HM43H5YC8Z,06/15/2026,08/31/2026,77,Studio,50.33,1400.95,EUR
      Réservation,07/16/2026,HM43H5YC8Z,06/15/2026,08/31/2026,77,Studio,79.88,2216.93,EUR
    CSV
    create_csv(csv_content)

    importer = LMNPCompta::AirbnbImporter.new(@csv_file, @journal)
    entries = importer.import

    assert_equal 2, entries.length
    assert_equal ["HM43H5YC8Z-01", "HM43H5YC8Z-02"], entries.map(&:ref)
  end

  # Test importing multiple payments month-by-month
  #
  # @return [void]
  def test_import_multi_payment_separate_months
    # First month import
    csv_month_1 = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de fin,Nuits,Logement,Frais de service,Revenus bruts,Devise
      Réservation,06/16/2026,HM43H5YC8Z,06/15/2026,08/31/2026,77,Studio,50.33,1400.95,EUR
    CSV
    create_csv(csv_month_1)

    importer1 = LMNPCompta::AirbnbImporter.new(@csv_file, @journal)
    entries1 = importer1.import
    assert_equal 1, entries1.length
    assert_equal "HM43H5YC8Z-01", entries1.first.ref

    # Add to journal and save to simulate active state
    @journal.add_entry(entries1.first)
    @journal.save!

    # Second month import (separate CSV)
    csv_month_2 = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de fin,Nuits,Logement,Frais de service,Revenus bruts,Devise
      Réservation,07/16/2026,HM43H5YC8Z,06/15/2026,08/31/2026,77,Studio,79.88,2216.93,EUR
    CSV
    create_csv(csv_month_2)

    importer2 = LMNPCompta::AirbnbImporter.new(@csv_file, @journal)
    entries2 = importer2.import
    assert_equal 1, entries2.length
    assert_equal "HM43H5YC8Z-02", entries2.first.ref
  end

  # Test importing multiple payments when previous payment is in another year's journal
  #
  # @return [void]
  def test_import_multi_payment_cross_years
    # 1. Setup a dummy journals data_dir
    test_data_dir = File.join(__dir__, 'tmp', 'cross_years_test_data')
    FileUtils.rm_rf(test_data_dir)
    FileUtils.mkdir_p(test_data_dir)

    original_data_dir = LMNPCompta::Settings.instance.data_dir
    LMNPCompta::Settings.instance.instance_variable_set(:@data_dir, test_data_dir)

    # 2. Add HM43H5YC8Z-01 to 2025's journal
    entry_2025 = {
      'id' => 1,
      'date' => '2025-12-16',
      'libelle' => 'Airbnb - HM43H5YC8Z-01',
      'ref' => 'HM43H5YC8Z-01',
      'journal' => 'VT',
      'lines' => [
        { 'compte' => '706000', 'credit' => '1400.95', 'debit' => '0.00', 'libelle_ligne' => 'Revenu' },
        { 'compte' => '512000', 'credit' => '0.00', 'debit' => '1400.95', 'libelle_ligne' => 'Virement' }
      ]
    }
    FileUtils.mkdir_p(File.join(test_data_dir, '2025'))
    File.write(File.join(test_data_dir, '2025', 'journal.yaml'), [entry_2025].to_yaml)

    # 3. Import HM43H5YC8Z second payment in 2026
    csv_2026 = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de fin,Nuits,Logement,Frais de service,Revenus bruts,Devise
      Réservation,01/16/2026,HM43H5YC8Z,12/15/2025,02/28/2026,77,Studio,79.88,2216.93,EUR
    CSV
    create_csv(csv_2026)

    # Re-initialize current year active journal for 2026
    current_journal_file = File.join(test_data_dir, '2026_journal.yaml')
    current_journal = LMNPCompta::Journal.new(current_journal_file, year: 2026)

    importer = LMNPCompta::AirbnbImporter.new(@csv_file, current_journal)
    entries = importer.import

    # Cleanup test_data_dir
    FileUtils.rm_rf(test_data_dir)
    LMNPCompta::Settings.instance.instance_variable_set(:@data_dir, original_data_dir)

    assert_equal 1, entries.length
    # Should correctly find the previous year's -01 entry and assign -02 suffix
    assert_equal "HM43H5YC8Z-02", entries.first.ref
  end

  def test_import_resolution_payment
    csv_content = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de fin,Nuits,Hébergement,Détails,Frais de service,Revenus bruts,Devise
      Payout,06/06/2026,,,,,,,,,
      Versement de résolution,06/06/2026,HMRAJCHMQA,06/02/2026,06/05/2026,3,Le Petit Refuge,Remboursement des dommages AirCover,0.00,100.25,EUR
    CSV
    create_csv(csv_content)

    importer = LMNPCompta::AirbnbImporter.new(@csv_file, @journal)
    entries = importer.import

    assert_equal 1, entries.length
    entry = entries.first
    assert_equal "HMRAJCHMQA-RES-01", entry.ref
    assert_equal "Airbnb - Résolution HMRAJCHMQA-RES-01 (Remboursement des dommages AirCover)", entry.libelle

    # Verify accounts mapped
    credit_line = entry.lines.find { |l| l[:credit] > LMNPCompta::Montant.new(0) }
    assert_equal LMNPCompta::COMPTE["Produits divers de gestion courante"], credit_line[:compte]
    assert_equal LMNPCompta::Montant.new("100.25"), credit_line[:credit]

    debit_line = entry.lines.find { |l| l[:compte] == LMNPCompta::COMPTE["Banque"] }
    assert_equal LMNPCompta::Montant.new("100.25"), debit_line[:debit]
  end

  def test_import_resolution_payment_same_date_as_booking
    csv_content = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de fin,Nuits,Hébergement,Détails,Frais de service,Revenus bruts,Devise
      Payout,06/06/2026,,,,,,,,,
      Réservation,06/06/2026,HMFEPSHPWD,06/02/2026,06/05/2026,3,Le Petit Refuge,,3.24,85.00,EUR
      Versement de résolution,06/06/2026,HMFEPSHPWD,06/02/2026,06/05/2026,3,Le Petit Refuge,Remboursement des dommages AirCover,0.00,10.00,EUR
    CSV
    create_csv(csv_content)

    importer = LMNPCompta::AirbnbImporter.new(@csv_file, @journal)
    entries = importer.import

    assert_equal 2, entries.length

    booking_entry = entries.find { |e| e.ref == "HMFEPSHPWD-01" }
    refute_nil booking_entry
    assert_equal "Airbnb - HMFEPSHPWD-01 (Période 06/06 - 05/06)", booking_entry.libelle

    resolution_entry = entries.find { |e| e.ref == "HMFEPSHPWD-RES-01" }
    refute_nil resolution_entry
    assert_equal "Airbnb - Résolution HMFEPSHPWD-RES-01 (Remboursement des dommages AirCover)", resolution_entry.libelle
  end

  # Test that cross-year laundry duplicate prevention works flawlessly
  #
  # @return [void]
  def test_import_multi_payment_cross_years_laundry
    # 1. Setup a dummy journals data_dir
    test_data_dir = File.join(__dir__, 'tmp', 'cross_years_laundry_test_data')
    FileUtils.rm_rf(test_data_dir)
    FileUtils.mkdir_p(test_data_dir)

    original_data_dir = LMNPCompta::Settings.instance.data_dir
    LMNPCompta::Settings.instance.instance_variable_set(:@data_dir, test_data_dir)

    # 2. Add HM43H5YC8Z-01 and laundry entry LNDRY-HM43H5YC8Z to 2025's journal
    entry_2025_booking = {
      'id' => 1,
      'date' => '2025-12-16',
      'libelle' => 'Airbnb - HM43H5YC8Z-01',
      'ref' => 'HM43H5YC8Z-01',
      'journal' => 'VT',
      'lines' => [
        { 'compte' => '706000', 'credit' => '1400.95', 'debit' => '0.00', 'libelle_ligne' => 'Revenu' },
        { 'compte' => '512000', 'credit' => '0.00', 'debit' => '1400.95', 'libelle_ligne' => 'Virement' }
      ]
    }
    entry_2025_laundry = {
      'id' => 2,
      'date' => '2025-12-31',
      'libelle' => 'Blanchisserie - Studio',
      'ref' => 'LNDRY-HM43H5YC8Z',
      'journal' => 'OD',
      'lines' => [
        { 'compte' => '615000', 'credit' => '0.00', 'debit' => '2.50', 'libelle_ligne' => 'Frais' },
        { 'compte' => '108000', 'credit' => '2.50', 'debit' => '0.00', 'libelle_ligne' => 'Avances' }
      ]
    }
    FileUtils.mkdir_p(File.join(test_data_dir, '2025'))
    File.write(File.join(test_data_dir, '2025', 'journal.yaml'), [entry_2025_booking, entry_2025_laundry].to_yaml)

    # 3. Import HM43H5YC8Z second payment in 2026
    csv_2026 = <<~CSV
      Type,Date,Code de confirmation,Date de début,Date de fin,Nuits,Logement,Frais de service,Revenus bruts,Devise
      Réservation,01/16/2026,HM43H5YC8Z,12/15/2025,02/28/2026,77,Studio,79.88,2216.93,EUR
    CSV
    create_csv(csv_2026)

    # Re-initialize current year active journal for 2026
    current_journal_file = File.join(test_data_dir, '2026_journal.yaml')
    current_journal = LMNPCompta::Journal.new(current_journal_file, year: 2026)

    importer = LMNPCompta::AirbnbImporter.new(@csv_file, current_journal)
    # Mock @blanchisseries directly
    laundry_mock = Struct.new(:nom_bien, :cost_per_wash).new("Studio", "2.5")
    importer.instance_variable_set(:@blanchisseries, [laundry_mock])

    entries = importer.import

    # Cleanup test_data_dir
    FileUtils.rm_rf(test_data_dir)
    LMNPCompta::Settings.instance.instance_variable_set(:@data_dir, original_data_dir)

    # Should only import the booking entry, NOT the laundry entry (as it already exists in 2025's journal!)
    assert_equal 1, entries.length
    assert_equal "HM43H5YC8Z-02", entries.first.ref
  end
end
