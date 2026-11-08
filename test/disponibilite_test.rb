require 'test_helper'
require 'lmnp_compta/disponibilite'
require 'fileutils'

class DisponibiliteTest < Minitest::Test
    TEST_DIR = File.join(__dir__, 'tmp', 'dispo_test')

    def setup
        FileUtils.rm_rf(TEST_DIR)
        FileUtils.mkdir_p(TEST_DIR)
        @orig_pwd = Dir.pwd
        Dir.chdir(TEST_DIR)
        File.write('lmnp.yaml', "data_dir: data\nannee: 2025\n")
        LMNPCompta::Settings.load('lmnp.yaml')
    end

    def teardown
        Dir.chdir(@orig_pwd)
        FileUtils.rm_rf(TEST_DIR)
    end

    def test_prorata_temporis_calculation
        dispo = LMNPCompta::Disponibilite.new(
            nom_bien: "Maison Test",
            annee: 2025,
            disponibles: 120,
            indisponibles: 245
        )

        assert_equal 120, dispo.disponibles
        assert_equal 245, dispo.indisponibles
        assert_equal 365, dispo.total_nuits
        assert dispo.valid_days_sum?
        # 120 / 365 = 0.328767
        assert_in_delta 0.328767, dispo.prorata_temporis, 0.00001
    end

    def test_deduce_indisponibles_from_disponibles
        dispo = LMNPCompta::Disponibilite.new(
            nom_bien: "Maison Test",
            annee: 2025,
            disponibles: 200
        )

        assert_equal 200, dispo.disponibles
        assert_equal 165, dispo.indisponibles
        assert_equal 365, dispo.total_nuits
        assert dispo.valid_days_sum?
    end

    def test_deduce_disponibles_from_indisponibles
        dispo = LMNPCompta::Disponibilite.new(
            nom_bien: "Maison Test",
            annee: 2025,
            indisponibles: 65
        )

        assert_equal 300, dispo.disponibles
        assert_equal 65, dispo.indisponibles
        assert_equal 365, dispo.total_nuits
        assert dispo.valid_days_sum?
    end

    def test_leap_year_handling
        dispo = LMNPCompta::Disponibilite.new(
            nom_bien: "Maison Bissextile",
            annee: 2024,
            disponibles: 150
        )

        assert_equal 366, dispo.total_nuits
        assert_equal 216, dispo.indisponibles
        assert dispo.valid_days_sum?
        # 150 / 366 = 0.409836
        assert_in_delta 0.409836, dispo.prorata_temporis, 0.00001
    end

    def test_pleine_annee_initialization
        dispo = LMNPCompta::Disponibilite.new(
            nom_bien: "Appart 100",
            annee: 2025,
            pleine_annee: true
        )

        assert_equal 365, dispo.disponibles
        assert_equal 0, dispo.indisponibles
        assert_equal 365, dispo.total_nuits
        assert dispo.pleine_annee?
        assert_equal 1.0, dispo.prorata_temporis
    end

    def test_validation_failure_on_invalid_sum
        dispo = LMNPCompta::Disponibilite.new(
            nom_bien: "Maison Invalide",
            annee: 2025,
            disponibles: 100,
            indisponibles: 50
        )

        assert_equal 150, dispo.total_nuits
        refute dispo.valid_days_sum?
        err = assert_raises(RuntimeError) do
            dispo.validate!
        end
        assert_match(/Incohérence du nombre de jours/, err.message)
    end

    def test_save_and_load
        dispo = LMNPCompta::Disponibilite.new(
            nom_bien: "Maison A",
            annee: 2025,
            disponibles: 120,
            indisponibles: 245
        )
        LMNPCompta::Disponibilite.save(dispo)

        loaded = LMNPCompta::Disponibilite.find("Maison A", 2025)
        refute_nil loaded
        assert_equal 120, loaded.disponibles
        assert_equal 245, loaded.indisponibles
        assert_equal dispo.prorata_temporis, loaded.prorata_temporis
        assert_equal({
            'disponibles' => 120,
            'indisponibles' => 245,
            'prorata_temporis' => dispo.prorata_temporis
        }, loaded.to_h)
    end
end
