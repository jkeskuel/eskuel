--=============================================================
-- Overall Resource Consumption Report
--=============================================================

DECLARE @interval_start_time datetimeoffset(7) = '2025-10-02 19:59:36.4294829 +02:00'
DECLARE @interval_end_time datetimeoffset(7) = '2025-11-02 18:59:36.4294829 +01:00'

;WITH DateGenerator AS
(
SELECT CAST(@interval_start_time AS DATETIME) DatePlaceHolder
UNION ALL
SELECT  DATEADD(d, 1, DatePlaceHolder)
FROM    DateGenerator
WHERE   DATEADD(d, 1, DatePlaceHolder) < @interval_end_time
), WaitStats AS
(
SELECT
    ROUND(CONVERT(float, SUM(ws.total_query_wait_time_ms))*1,2) total_query_wait_time
FROM sys.query_store_wait_stats ws
    JOIN sys.query_store_runtime_stats_interval itvl ON itvl.runtime_stats_interval_id = ws.runtime_stats_interval_id
WHERE NOT (itvl.start_time > @interval_end_time OR itvl.end_time < @interval_start_time)
GROUP BY DATEDIFF(d, 0, itvl.end_time)
),
UnionAll AS
(
SELECT
    CONVERT(float, SUM(rs.count_executions)) as total_count_executions,
    ROUND(CONVERT(float, SUM(rs.avg_duration*rs.count_executions))*0.001,2) as total_duration,
    ROUND(CONVERT(float, SUM(rs.avg_cpu_time*rs.count_executions))*0.001,2) as total_cpu_time,
    ROUND(CONVERT(float, SUM(rs.avg_logical_io_reads*rs.count_executions))*8,2) as total_logical_io_reads,
    ROUND(CONVERT(float, SUM(rs.avg_logical_io_writes*rs.count_executions))*8,2) as total_logical_io_writes,
    ROUND(CONVERT(float, SUM(rs.avg_physical_io_reads*rs.count_executions))*8,2) as total_physical_io_reads,
    ROUND(CONVERT(float, SUM(rs.avg_clr_time*rs.count_executions))*0.001,2) as total_clr_time,
    ROUND(CONVERT(float, SUM(rs.avg_dop*rs.count_executions))*1,0) as total_dop,
    ROUND(CONVERT(float, SUM(rs.avg_query_max_used_memory*rs.count_executions))*8,2) as total_query_max_used_memory,
    ROUND(CONVERT(float, SUM(rs.avg_rowcount*rs.count_executions))*1,0) as total_rowcount,
    ROUND(CONVERT(float, SUM(rs.avg_log_bytes_used*rs.count_executions))*0.0009765625,2) as total_log_bytes_used,
    ROUND(CONVERT(float, SUM(rs.avg_tempdb_space_used*rs.count_executions))*8,2) as total_tempdb_space_used,
    DATEADD(d, ((DATEDIFF(d, 0, rs.last_execution_time))),0 ) as bucket_start,
    DATEADD(d, (1 + (DATEDIFF(d, 0, rs.last_execution_time))), 0) as bucket_end
FROM sys.query_store_runtime_stats rs
WHERE NOT (rs.first_execution_time > @interval_end_time OR rs.last_execution_time < @interval_start_time)
GROUP BY DATEDIFF(d, 0, rs.last_execution_time)
)
SELECT 
    total_count_executions,
    total_duration,
    total_cpu_time,
    total_logical_io_reads,
    total_logical_io_writes,
    total_physical_io_reads,
    total_clr_time,
    total_dop,
    total_query_max_used_memory,
    total_rowcount,
    total_log_bytes_used,
    total_tempdb_space_used,
    total_query_wait_time,
    SWITCHOFFSET(bucket_start, DATEPART(tz, @interval_start_time)) , SWITCHOFFSET(bucket_end, DATEPART(tz, @interval_start_time))
FROM
(
SELECT *, ROW_NUMBER() OVER (PARTITION BY bucket_start ORDER BY bucket_start, total_duration DESC) AS RowNumber
FROM UnionAll , WaitStats
) as UnionAllResults
WHERE UnionAllResults.RowNumber = 1
OPTION (MAXRECURSION 0,RECOMPILE)

--=============================================================
-- Top Resource Consuming Queries Report
--=============================================================

DECLARE @results_row_count int = 25
DECLARE @interval_start_time datetimeoffset(7) = '2025-11-02 18:05:20.8908655 +01:00'
DECLARE @interval_end_time datetimeoffset(7) = '2025-11-02 19:05:20.8908655 +01:00'

