Then(/^I create a db user "(.*?)" with password "(.*?)"$/) do |user, pw|
  # drop them first, in case we're re-running during dev
  run_sql_in_testdb("DROP DATABASE #{user};")
  run_sql_in_testdb("DROP USER #{user};")
  run_sql_in_testdb("CREATE USER #{user} WITH PASSWORD '#{pw}';")
  run_sql_in_testdb("CREATE DATABASE #{user};")
end

regex = /^I moniter "(.+)" and db user "(.+)" for (\d+) values in (\d+) seconds$/
Then(regex) do |var_id, db_user, vals_needed_str, timeout_str|
  @pg_results = postgres_rotation_results(
    var_id: var_id,
    db_user: db_user,
    values_needed: vals_needed_str.to_i,
    timeout: timeout_str.to_i
  )
end

Then(/^we find at least (\d+) distinct matching passwords$/) do |num_needed_str|
  # this is not really needed, as an error would have occured before getting
  # here if the values_needed had not been reached
  expect(@pg_results.uniq.size).to be >= num_needed_str.to_i
end

Then(/^the generated passwords have length (\d+)$/) do |len_str|
  length    = len_str.to_i
  conjur_pw = @pg_results.last
  expect(conjur_pw.length).to eq(length)
end

Given(/^I have the root policy:$/) do |policy|
  invoke do
    load_root_policy policy
  end
end

Given(/^I reset my root policy$/) do
  invoke do
    load_root_policy <<~EOS
      - !policy
         id: db-reports
         body:
    EOS
  end
end

Given(/^I add the value "(.*)" to variable "(.+)"$/) do |val, var|
  variable = variable_resource(var)
  variable.add_value(val)
end

Then(/^I wait for (\d+) seconds?$/) do |num_seconds|
  puts "Sleeping #{num_seconds}...."
  sleep(num_seconds.to_i)
end
