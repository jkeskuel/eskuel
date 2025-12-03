;WITH local AS (
    SELECT *
    FROM sys.dm_hadr_database_replica_states drs
    WHERE is_local = 1
),
remote AS (
    SELECT *
    FROM sys.dm_hadr_database_replica_states drs
    WHERE is_local = 0
)
SELECT  
      DB_NAME(d.database_id) AS dbname
    , l.synchronization_health_desc AS local_health
    , r.synchronization_health_desc AS remote_health
FROM sys.databases d
LEFT JOIN local  l ON d.database_id = l.database_id
LEFT JOIN remote r ON l.database_id = r.database_id
WHERE d.database_id > 4
  AND (
        r.synchronization_health_desc <> 'HEALTHY'
        OR l.synchronization_health IS NULL
      )
ORDER BY dbname ASC;
