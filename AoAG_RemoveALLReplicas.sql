-- Declare variables for looping through all AGs
DECLARE @AGName VARCHAR(512);
DECLARE @SQL NVARCHAR(MAX);

-- Temporary table to hold AG names
CREATE TABLE #AGList (AGName VARCHAR(512));

-- Insert all AG names into the temporary table
INSERT INTO #AGList (AGName)
SELECT name 
FROM sys.availability_groups WITH(NOLOCK);

-- Cursor to iterate through each AG
DECLARE AGCursor CURSOR FOR 
SELECT AGName FROM #AGList;

OPEN AGCursor;
FETCH NEXT FROM AGCursor INTO @AGName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Removing replica mcvmdrprodsql01 from AG: ' + @AGName;

    -- Construct the dynamic SQL to remove the replica
    SET @SQL = N'
    ALTER AVAILABILITY GROUP [' + @AGName + N']
    REMOVE REPLICA ON ''MCVMDRPRODSQL01'';';

    /*
    BEGIN TRY
        EXEC sp_executesql @SQL;
        PRINT 'Replica mcvmdrprodsql01 removed from AG: ' + @AGName;
    END TRY
    BEGIN CATCH
        PRINT 'Error occurred while removing replica from AG: ' + @AGName;
        PRINT ERROR_MESSAGE();
    END CATCH;
	*/

	PRINT @SQL

    FETCH NEXT FROM AGCursor INTO @AGName;
END

-- Cleanup
CLOSE AGCursor;
DEALLOCATE AGCursor;
