require_relative '../montant'

module LMNPCompta
  module Fiscal
    class Base
      attr_reader :balances, :entries, :assets, :stock, :year

      def initialize(entries, assets, stock, year)
        @entries = entries
        @assets = assets
        @stock = stock
        @year = year
        @balances = Hash.new(Montant.new("0"))
        calculate_balances
      end

      def calculate_balances
        @entries.each do |e|
          e.lines.each do |l|
            debit = l[:debit]
            credit = l[:credit]
            @balances[l[:compte].to_s] += (debit - credit)
          end
        end
      end

      def sum_prefix(prefix)
        @balances.select { |k, _| k.to_s.start_with?(prefix) }.values.sum(Montant.new(0))
      end
      
      # Methods to be implemented by subclasses or defaults
      def analyze; raise NotImplementedError; end
      def immo_brut; raise NotImplementedError; end
      def amort_cumules; raise NotImplementedError; end
      def tresorerie; raise NotImplementedError; end
      def creances; raise NotImplementedError; end
      def capital; raise NotImplementedError; end
      def emprunts; raise NotImplementedError; end
      def dettes_fournisseurs; raise NotImplementedError; end
      def recettes; raise NotImplementedError; end
      def charges_exploit; raise NotImplementedError; end
      def charges_fi; raise NotImplementedError; end
      def dotations; raise NotImplementedError; end

      def immo_net
        immo_brut - amort_cumules
      end
      
      def resultat_comptable
        recettes - (charges_exploit + charges_fi + dotations)
      end
    end
  end
end
