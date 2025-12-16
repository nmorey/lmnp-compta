module LMNPCompta
    class Command
        def self.registry
            @registry ||= {}
        end

        def self.register(name, description)
            Command.registry[name.to_s] = { class: self, description: description }
        end

        def initialize(args)
            @args = args
        end

        def execute
            raise NotImplementedError
        end
    end
end
