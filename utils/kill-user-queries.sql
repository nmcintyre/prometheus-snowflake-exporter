-- Create a stored procedure to kill all running queries for a user
CREATE OR REPLACE PROCEDURE KILL_USER_QUERIES(USER_TO_KILL STRING)
RETURNS STRING
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
var killed_queries = 0;
var running_queries_command = 
  "SELECT QUERY_ID " +
  "FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_USER(USER_NAME => '" + USER_TO_KILL + "', RESULT_LIMIT => 1000)) " +
  "WHERE EXECUTION_STATUS IN ('RUNNING', 'QUEUED', 'STARTED')";
var stmt = snowflake.createStatement({sqlText: running_queries_command});
var result_set = stmt.execute();

while (result_set.next()) {
  var query_id = result_set.getColumnValue(1);
  var cancel_command = "CALL SYSTEM$CANCEL_QUERY('" + query_id + "')";
  
  try {
    var cancel_stmt = snowflake.createStatement({sqlText: cancel_command});
    cancel_stmt.execute();
    killed_queries++;
  } catch (err) {
    // Query might have completed before we tried to cancel it
  }
}

return "Killed " + killed_queries + " queries for user " + USER_TO_KILL;
$$;

-- Execute the procedure
CALL KILL_USER_QUERIES('PROMETHEUS_USER');
