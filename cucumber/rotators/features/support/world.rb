# TODO: Explanation of design and how to add a new rotator
#

require 'aws-sdk'

module RotatorWorld

  # Utility for the postgres rotator
  #
  def run_sql_in_testdb(sql, user='postgres', pw='postgres_secret')
    system("PGPASSWORD=#{pw} psql -h testdb -U #{user} -c \"#{sql}\"")
  end

  def variable(var_name)
    conjur_api.resource("cucumber:variable:#{var_name}")
  end

  # This wires up and kicks off of the postgres polling process, and then
  # returns the results of that process: a history of distinct passwords seen
  # by the polling.
  #
  def postgres_password_history(var_id:, db_user:, values_needed:, timeout:)
    variable_meth = method(:variable)
    polled_value = PgRotatingPassword.new(var_id, db_user, variable_meth)
    polling = PollingSession.new(polled_value, values_needed, timeout)
    polling.captured_values
  end

  def aws_credentials_history(values_needed:, timeout:)
    variable_meth = method(:variable)
    polled_value = AwsRotatingCredentials.new(variable_meth)
    polling = PollingSession.new(polled_value, values_needed, timeout)
    polling.captured_values
  end

  # This represents a rotating postgres password across time -- a changing
  # entity with a current_value.
  # 
  # The "value" of this entity only exists when the actual db password matches
  # the password in Conjur.  During the ephemeral moments when they're out of
  # sync, or when either one of the passwords is not available, the
  # `PgRotatingPassword` is considered to be `nil`.
  #
  # This avoids possible race conditions with the actual rotation thread --
  # it's possible we could "reading" here at the same time the rotation process
  # has only "written" one of the two passwords that need to be kept in sync.
  #
  PgRotatingPassword ||= Struct.new(:var_name, :db_user, :variable_meth) do

    def current_value
      pw = variable_meth.(var_name)&.value
      pw_works_in_db = pg_login_result(db_user, pw) if pw
      pw_works_in_db ? pw : nil
    rescue
      nil
    end

    private

    # The host -- the container name of the testdb created by docker-compose --
    # is hardcoded here.  This shouldn't be problematic as there's likely no
    # need to make it dynamic.
    def pg_login_result(user, pw)
      system("PGPASSWORD=#{pw} psql -c \"\\q\" -h testdb -U #{user}")
    end
  end

  # Assumes:
  # 1. awscli is installed.
  # 2. The test account has the `describe-regions` privilege.
  #
  AwsRotatingCredentials ||= Struct.new(:variable_meth) do

    def current_value
      id = variable_meth.('access_key_id')&.value
      key = variable_meth.('secret_access_key')&.value
      return nil unless id && key
      return nil unless valid_credentials?(id, key)
      { access_key_id: id, secret_access_key: key}
    rescue
      nil
    end

    private

    def valid_credentials?(id, key)
      options = { region: 'us-east-1', access_key_id: id, secret_access_key: key }
      Aws::EC2::Client.new(options).describe_regions
      true
    rescue
      false
    end

  end

  # A "session" of polling that lasts until we've captured the number of values
  # specified by "values_needed" or we exceed the timeout limit, in which case
  # it raises an error.
  # 
  class PollingSession

    def initialize(polled_value, values_needed, timeout)
      @polled_value = polled_value
      @values_needed = values_needed
      @timeout       = timeout
    end

    def captured_values
      timer = Timer.new
      history = []
      loop do
        history = updated_history(history)
        return history if history.size >= @values_needed
        raise error_msg if timer.has_exceeded?(@timeout)
        sleep(0.3)
      end
    end

    def updated_history(history)
      cur = @polled_value.current_value
      did_value_change = cur && cur != history.last
      did_value_change ? history + [cur] : history
    end

    def error_msg
      "Failed to detect #{@values_needed} rotations in #{@timeout} seconds"
    end
  end

  class Timer
    def initialize
      @started_at = Time.new
    end

    def time_elapsed
      Time.new - @started_at
    end

    def has_exceeded?(seconds)
      time_elapsed > seconds
    end
  end

end
