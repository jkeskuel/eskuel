-- Create a temporary table to store the results
CREATE TABLE #ExtendedPropertiesResults (
    DatabaseName sysname,
    SchemaName sysname,
    TableName sysname,
    ExtendedPropertyName sysname,
    ExtendedPropertyValue sql_variant
);

-- Declare variables for database name and dynamic SQL
DECLARE @DBName sysname;
DECLARE @SQL NVARCHAR(MAX);

-- Cursor to loop through all user databases
DECLARE db_cursor CURSOR FOR
SELECT name FROM sys.databases
WHERE state = 0              -- Only online databases
  AND database_id > 4        -- Exclude system databases (master, model, msdb, tempdb)
  AND is_read_only = 0;      -- Exclude read-only databases

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DBName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
    INSERT INTO #ExtendedPropertiesResults (DatabaseName, SchemaName, TableName, ExtendedPropertyName, ExtendedPropertyValue)
    SELECT
        ''' + QUOTENAME(@DBName) + ''',       -- Database name
        SCHEMA_NAME(tbl.schema_id) AS SchemaName,
        tbl.name AS TableName,
        p.name AS ExtendedPropertyName,
        CAST(p.value AS sql_variant) AS ExtendedPropertyValue
    FROM ' + QUOTENAME(@DBName) + '.sys.tables AS tbl
    INNER JOIN ' + QUOTENAME(@DBName) + '.sys.extended_properties AS p
        ON p.major_id = tbl.object_id AND p.minor_id = 0 AND p.class = 1
    WHERE EXISTS (
        SELECT 1 FROM ' + QUOTENAME(@DBName) + '.sys.extended_properties
        WHERE major_id = tbl.object_id AND minor_id = 0 AND class = 1
    )
	AND p.name= ''Restriction''
	;';

    BEGIN TRY
        -- Execute the dynamic SQL
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        PRINT 'Error accessing database ' + QUOTENAME(@DBName) + ': ' + ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM db_cursor INTO @DBName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Select the collected results
SELECT * FROM #ExtendedPropertiesResults;

-- Clean up the temporary table
DROP TABLE #ExtendedPropertiesResults;
