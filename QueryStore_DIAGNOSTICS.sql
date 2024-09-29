/*
Source: https://learn.microsoft.com/en-us/sql/relational-databases/performance/tune-performance-with-the-query-store?view=sql-server-ver16
*/
-- Last queries executed on the database
-- The last n queries executed on the database within the last hour:

SELECT TOP 10 qt.query_sql_text,
    q.query_id,
    qt.query_text_id,
    p.plan_id,
    rs.last_execution_time
FROM sys.query_store_query_text AS qt
INNER JOIN sys.query_store_query AS q
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON p.plan_id = rs.plan_id
WHERE rs.last_execution_time > DATEADD(HOUR, -1, GETUTCDATE())
ORDER BY rs.last_execution_time DESC;

-- Execution counts
-- Number of executions for each query within the last hour:

SELECT q.query_id,
    qt.query_text_id,
    qt.query_sql_text,
    SUM(rs.count_executions) AS total_execution_count
FROM sys.query_store_query_text AS qt
INNER JOIN sys.query_store_query AS q
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON p.plan_id = rs.plan_id
WHERE rs.last_execution_time > DATEADD(HOUR, -1, GETUTCDATE())
GROUP BY q.query_id,
    qt.query_text_id,
    qt.query_sql_text
ORDER BY total_execution_count DESC;

-- Longest average execution time
-- The number of queries with the highest average duration within last hour:

SELECT TOP 10 ROUND(CONVERT(FLOAT, SUM(rs.avg_duration * rs.count_executions)) /
        NULLIF(SUM(rs.count_executions), 0), 2) avg_duration,
    SUM(rs.count_executions) AS total_execution_count,
    qt.query_sql_text,
    q.query_id,
    qt.query_text_id,
    p.plan_id,
    GETUTCDATE() AS CurrentUTCTime,
    MAX(rs.last_execution_time) AS last_execution_time
FROM sys.query_store_query_text AS qt
INNER JOIN sys.query_store_query AS q
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON p.plan_id = rs.plan_id
WHERE rs.last_execution_time > DATEADD(HOUR, -1, GETUTCDATE())
GROUP BY qt.query_sql_text,
    q.query_id,
    qt.query_text_id,
    p.plan_id
ORDER BY avg_duration DESC;

-- Highest average physical I/O reads
-- The number of queries that had the biggest average physical I/O reads in last 24 hours, with corresponding average row count and execution count:

SELECT TOP 10 rs.avg_physical_io_reads,
    qt.query_sql_text,
    q.query_id,
    qt.query_text_id,
    p.plan_id,
    rs.runtime_stats_id,
    rsi.start_time,
    rsi.end_time,
    rs.avg_rowcount,
    rs.count_executions
FROM sys.query_store_query_text AS qt
INNER JOIN sys.query_store_query AS q
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON p.plan_id = rs.plan_id
INNER JOIN sys.query_store_runtime_stats_interval AS rsi
    ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(hour, -24, GETUTCDATE())
ORDER BY rs.avg_physical_io_reads DESC;

-- Queries with multiple plans
-- Queries with more than one plan are especially interesting, because they can be candidates for a regression in performance due to a change in plan choice.
-- The following query identifies the queries with the highest number of plans within the last hour:

SELECT q.query_id,
    object_name(object_id) AS ContainingObject,
    COUNT(*) AS QueryPlanCount,
    STRING_AGG(p.plan_id, ',') plan_ids,
    qt.query_sql_text
FROM sys.query_store_query_text AS qt
INNER JOIN sys.query_store_query AS q
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON p.plan_id = rs.plan_id
WHERE rs.last_execution_time > DATEADD(HOUR, -1, GETUTCDATE())
GROUP BY OBJECT_NAME(object_id),
    q.query_id,
    qt.query_sql_text
HAVING COUNT(DISTINCT p.plan_id) > 1
ORDER BY QueryPlanCount DESC;

-- The following query identifies these queries along with all plans within the last hour:

WITH Query_MultPlans
AS (
    SELECT COUNT(*) AS QueryPlanCount,
        q.query_id
    FROM sys.query_store_query_text AS qt
    INNER JOIN sys.query_store_query AS q
        ON qt.query_text_id = q.query_text_id
    INNER JOIN sys.query_store_plan AS p
        ON p.query_id = q.query_id
    GROUP BY q.query_id
    HAVING COUNT(DISTINCT plan_id) > 1
)
SELECT q.query_id,
    object_name(object_id) AS ContainingObject,
    query_sql_text,
    p.plan_id,
    p.query_plan AS plan_xml,
    p.last_compile_start_time,
    p.last_execution_time
FROM Query_MultPlans AS qm
INNER JOIN sys.query_store_query AS q
    ON qm.query_id = q.query_id
INNER JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
INNER JOIN sys.query_store_query_text qt
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON p.plan_id = rs.plan_id
WHERE rs.last_execution_time > DATEADD(HOUR, -1, GETUTCDATE())
ORDER BY q.query_id,
    p.plan_id;
	
-- Highest wait durations
-- This query returns the top 10 queries with the highest wait durations for the last hour:
	
SELECT TOP 10 qt.query_text_id,
    q.query_id,
    p.plan_id,
    sum(total_query_wait_time_ms) AS sum_total_wait_ms
FROM sys.query_store_wait_stats ws
INNER JOIN sys.query_store_plan p
    ON ws.plan_id = p.plan_id
INNER JOIN sys.query_store_query q
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_query_text qt
    ON q.query_text_id = qt.query_text_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON p.plan_id = rs.plan_id
WHERE rs.last_execution_time > DATEADD(HOUR, -1, GETUTCDATE())
GROUP BY qt.query_text_id,
    q.query_id,
    p.plan_id
ORDER BY sum_total_wait_ms DESC;