require 'ostruct'

# Assorted utilities
module Util
  # An OpenStruct with explicitly defined initial fields.
  class Struct < OpenStruct
    def initialize values
      klass = self.class
      klass.check_args values
      super klass.defaults.merge values
    end

    def self.check_args values
      keys = values.keys
      if (extra = keys - fields - defaults.keys).any? # rubocop:disable Style/GuardClause
        raise ArgumentError, "unexpected parameters: #{extra.join(', ')}"
      elsif (missing = fields - keys).any?
        raise ArgumentError, "missing parameters: #{missing.join(', ')}"
      end
    end

    def self.fields *fields, **optfields
      defaults.merge! optfields
      (@fields ||= []).push(*fields)
    end

    def self.defaults
      @defaults ||= {}
    end
  end
end
