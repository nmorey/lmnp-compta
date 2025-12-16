require 'minitest/autorun'
require_relative '../lib/lmnp_compta/montant'

class MontantTest < Minitest::Test
    def test_initialization
        assert_equal "10,00", LMNPCompta::Montant.new(10).to_s
        assert_equal "10,50", LMNPCompta::Montant.new(10.5).to_s
        assert_equal "10,50", LMNPCompta::Montant.new("10.50").to_s
        assert_equal "0,00", LMNPCompta::Montant.new(nil).to_s
    end

    def test_french_parsing
        # French format with space as thousand separator and comma as decimal
        assert_equal "1050,50", LMNPCompta::Montant.new("1 050,50").to_s
        # French format with simple comma
        assert_equal "12,30", LMNPCompta::Montant.new("12,30").to_s
        # Dirty input (currency symbols)
        assert_equal "100,00", LMNPCompta::Montant.new("100 €").to_s
        assert_equal "100,00", LMNPCompta::Montant.new("EUR 100").to_s
    end

    def test_arithmetic
        m1 = LMNPCompta::Montant.new(10)
        m2 = LMNPCompta::Montant.new(5.5)

        assert_equal "15,50", (m1 + m2).to_s
        assert_equal "4,50", (m1 - m2).to_s
        assert_equal "20,00", (m1 * 2).to_s
    end

    def test_comparison
        m1 = LMNPCompta::Montant.new(10)
        m2 = LMNPCompta::Montant.new(10.00)
        m3 = LMNPCompta::Montant.new(11)

        assert m1 == m2
        assert m3 > m1
        assert m1 < m3
        assert m1 != m3
    end

    def test_zero_checks
        assert LMNPCompta::Montant.new(0).zero?
        assert LMNPCompta::Montant.new("0,00").zero?
        refute LMNPCompta::Montant.new(0.01).zero?
    end

    def test_abs
        neg = LMNPCompta::Montant.new(-10)
        assert_equal "10,00", neg.abs.to_s
    end
end
