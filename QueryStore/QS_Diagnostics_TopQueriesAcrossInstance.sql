/*==============================================================================
  Query Store – Top N Query Hashes Across All Databases
  - Groups by query_hash to also capture “ad-hoc” variations under one fingerprint
  - Aggregates last @LastNDays across all ONLINE, QS-enabled user databases
  - Order by CPU, duration, or logical reads (configurable)
  Notes:
    * Query Store time units:
        - avg_duration, avg_cpu_time are in MICROSECONDS (µs).
        - converted to milliseconds (ms) where labeled “…_ms”.
    * Logical/physical reads are in pages/reads.
==============================================================================*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- =====================
-- Parameters
-- =====================

DECLARE @TopN             int         = 100;          -- Top N rows returned
DECLARE @LastNDays        int         = 7;            -- Lookback window
DECLARE @OrderBy          varchar(20) = 'MEMORY';        -- 'CPU'|'DURATION'|'READS'|'MEMORY'
DECLARE @MinExecutions    bigint      = 1;            -- Ignore hashes with < N executions

-- Derived time window
DECLARE @StartDate datetime2(3) = DATEADD(day, -@LastNDays, SYSUTCDATETIME()); 
--DECLARE @StartDate datetime2(3) = DATEADD(day, -@LastNDays, SYSDATETIME()); -- uncomment for server time

-- ======================
-- Temp table 
-- ======================
IF OBJECT_ID('tempdb..#QueryStoreData') IS NOT NULL
	DROP TABLE #QueryStoreData;

CREATE TABLE #QueryStoreData
(
    database_name         sysname           NOT NULL,
    query_hash            binary(8)         NOT NULL,
    query_text_sample     nvarchar(1000)    NULL,      -- shortest raw text
    query_text_clean      nvarchar(1000)    NULL,      -- normalized for nicer display
    query_id_count        int               NOT NULL,
    total_executions      bigint            NOT NULL,
    total_duration_ms     bigint            NOT NULL,  -- sum in ms
    avg_duration_ms       decimal(18,2)     NOT NULL,
    total_cpu_ms          bigint            NOT NULL,
    avg_cpu_ms            decimal(18,2)     NOT NULL,
    total_logical_reads   bigint            NOT NULL,
    avg_logical_reads     decimal(18,2)     NOT NULL,
    total_physical_reads  bigint            NOT NULL,
	avg_used_memory       decimal(18,2)     NOT NULL,
    total_used_memory     bigint            NOT NULL,
    first_execution_time  datetime2(3)      NULL,
    last_execution_time   datetime2(3)      NULL
);

-- ==========================================================
-- Collect list of QS-enabled, ONLINE, non-system databases
-- ==========================================================
DECLARE @dbs TABLE (db_name sysname PRIMARY KEY);
INSERT @dbs(db_name)
SELECT name
FROM sys.databases
WHERE is_query_store_on = 1
  AND state = 0
  AND name NOT IN ('master','model','msdb','tempdb');

-- ==========================================
-- Iterate databases and gather QS aggregates
--   * Parameterize @StartDate to avoid string concat
-- ==========================================
DECLARE
    @db_name sysname,
    @sql     nvarchar(max);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT db_name FROM @dbs;

OPEN cur;
FETCH NEXT FROM cur INTO @db_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    INSERT INTO #QueryStoreData
    SELECT
        DB_NAME() AS database_name,
        q.query_hash,

        -- Representative query text (shortest raw sample)
        (SELECT TOP (1) LEFT(qt2.query_sql_text, 1000)
         FROM sys.query_store_query q2
         JOIN sys.query_store_query_text qt2
           ON q2.query_text_id = qt2.query_text_id
         WHERE q2.query_hash = q.query_hash
         ORDER BY LEN(qt2.query_sql_text) ASC) AS query_text_sample,

        -- A lightly normalized copy (trim + collapse whitespace) for nicer display
        (SELECT TOP (1)
                LEFT( LTRIM(RTRIM(
                    REPLACE(REPLACE(REPLACE(qt2.query_sql_text, CHAR(13), '' ''), CHAR(10), '' ''), CHAR(9), '' '')
                )), 1000)
         FROM sys.query_store_query q2
         JOIN sys.query_store_query_text qt2
           ON q2.query_text_id = qt2.query_text_id
         WHERE q2.query_hash = q.query_hash
         ORDER BY LEN(qt2.query_sql_text) ASC) AS query_text_clean,

        COUNT(DISTINCT q.query_id) AS query_id_count,

        -- Aggregate runtime stats; QS stores averages per interval/plan
        SUM(CAST(rs.count_executions AS bigint)) AS total_executions,

        -- Convert µs -> ms: (avg * count) / 1000
        SUM(CAST(rs.avg_duration   * rs.count_executions AS bigint)) / 1000 AS total_duration_ms,
        CASE WHEN SUM(rs.count_executions) > 0
             THEN (SUM(CAST(rs.avg_duration * rs.count_executions AS bigint)) * 1.0)
                  / NULLIF(SUM(rs.count_executions),0) / 1000.0
             ELSE 0 END AS avg_duration_ms,

        SUM(CAST(rs.avg_cpu_time   * rs.count_executions AS bigint)) / 1000 AS total_cpu_ms,
        CASE WHEN SUM(rs.count_executions) > 0
             THEN (SUM(CAST(rs.avg_cpu_time * rs.count_executions AS bigint)) * 1.0)
                  / NULLIF(SUM(rs.count_executions),0) / 1000.0
             ELSE 0 END AS avg_cpu_ms,

        SUM(CAST(rs.avg_logical_io_reads * rs.count_executions AS bigint)) AS total_logical_reads,
        CASE WHEN SUM(rs.count_executions) > 0
             THEN (SUM(CAST(rs.avg_logical_io_reads * rs.count_executions AS bigint)) * 1.0)
                  / NULLIF(SUM(rs.count_executions),0)
             ELSE 0 END AS avg_logical_reads,

        SUM(CAST(rs.avg_physical_io_reads * rs.count_executions AS bigint)) AS total_physical_reads,

		SUM(CAST(rs.avg_query_max_used_memory * rs.count_executions AS bigint)) AS total_used_memory,
        CASE WHEN SUM(rs.count_executions) > 0
             THEN (SUM(CAST(rs.avg_query_max_used_memory * rs.count_executions AS bigint)) * 1.0)
                  / NULLIF(SUM(rs.count_executions),0)
             ELSE 0 END AS avg_used_memory,

        MIN(rsi.start_time) AS first_execution_time,
        MAX(rsi.end_time)   AS last_execution_time
    FROM sys.query_store_query q
    JOIN sys.query_store_plan p
      ON q.query_id = p.query_id
    JOIN sys.query_store_runtime_stats rs
      ON p.plan_id = rs.plan_id
    JOIN sys.query_store_runtime_stats_interval rsi
      ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
    WHERE rsi.start_time >= @pStartDate
      AND q.is_internal_query = 0
    GROUP BY q.query_hash
    HAVING SUM(rs.count_executions) >= @pMinExecs;
    ';

    BEGIN TRY
        -- Build full dynamic SQL with the database context
		DECLARE @fullsql nvarchar(max);

		SET @fullsql = N'USE ' + QUOTENAME(@db_name) + N'; ' + @sql;

		-- Execute with parameters
		EXEC sp_executesql
			@fullsql,
			N'@pStartDate datetime2(3), @pMinExecs bigint',
			@pStartDate = @StartDate,
			@pMinExecs  = @MinExecutions;

        PRINT 'Processed database: ' + @db_name;
    END TRY
    BEGIN CATCH
        PRINT 'Error processing database ' + @db_name + ': ' + ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM cur INTO @db_name;
END

CLOSE cur;
DEALLOCATE cur;

-- ==========================================
-- Aggregate same query_hash across databases
-- ==========================================
;WITH Aggregated AS
(
    SELECT
        query_hash,
        STRING_AGG(database_name, ', ') WITHIN GROUP (ORDER BY database_name) AS databases,
        -- pick the shortest normalized form for display
        (SELECT TOP (1) q2.query_text_clean
         FROM #QueryStoreData q2
         WHERE q2.query_hash = q.query_hash
         ORDER BY LEN(q2.query_text_clean) ASC) AS query_text_clean,
        (SELECT TOP (1) q2.query_text_sample
         FROM #QueryStoreData q2
         WHERE q2.query_hash = q.query_hash
         ORDER BY LEN(q2.query_text_sample) ASC) AS query_text_sample,
        SUM(query_id_count)      AS total_query_ids,
        SUM(total_executions)    AS total_executions,
        SUM(total_duration_ms)   AS total_duration_ms,
        CASE WHEN SUM(total_executions) > 0
             THEN CAST(SUM(total_duration_ms) AS decimal(18,2)) / NULLIF(SUM(total_executions),0)
             ELSE 0 END         AS avg_duration_ms,
        SUM(total_cpu_ms)        AS total_cpu_ms,
        CASE WHEN SUM(total_executions) > 0
             THEN CAST(SUM(total_cpu_ms) AS decimal(18,2)) / NULLIF(SUM(total_executions),0)
             ELSE 0 END         AS avg_cpu_ms,
        SUM(total_logical_reads) AS total_logical_reads,
        CASE WHEN SUM(total_executions) > 0
             THEN CAST(SUM(total_logical_reads) AS decimal(18,2)) / NULLIF(SUM(total_executions),0)
             ELSE 0 END         AS avg_logical_reads,
        SUM(total_physical_reads) AS total_physical_reads,
		SUM(total_used_memory) AS total_used_memory,
         CASE WHEN SUM(total_executions) > 0
             THEN CAST(SUM(total_used_memory) AS decimal(18,2)) / NULLIF(SUM(total_executions),0)
             ELSE 0 END         AS avg_used_memory,
        MIN(first_execution_time) AS first_execution_time,
        MAX(last_execution_time)  AS last_execution_time
    FROM #QueryStoreData q
    GROUP BY query_hash
)
SELECT TOP (@TopN)
    CONVERT(varchar(18), query_hash, 1)                                  AS query_hash,
    databases,
    -- prefer clean text for readability; fall back to raw sample
    LEFT(COALESCE(query_text_clean, query_text_sample), 200) +
        CASE WHEN LEN(COALESCE(query_text_clean, query_text_sample)) > 200 THEN '…' ELSE '' END AS query_sample,
    total_query_ids,
    total_executions,

    -- Duration
    total_duration_ms,
    CAST(avg_duration_ms AS DECIMAL(32,2)) avg_duration_ms,

    -- CPU
    total_cpu_ms,
    CAST(avg_cpu_ms AS DECIMAL(32,2)) avg_cpu_ms,

    -- I/O
    total_logical_reads,
    CAST(avg_logical_reads AS DECIMAL(32,2)) avg_logical_reads,
    total_physical_reads,

	-- Memory
	total_used_memory,
    CAST(avg_used_memory AS DECIMAL(32,2)) avg_used_memory,

    -- Window
    first_execution_time,
    last_execution_time,

    -- Simple categorization
    CASE WHEN total_query_ids > 1 THEN 'AD-HOC PATTERN' ELSE 'PARAMETERIZED' END AS query_type,
    CASE WHEN avg_duration_ms >= 5000 THEN 'SLOW'
         WHEN avg_duration_ms >= 1000 THEN 'MODERATE'
         ELSE 'FAST' END AS duration_category,
    CASE WHEN avg_cpu_ms >= 2000 THEN 'HIGH CPU'
         WHEN avg_cpu_ms >= 500  THEN 'MODERATE CPU'
         ELSE 'LOW CPU' END AS cpu_category
FROM Aggregated
ORDER BY
    CASE
        WHEN @OrderBy = 'CPU'      THEN total_cpu_ms
        WHEN @OrderBy = 'DURATION' THEN total_duration_ms
        WHEN @OrderBy = 'READS'    THEN total_logical_reads
		WHEN @OrderBy = 'MEMORY'    THEN total_used_memory
        ELSE total_cpu_ms
    END DESC;

-- =====================
-- Summary statistics
-- =====================
PRINT CHAR(13) + '=== SUMMARY STATISTICS ===';

SELECT
    'SUMMARY'                                AS metric_type,
    COUNT(DISTINCT query_hash)               AS unique_query_hashes,
    SUM(query_id_count)                      AS total_query_ids_across_instance,
    SUM(total_executions)                    AS total_executions,
    SUM(total_duration_ms)                   AS total_duration_ms,
    SUM(total_cpu_ms)                        AS total_cpu_ms,
    SUM(total_logical_reads)                 AS total_logical_reads,
    SUM(CASE WHEN query_id_count > 1 THEN 1 ELSE 0 END) AS adhoc_query_patterns,
    SUM(CASE WHEN query_id_count = 1 THEN 1 ELSE 0 END) AS parameterized_queries
FROM #QueryStoreData;

/* Top databases by activity 
*/
SELECT
    database_name,
    COUNT(DISTINCT query_hash)     AS unique_query_hashes,
    SUM(query_id_count)            AS total_query_ids,
    SUM(total_executions)          AS total_executions,
    SUM(total_cpu_ms)              AS total_cpu_ms,
    SUM(total_duration_ms)         AS total_duration_ms,
	SUM(total_used_memory)         AS total_used_memory
FROM #QueryStoreData
GROUP BY database_name
ORDER BY total_cpu_ms DESC;
--ORDER BY total_duration_ms DESC;
--ORDER BY total_logical_reads DESC;

/* Cleanup
*/
DROP TABLE IF EXISTS #QueryStoreData;

PRINT '';
PRINT 'Parameters used:';
PRINT 'Top N queries: ' + CAST(@TopN AS varchar(10));
PRINT 'Last N days: ' + CAST(@LastNDays AS varchar(10));
PRINT 'Ordered by: '  + @OrderBy;
PRINT 'Date range (UTC): ' + CONVERT(varchar(23), @StartDate, 121) + ' to ' + CONVERT(varchar(23), SYSUTCDATETIME(), 121);
