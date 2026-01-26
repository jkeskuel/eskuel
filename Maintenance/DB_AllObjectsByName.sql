/* ================================================
   Find Linked Servers and Object References
   Author: Jure Kranjc
   Purpose: Detect any linked servers and T-SQL objects 
            referencing a specific target (e.g. KROMPIR)
   ================================================ */
DECLARE @LinkedServerPattern sysname = N'%KROMPIR%';  -- <-- change pattern as needed
PRINT '--- LINKED SERVERS ---';
SELECT 
    name AS LinkedServerName,
    data_source AS DataSource,
    provider,
    product
FROM sys.servers
WHERE is_linked = 1
  AND (name LIKE @LinkedServerPattern OR data_source LIKE @LinkedServerPattern)
ORDER BY name;
PRINT '--- OBJECT REFERENCES ---';
DECLARE @sql NVARCHAR(MAX) = N'';
-- iterate through all databases
DECLARE db CURSOR LOCAL FAST_FORWARD FOR
SELECT name FROM sys.databases
WHERE state = 0 AND database_id > 4;  -- exclude system DBs (optional)
OPEN db;
DECLARE @dbname sysname;
CREATE TABLE #Refs
(
    DatabaseName sysname,
    SchemaName sysname,
    ObjectName sysname,
    ObjectType NVARCHAR(50),
    DefinitionSnippet NVARCHAR(4000)
);
WHILE 1 = 1
BEGIN
    FETCH NEXT FROM db INTO @dbname;
    IF @@FETCH_STATUS <> 0 BREAK;
    SET @sql = '
    USE ' + QUOTENAME(@dbname) + ';
    INSERT INTO #Refs (DatabaseName, SchemaName, ObjectName, ObjectType, DefinitionSnippet)
    SELECT 
        DB_NAME(),
        s.name,
        o.name,
        o.type_desc,
        LEFT(m.definition, 4000)
    FROM sys.sql_modules m
    JOIN sys.objects o ON m.object_id = o.object_id
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE m.definition LIKE ' + QUOTENAME('%KROMPIR%', '''') + ';';
    EXEC sys.sp_executesql @sql;
END
CLOSE db;
DEALLOCATE db;
SELECT *
FROM #Refs
ORDER BY DatabaseName, SchemaName, ObjectName;
DROP TABLE #Refs;
