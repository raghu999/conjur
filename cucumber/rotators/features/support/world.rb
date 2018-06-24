# TODO: Explanation of design and how to add a new rotator
#
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
    value_factory = PgCurrentPassword.new(var_id, db_user, variable_meth)
    polling_strat = PollingStrategy.new(value_factory, values_needed, timeout)
    polling_strat.results
  end


  # This represents the concept of the realtime, current value of the postgres
  # password, considered as a changing entity within the context of rotation.
  # 
  # The "value" of this entity only exists when the actual db password matches
  # the password in Conjur.  During the ephemeral moments when they're out of
  # sync, or when either one of the passwords is not available, the
  # `PgCurrentPassword` is considered to be `nil`.
  #
  # This avoids possible race conditions with the actual rotation thread --
  # it's possible we could "reading" here at the same time the rotation process
  # has only "written" one of the two passwords that need to be kept in sync.
  #
  PgCurrentPassword ||= Struct.new(:var_name, :db_user, :variable_meth) do

    def current_value
      pw = variable_meth.(var_name)&.value
      pw_works_in_db = pg_login_result(db_user, pw) if pw
      pw_works_in_db ? pw : nil
    rescue
      nil
    end

    # The host -- the container name of the testdb created by docker-compose --
    # is hardcoded here.  This shouldn't be problematic as there's likely no
    # need to make it dynamic.
    def pg_login_result(user, pw)
      system("PGPASSWORD=#{pw} psql -c \"\\q\" -h testdb -U #{user}")
    end
  end

  # TODO more accurate name than value_factory?
  #
  class PollingStrategy

    def initialize(value_factory, values_needed, timeout)
      @value_factory = value_factory
      @values_needed = values_needed
      @timeout       = timeout
    end

    def results
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
      cur = @value_factory.current_value
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
