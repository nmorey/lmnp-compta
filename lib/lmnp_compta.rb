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
require_relative 'lmnp_compta/journals'
require_relative 'lmnp_compta/asset'
require_relative 'lmnp_compta/settings'
require_relative 'lmnp_compta/cloture'

module LMNPCompta
    # Exception levée lorsque l'utilisateur annule une opération interactive.
    class UserCancelledError < StandardError; end

    # Demande une confirmation interactive à l'utilisateur si STDIN est un TTY.
    # Si STDIN n'est pas un TTY, la confirmation est automatiquement accordée.
    #
    # @param prompt_message [String] Le message de l'invite de confirmation
    # @raise [UserCancelledError] Si l'utilisateur répond par la négative ou annule
    # @return [void]
    def self.confirm!(prompt_message)
        if $stdin.tty?
            print "#{prompt_message} (o/N) : "
            $stdout.flush
            answer = $stdin.gets.to_s.strip.downcase
            unless %w[o oui y yes].include?(answer)
                raise UserCancelledError, "Opération annulée par l'utilisateur."
            end
        end
    end

    def self.format_date(date_str)
        Date.parse(date_str).strftime("%Y%m%d")
    rescue
        raise "ERREUR: Date invalide #{date_str}"
    end
end
