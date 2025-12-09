-- =============================================
-- Script: Onboard Top 5 Databases to AG with Auto Seeding
-- Description: Adds up to 5 databases to AG, respecting concurrent seeding limit
-- Usage: Run this script via SQL Agent job every 10 minutes
-- =============================================

SET NOCOUNT ON;

-- Configuration
DECLARE @AGName NVARCHAR(128) = 'YourAGName'; -- Change this to your AG name
DECLARE @MaxConcurrentSeeding INT = 5;

-- Get count of currently seeding databases
DECLARE @CurrentSeeding INT = 0;

SELECT @CurrentSeeding = COUNT(*)
FROM sys.dm_hadr_automatic_seeding
WHERE ag_db_name IS NOT NULL
    AND (current_state IN (0, 1, 2, 3, 4)); -- States: 0=Initializing, 1=Waiting, 2=Hashing, 3=Transferring, 4=Complete
    -- Exclude state 5 (Failed) and 6 (Completed Success)

PRINT 'Currently seeding databases: ' + CAST(@CurrentSeeding AS NVARCHAR(10));
PRINT 'Maximum concurrent seeding allowed: ' + CAST(@MaxConcurrentSeeding AS NVARCHAR(10));

-- Calculate how many new databases can be added
DECLARE @SlotsAvailable INT = @MaxConcurrentSeeding - @CurrentSeeding;

IF @SlotsAvailable <= 0
BEGIN
    PRINT 'Seeding limit reached. No databases will be added at this time.';
    RETURN;
END

PRINT 'Available slots for new databases: ' + CAST(@SlotsAvailable AS NVARCHAR(10));
PRINT '';

-- Get databases not yet in AG (top N based on available slots)
-- Ordered by name - modify ORDER BY clause as needed (e.g., by size, priority, etc.)
DECLARE @DatabasesToAdd TABLE (
    DatabaseName NVARCHAR(128),
    RowNum INT
);

INSERT INTO @DatabasesToAdd (DatabaseName, RowNum)
SELECT TOP (@SlotsAvailable)
    d.name,
    ROW_NUMBER() OVER (ORDER BY d.name) AS RowNum
FROM sys.databases d
WHERE d.database_id > 4 -- Exclude system databases
    AND d.state_desc = 'ONLINE'
    AND d.name NOT IN (
        -- Exclude databases already in the AG
        SELECT database_name
        FROM sys.availability_databases_cluster
        WHERE group_id = (SELECT group_id FROM sys.availability_groups WHERE name = @AGName)
    )
ORDER BY d.name; -- Change to d.log_reuse_wait_desc, size, etc. as needed

-- Display databases to be added
IF NOT EXISTS (SELECT 1 FROM @DatabasesToAdd)
BEGIN
    PRINT 'No databases found to add to AG.';
    RETURN;
END

PRINT 'Databases to be added to AG: ' + @AGName;
SELECT DatabaseName FROM @DatabasesToAdd ORDER BY RowNum;
PRINT '';

-- Add databases to AG
DECLARE @DatabaseName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);

DECLARE db_cursor CURSOR FOR
SELECT DatabaseName FROM @DatabasesToAdd ORDER BY RowNum;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        PRINT 'Adding database: ' + @DatabaseName + ' to AG: ' + @AGName;

        -- Add database to AG (automatic seeding will start automatically)
        SET @SQL = N'ALTER AVAILABILITY GROUP [' + @AGName + N'] ADD DATABASE [' + @DatabaseName + N'];';

        EXEC sp_executesql @SQL;

        PRINT 'Successfully added database: ' + @DatabaseName;
        PRINT '';
    END TRY
    BEGIN CATCH
        PRINT 'Error adding database: ' + @DatabaseName;
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT '';
    END CATCH

    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

PRINT '======================================';
PRINT 'Onboarding process completed.';
PRINT 'Automatic seeding will begin shortly.';
PRINT 'Monitor seeding progress with:';
PRINT 'SELECT * FROM sys.dm_hadr_automatic_seeding;';
PRINT 'SELECT * FROM sys.dm_hadr_physical_seeding_stats;';
PRINT '======================================';
GO
