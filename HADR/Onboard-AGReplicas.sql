-- =============================================
-- Script: Onboard AG Replicas Starting with SRV-
-- Description: Adds back replicas with names starting with 'SRV-' to the specified Availability Group
-- =============================================

-- Set the Availability Group name and replica configuration
DECLARE @AGName NVARCHAR(128) = 'YourAGName'; -- Change this to your AG name

-- Variables
DECLARE @ReplicaServer NVARCHAR(128);
DECLARE @EndpointURL NVARCHAR(256);
DECLARE @SQL NVARCHAR(MAX);

-- Create temp table to store replicas to onboard
-- Populate this table with the replicas you want to add back
DECLARE @ReplicasToOnboard TABLE (
    ReplicaServerName NVARCHAR(128),
    EndpointURL NVARCHAR(256),
    AvailabilityMode NVARCHAR(20), -- SYNCHRONOUS_COMMIT or ASYNCHRONOUS_COMMIT
    FailoverMode NVARCHAR(20),     -- AUTOMATIC or MANUAL
    BackupPriority INT,             -- 0-100
    ReadableSecondary NVARCHAR(20)  -- NO, READ_ONLY, or ALL
);

-- *** MANUALLY POPULATE THIS TABLE WITH YOUR REPLICAS ***
-- Example:
INSERT INTO @ReplicasToOnboard VALUES
    ('SRV-SQL01', 'TCP://SRV-SQL01.domain.com:5022', 'ASYNCHRONOUS_COMMIT', 'MANUAL', 50, 'READ_ONLY'),
    ('SRV-SQL02', 'TCP://SRV-SQL02.domain.com:5022', 'ASYNCHRONOUS_COMMIT', 'MANUAL', 50, 'READ_ONLY');

-- Display replicas that will be onboarded
SELECT
    'Replicas to be added to AG: ' + @AGName AS Information;

SELECT * FROM @ReplicasToOnboard;

-- Cursor to iterate through replicas
DECLARE replica_cursor CURSOR FOR
SELECT
    ReplicaServerName,
    EndpointURL,
    AvailabilityMode,
    FailoverMode,
    BackupPriority,
    ReadableSecondary
FROM @ReplicasToOnboard;

DECLARE @AvailabilityMode NVARCHAR(20);
DECLARE @FailoverMode NVARCHAR(20);
DECLARE @BackupPriority INT;
DECLARE @ReadableSecondary NVARCHAR(20);

OPEN replica_cursor;
FETCH NEXT FROM replica_cursor INTO @ReplicaServer, @EndpointURL, @AvailabilityMode, @FailoverMode, @BackupPriority, @ReadableSecondary;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        PRINT 'Adding replica: ' + @ReplicaServer + ' to AG: ' + @AGName;

        -- Add the replica to the AG (run on PRIMARY replica)
        SET @SQL = N'ALTER AVAILABILITY GROUP [' + @AGName + ']
                     ADD REPLICA ON N''' + @ReplicaServer + '''
                     WITH (
                         ENDPOINT_URL = N''' + @EndpointURL + ''',
                         AVAILABILITY_MODE = ' + @AvailabilityMode + ',
                         FAILOVER_MODE = ' + @FailoverMode + ',
                         BACKUP_PRIORITY = ' + CAST(@BackupPriority AS NVARCHAR(10)) + ',
                         SECONDARY_ROLE(ALLOW_CONNECTIONS = ' + @ReadableSecondary + '),
                         SEEDING_MODE = AUTOMATIC
                     );';

        PRINT 'Executing: ' + @SQL;
        EXEC sp_executesql @SQL;

        PRINT 'Successfully added replica: ' + @ReplicaServer;
        PRINT 'NOTE: You need to JOIN the AG on the replica server ' + @ReplicaServer;
        PRINT 'Run this on ' + @ReplicaServer + ':';
        PRINT 'ALTER AVAILABILITY GROUP [' + @AGName + '] JOIN;';
        PRINT 'GO';
        PRINT '';
    END TRY
    BEGIN CATCH
        PRINT 'Error adding replica: ' + @ReplicaServer;
        PRINT 'Error Message: ' + ERROR_MESSAGE();
    END CATCH

    FETCH NEXT FROM replica_cursor INTO @ReplicaServer, @EndpointURL, @AvailabilityMode, @FailoverMode, @BackupPriority, @ReadableSecondary;
END

CLOSE replica_cursor;
DEALLOCATE replica_cursor;

PRINT '';
PRINT '======================================';
PRINT 'Onboarding process completed on PRIMARY.';
PRINT 'IMPORTANT: Connect to each replica server and run:';
PRINT 'ALTER AVAILABILITY GROUP [' + @AGName + '] JOIN;';
PRINT 'ALTER AVAILABILITY GROUP [' + @AGName + '] GRANT CREATE ANY DATABASE;';
PRINT '======================================';
GO
