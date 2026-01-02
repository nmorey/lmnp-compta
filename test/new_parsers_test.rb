require 'minitest/autorun'
require_relative '../lib/lmnp_compta/invoice_parser'
# Require all parsers to ensure they are registered
Dir.glob(File.join(__dir__, '../lib/lmnp_compta/invoice_parsers', '*.rb')).each do |file|
    require file
end

class NewParsersTest < Minitest::Test
    def test_amazon_parser
        text = <<~TXT
            amazon.fr
            Facture
            Payé
            Vendu par Amazon EU S.à r.l., UK Branch
            Date de la commande 23.12.2025
            Numéro de la facture FR52NMLVAEUD
            Total à payer 32,96 €
            TVA déclarée par Amazon EU S.a.r.L.
        TXT

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_instance_of LMNPCompta::InvoiceParser::Amazon, parser

        data = parser.parse.first
        assert_equal Date.new(2025, 12, 23), data[:date]
        assert_equal "AMAZON-20251223-FR52NMLVAEUD", data[:ref]
        assert_equal "32.96", data[:montant].to_s
        assert_equal "Achat Amazon FR52NMLVAEUD", data[:libelle]
        assert_equal "606300", data[:compte_charge]
    end

    def test_entrepot_bricolage_parser
        text = <<~TXT
            L'ENTREPÔT DU BRICOLAGE
            Clos de l'ile Roche La Paccoterie
            Facture N°
            900600200000599577
            DUPLICATA
            le 02/01/2026 09:02:34
            Produit TVA Quantité Prix Unitaire Prix Total
            [420851] MINI COFFRE A CLES COMBI. 20,00 % 1 34,90 € 34,90 €
            TOTAL TTC :
            56,70 €
            TAUX TVA H.T
        TXT

        parser = LMNPCompta::InvoiceParser::Factory.build(nil, text)
        assert_instance_of LMNPCompta::InvoiceParser::EntrepotBricolage, parser

        data = parser.parse.first
        assert_equal Date.new(2026, 1, 2), data[:date]
        # Check ref logic. It might pick up the long number.
        # "Facture N°\n900..."
        # Regex: /Facture N°\s*(\d+)/i -> \s* matches newline
        # So it should match 900600200000599577
        assert_equal "ENTREPOT-20260102-900600200000599577", data[:ref]
        assert_equal "56.70", data[:montant].to_s
        assert_equal "Achat Entrepôt du Bricolage", data[:libelle]
        assert_equal "606300", data[:compte_charge]
    end
end
