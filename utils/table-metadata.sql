-- Get only the most recent data for each table across all databases
WITH latest_tables AS (
  SELECT
    table_catalog,
    table_schema,
    table_name,
    row_count,
    bytes,
    created,
    last_altered,
    table_type,
    -- Using ROW_NUMBER to get only the latest version of each table
    ROW_NUMBER() OVER (
      PARTITION BY table_catalog, table_schema, table_name
      ORDER BY last_altered DESC
    ) AS rn
  FROM
    snowflake.account_usage.tables
  WHERE
    table_type = 'BASE TABLE'
    AND table_catalog IN
    (
      -- JP legacy
      'ANALYTICS', 'BUOY_SOFTWARE',

      -- Contemporary environments
      'BUOY_DEV',                     'BUOY_STAGING',                                                    'BUOY_PROD',
      'JP_DEV',                       'JP_STAGING',                                                      'JP_PROD',
      'CSL_DEV',                      'CSL_STAGING',                      'CSL_QA',                      'CSL_PROD',

      -- Snowflake Connector for Postgres application databases
      'CSL_NONPROD_POSTGRESQL',                                                                          'CSL_PROD_POSTGRESQL',

      -- Snowflake Connector for Postgres destination databases
      'CSL_DEV_POSTGRESQL_BUOYRAILS', 'CSL_STAGING_POSTGRESQL_BUOYRAILS', 'CSL_QA_POSTGRESQL_BUOYRAILS', 'CSL_PROD_POSTGRESQL_BUOYRAILS',
      'CSL_DEV_POSTGRESQL_WHARF',     'CSL_STAGING_POSTGRESQL_WHARF',     'CSL_QA_POSTGRESQL_WHARF',     'CSL_PROD_POSTGRESQL_WHARF'
    )
    -- exclude deleted tables
    AND deleted IS NULL
)
SELECT
  table_catalog AS database_name,
  table_schema AS schema_name,
  table_name,
  row_count,
  bytes / (1024*1024) AS size_mb,
  bytes / (1024*1024*1024) AS size_gb,
  TO_VARCHAR(last_altered, 'YYYY-MM-DD HH24:MI:SS') AS last_modified,
  TO_VARCHAR(created, 'YYYY-MM-DD HH24:MI:SS') AS created,
  table_type
FROM
  latest_tables
WHERE
  rn = 1  -- Only take the most recent version
ORDER BY
  table_catalog,
  table_schema,
  table_name;
