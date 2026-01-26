DECLARE 
    @sourceDb      SYSNAME = 'YOLO', /* Source database name */
    @SQL           NVARCHAR(MAX),
    @SSDBName      SYSNAME,
    @sourcePath    NVARCHAR(512),
    @SnapshotName  SYSNAME;

/* Generate snapshot name with timestamp */
SET @SnapshotName = @sourceDb + '_dbss_' + 
                    REPLACE(CONVERT(VARCHAR(5), GETDATE(), 108), ':', '') + '_' +
                    CONVERT(VARCHAR, GETDATE(), 112);

/* Get the path to the data file (excluding filename) */
SELECT @sourcePath = LEFT(physical_name, LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name)))
FROM sys.master_files
WHERE database_id = DB_ID(@sourceDb)
  AND type_desc = 'ROWS';

/* Drop temp table if it exists */
IF OBJECT_ID('tempdb..##DBObjects', 'U') IS NOT NULL
    DROP TABLE ##DBObjects;

/* Copy database file metadata to a global temp table */
SET @SQL = '
    SELECT *
    INTO ##DBObjects
    FROM [' + @sourceDb + '].sys.database_files;
';
EXEC sp_executesql @SQL;

/* Build CREATE DATABASE AS SNAPSHOT OF command */
SET @SQL = 'CREATE DATABASE [' + @SnapshotName + '_dbss] ON ';

SELECT @SQL += 
    '(NAME = ' + name + ', FILENAME = ''' + @sourcePath + '\' + name + '_ss''),'
FROM ##DBObjects
WHERE type_desc = 'ROWS';

/* Remove the trailing comma */
SET @SQL = LEFT(@SQL, LEN(@SQL) - 1);

/* Append snapshot clause */
SET @SQL += ' AS SNAPSHOT OF [' + @sourceDb + '];';

/* Uncomment the next line to execute the snapshot creation */
/* EXEC sp_executesql @SQL; */

/* Print the final SQL command */
PRINT @SQL;
