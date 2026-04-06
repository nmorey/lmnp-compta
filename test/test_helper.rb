require 'net/http'

# Globally mock Net::HTTP.start during the test suite to prevent actual TSA network calls
Net::HTTP.singleton_class.alias_method :original_start, :start
Net::HTTP.define_singleton_method(:start) do |*args, **kwargs, &block|
  # We return nil to simulate a failed/skipped network request, ensuring the test doesn't contact live servers.
  nil
end