;WITH wait_stats AS
(
SELECT
    ws.plan_id plan_id,
    ws.wait_category,
    ROUND(CONVERT(float, SUM(ws.total_query_wait_time_ms)/SUM(ws.total_query_wait_time_ms/ws.avg_query_wait_time_ms))*1,2) avg_query_wait_time,
    ROUND(CONVERT(float, SQRT( SUM(ws.stdev_query_wait_time_ms*ws.stdev_query_wait_time_ms*(ws.total_query_wait_time_ms/ws.avg_query_wait_time_ms))/SUM(ws.total_query_wait_time_ms/ws.avg_query_wait_time_ms)))*1,2) stdev_query_wait_time,
    CAST(ROUND(SUM(ws.total_query_wait_time_ms/ws.avg_query_wait_time_ms),0) AS BIGINT) count_executions,
    MAX(itvl.end_time) last_execution_time,
    MIN(itvl.start_time) first_execution_time
FROM sys.query_store_wait_stats ws
    JOIN sys.query_store_runtime_stats_interval itvl ON itvl.runtime_stats_interval_id = ws.runtime_stats_interval_id
WHERE NOT (itvl.start_time > @interval_end_time OR itvl.end_time < @interval_start_time)
GROUP BY ws.plan_id, ws.runtime_stats_interval_id, ws.wait_category
),
top_wait_stats AS
(
SELECT 
    p.query_id query_id,
    q.object_id object_id,
    ISNULL(OBJECT_NAME(q.object_id),'') object_name,
    qt.query_sql_text query_sql_text,
    ROUND(CONVERT(float, SUM(ws.avg_query_wait_time*ws.count_executions))*1,2) total_query_wait_time,
    MAX(ws.count_executions) count_executions,
    COUNT(distinct p.plan_id) num_plans
FROM wait_stats ws
    JOIN sys.query_store_plan p ON p.plan_id = ws.plan_id
    JOIN sys.query_store_query q ON q.query_id = p.query_id
    JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
WHERE NOT (ws.first_execution_time > @interval_end_time OR ws.last_execution_time < @interval_start_time)
GROUP BY p.query_id, qt.query_sql_text, q.object_id
),
top_other_stats AS
(
SELECT 
    p.query_id query_id,
    q.object_id object_id,
    ISNULL(OBJECT_NAME(q.object_id),'') object_name,
    qt.query_sql_text query_sql_text,
    ROUND(CONVERT(float, SUM(rs.avg_duration*rs.count_executions))*0.001,2) total_duration,
    ROUND(CONVERT(float, SUM(rs.avg_cpu_time*rs.count_executions))*0.001,2) total_cpu_time,
    ROUND(CONVERT(float, SUM(rs.avg_logical_io_reads*rs.count_executions))*8,2) total_logical_io_reads,
    ROUND(CONVERT(float, SUM(rs.avg_logical_io_writes*rs.count_executions))*8,2) total_logical_io_writes,
    ROUND(CONVERT(float, SUM(rs.avg_physical_io_reads*rs.count_executions))*8,2) total_physical_io_reads,
    ROUND(CONVERT(float, SUM(rs.avg_clr_time*rs.count_executions))*0.001,2) total_clr_time,
    ROUND(CONVERT(float, SUM(rs.avg_dop*rs.count_executions))*1,0) total_dop,
    ROUND(CONVERT(float, SUM(rs.avg_query_max_used_memory*rs.count_executions))*8,2) total_query_max_used_memory,
    ROUND(CONVERT(float, SUM(rs.avg_rowcount*rs.count_executions))*1,0) total_rowcount,
    ROUND(CONVERT(float, SUM(rs.avg_log_bytes_used*rs.count_executions))*0.0009765625,2) total_log_bytes_used,
    ROUND(CONVERT(float, SUM(rs.avg_tempdb_space_used*rs.count_executions))*8,2) total_tempdb_space_used,
    SUM(rs.count_executions) count_executions,
    COUNT(distinct p.plan_id) num_plans
FROM sys.query_store_runtime_stats rs
    JOIN sys.query_store_plan p ON p.plan_id = rs.plan_id
    JOIN sys.query_store_query q ON q.query_id = p.query_id
    JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
WHERE NOT (rs.first_execution_time > @interval_end_time OR rs.last_execution_time < @interval_start_time)
GROUP BY p.query_id, qt.query_sql_text, q.object_id
)
SELECT TOP (@results_row_count)
    A.query_id query_id,
    A.object_id object_id,
    A.object_name object_name,
    A.query_sql_text query_sql_text,
    A.total_duration total_duration,
    A.total_cpu_time total_cpu_time,
    A.total_logical_io_reads total_logical_io_reads,
    A.total_logical_io_writes total_logical_io_writes,
    A.total_physical_io_reads total_physical_io_reads,
    A.total_clr_time total_clr_time,
    A.total_dop total_dop,
    A.total_query_max_used_memory total_query_max_used_memory,
    A.total_rowcount total_rowcount,
    A.total_log_bytes_used total_log_bytes_used,
    A.total_tempdb_space_used total_tempdb_space_used,
    ISNULL(B.total_query_wait_time,0) total_query_wait_time,
    A.count_executions count_executions,
    A.num_plans num_plans
FROM top_other_stats A LEFT JOIN top_wait_stats B on A.query_id = B.query_id and A.query_sql_text = B.query_sql_text and A.object_id = B.object_id
WHERE A.num_plans >= 1
ORDER BY total_duration DESC