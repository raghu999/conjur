require 'syslog'
require 'logger'

module Audit
  class Event < Util::Struct
    def log_to logger
      logger.log logger_severity, self, progname
    end

    def to_s
      message
    end

    def progname
      'conjur'
    end

    # Return severity as it's understood by Ruby ::Logger
    def logger_severity
      SEVERITY_MAP[severity]
    end

    # Pretend this is a String because Ruby's built-in log formatter matches it
    # like this and uses #inspect to print the message otherwise.
    #
    # I suppose it does :reek:ControlParameter, but there isn't much that can be done about it.
    def === other
      (other == String) || super
    end

    SDID = ::Audit::SDID

    SEVERITY_MAP = {
      LOG_EMERG: :FATAL,
      LOG_ALERT: :FATAL,
      LOG_CRIT: :ERROR,
      LOG_ERR: :ERROR,
      LOG_WARNING: :WARN,
      LOG_NOTICE: :INFO,
      LOG_INFO: :INFO,
      LOG_DEBUG: :DEBUG
    }.map do |syslog, logger|
      [Syslog::Level.const_get(syslog), Logger::Severity.const_get(logger)]
    end.to_h.freeze
  end
end
