require 'ostruct'

# Assorted utilities
module Util
  # An OpenStruct with explicitly defined initial fields.
  class Struct < OpenStruct
    def initialize values
      self.class.check_args values
      super
    end

    def self.check_args values
      keys = values.keys
      if (extra = keys - fields).any? # rubocop:disable Style/GuardClause
        raise ArgumentError, "unexpected parameters: #{extra.join(', ')}"
      elsif (missing = fields - keys).any?
        raise ArgumentError, "missing parameters: #{missing.join(', ')}"
      end
    end

    def self.fields *fields
      (@fields ||= []).push(*fields)
    end

    attr_reader :fields
  end
end
