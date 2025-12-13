require 'date'
require_relative 'lmnp_compta/montant'
require_relative 'lmnp_compta/plan_comptable'
require_relative 'lmnp_compta/amortization'
require_relative 'lmnp_compta/fiscal/base'
require_relative 'lmnp_compta/fiscal_analyzer'
require_relative 'lmnp_compta/fec_generator'
require_relative 'lmnp_compta/airbnb_importer'
require_relative 'lmnp_compta/invoice_parser'
require_relative 'lmnp_compta/entry'
require_relative 'lmnp_compta/journal'
require_relative 'lmnp_compta/settings'

module LMNPCompta
  def self.format_date(date_str)
    Date.parse(date_str).strftime("%Y%m%d")
  rescue
    raise "ERREUR: Date invalide #{date_str}"
  end
end
