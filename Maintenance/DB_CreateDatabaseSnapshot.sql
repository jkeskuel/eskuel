/*
    Creates a database snapshot with proper handling of multiple data files
    Works on both Windows and Linux paths
*/

DECLARE 
    @SourceDB       SYSNAME = 'YOLO',  -- Source database name
    @SnapshotSuffix NVARCHAR(50) = NULL, -- Optional suffix, defaults to timestamp
    @SnapshotName   SYSNAME,
    @SQL            NVARCHAR(MAX);

-- Generate snapshot name
IF @SnapshotSuffix IS NULL
    SET @SnapshotSuffix = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');

SET @SnapshotName = @SourceDB + '_ss_' + @SnapshotSuffix;

-- Check if source database exists
IF DB_ID(@SourceDB) IS NULL
BEGIN
    RAISERROR('Database [%s] does not exist', 16, 1, @SourceDB);
    RETURN;
END;

-- Check if snapshot already exists
IF DB_ID(@SnapshotName) IS NOT NULL
BEGIN
    RAISERROR('Snapshot [%s] already exists', 16, 1, @SnapshotName);
    RETURN;
END;

-- Build CREATE DATABASE statement
SET @SQL = N'CREATE DATABASE ' + QUOTENAME(@SnapshotName) + N' ON ' + CHAR(13) + CHAR(10);

-- Add each data file (ROWS only, no logs)
SELECT @SQL = @SQL + 
    N'(NAME = ' + QUOTENAME(name, '''') + 
    N', FILENAME = ' + QUOTENAME(
        -- Extract directory path (works on Windows and Linux)
        LEFT(physical_name, 
             LEN(physical_name) - CHARINDEX(
                 CASE WHEN physical_name LIKE '%/%' THEN '/' ELSE '\' END, 
                 REVERSE(physical_name)
             )
        ) + 
        CASE WHEN physical_name LIKE '%/%' THEN '/' ELSE '\' END +
        name + '_' + @SnapshotSuffix + '.ss'
    , '''') + 
    N'),' + CHAR(13) + CHAR(10)
FROM sys.master_files
WHERE database_id = DB_ID(@SourceDB)
  AND type = 0  -- ROWS only (data files)
ORDER BY file_id;

-- Remove trailing comma and add snapshot clause
SET @SQL = LEFT(@SQL, LEN(@SQL) - 3) + CHAR(13) + CHAR(10);
SET @SQL = @SQL + N'AS SNAPSHOT OF ' + QUOTENAME(@SourceDB) + N';';

-- Print the command
PRINT @SQL;
PRINT '';
PRINT 'To create the snapshot, uncomment the EXEC line below:';
PRINT '';

-- Execute (uncomment to actually create the snapshot)
-- EXEC sp_executesql @SQL;

-- To verify snapshot after creation:
-- SELECT name, create_date, source_database_id 
-- FROM sys.databases 
-- WHERE source_database_id = DB_ID(@SourceDB);
