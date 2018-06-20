require 'audit/event'

module Audit
  class Event
    class Policy < Event
      fields :policy_version, :operation, :subject

      def severity
        Syslog::LOG_NOTICE
      end

      def message
        @message ||= format "%s %sed %s", user_id, operation.to_s.chomp('e'), subject
      end

      def user_id
        @user_id ||= policy_version.role.id
      end

      def structured_data
        {
          SDID::AUTH => { user: user_id },
          SDID::POLICY => { id: policy_version.id, version: policy_version.version },
          SDID::SUBJECT => subject.to_h,
          SDID::ACTION => { operation: operation }
        }
      end

      def msgid
        'policy'
      end
    end
  end
end
