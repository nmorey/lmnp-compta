require 'yaml'
require 'date'
require_relative 'entry'

module LMNPCompta
  class Journal
    attr_reader :file_path, :entries

    def initialize(file_path)
      @file_path = file_path
      @entries = []
      load! if File.exist?(file_path)
    end

    def load!
      data = YAML.load_file(@file_path) || []
      @entries = data.map { |d| Entry.new(d) }
    end

    def save!
      # Sort by date
      sorted = @entries.sort_by { |e| Date.parse(e.date.to_s) }
      File.write(@file_path, sorted.map(&:to_h).to_yaml)
    end

    def add_entry(entry)
      entry.id = next_id if entry.id.nil?
      unless entry.balanced?
        raise "Cannot add unbalanced entry: #{entry.libelle} (Balance: #{entry.balance})"
      end
      @entries << entry
    end

    def next_id
      max_id = @entries.map { |e| e.id.to_i }.max || 0
      max_id + 1
    end
    
    def find(id)
      @entries.find { |e| e.id == id }
    end

    def delete(id)
      @entries.reject! { |e| e.id == id }
    end
  end
end
