-- Get log size (MB) and % used for each database
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#DBA_LogStats') IS NOT NULL DROP TABLE #DBA_LogStats;

CREATE TABLE #DBA_LogStats (
    database_name sysname,
    log_size_mb DECIMAL(18,2),
    log_used_mb DECIMAL(18,2),
    log_used_percent DECIMAL(5,2)
);

DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += '
USE [' + name + '];
INSERT INTO #DBA_LogStats (database_name, log_size_mb, log_used_mb, log_used_percent)
SELECT
    DB_NAME(),
    total_log_size_in_bytes / 1048576.0 AS log_size_mb,
    used_log_space_in_bytes / 1048576.0 AS log_used_mb,
    used_log_space_in_percent
FROM sys.dm_db_log_space_usage;
'
FROM sys.databases
WHERE state_desc = 'ONLINE' 
and recovery_model_desc != 'SIMPLE'
--AND name NOT IN ('tempdb'); 

EXEC sp_executesql @sql;

SELECT * FROM #DBA_LogStats
ORDER BY log_used_percent DESC;

--DROP TABLE #DBA_LogStats;
