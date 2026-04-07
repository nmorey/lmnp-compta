require 'minitest/autorun'
require_relative '../lib/lmnp_compta/amortization'
require_relative '../lib/lmnp_compta/montant'

class AmortizationTest < Minitest::Test
    def test_full_year_amortization
        # 1000€ over 10 years = 100€ per year
        dotation = LMNPCompta::Amortization.calcul_dotation(1000, 10, "2024-01-01", 2025)
        assert_equal "100,00", dotation.to_s
    end

    def test_prorata_temporis_start
        # 1000€ over 10 years = 100€/year
        # Start 01/07/2025 (Mid-year) -> 50€ (depends on days count 360 base)
        # Days in 2025: 360
        # Days active: from 01/07 to 31/12 = (30 - 1 + 1) + 5 * 30 = 180 days
        # Expected: 100 * (180/360) = 50.00

        dotation = LMNPCompta::Amortization.calcul_dotation(1000, 10, "2025-07-01", 2025)
        assert_equal "50,00", dotation.to_s
    end

    def test_end_of_amortization
        # 100€ over 2 years starting 01/01/2023
        # 2023: 50
        # 2024: 50
        # 2025: 0 (Finished)
        dotation = LMNPCompta::Amortization.calcul_dotation(100, 2, "2023-01-01", 2025)
        assert_equal "0,00", dotation.to_s
    end

    def test_zero_duration
        dotation = LMNPCompta::Amortization.calcul_dotation(1000, 0, "2025-01-01", 2025)
        assert_equal "0,00", dotation.to_s
    end
end
