-- =============================================
-- Script: Evict AG Replicas Starting with SRV-
-- Description: Removes replicas with names starting with 'SRV-' from the specified Availability Group
-- =============================================

-- Set the Availability Group name
DECLARE @AGName NVARCHAR(128) = 'YourAGName'; -- Change this to your AG name

-- Variables
DECLARE @ReplicaName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);

-- Create temp table to store replicas to evict
DECLARE @ReplicasToEvict TABLE (
    ReplicaName NVARCHAR(128),
    ReplicaServerName NVARCHAR(128)
);

-- Get all replicas starting with SRV- for the specified AG
INSERT INTO @ReplicasToEvict (ReplicaName, ReplicaServerName)
SELECT
    ar.replica_server_name,
    ar.replica_server_name
FROM sys.availability_replicas ar
INNER JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
WHERE ag.name = @AGName
    AND ar.replica_server_name LIKE 'SRV-%'
    AND ar.replica_server_name <> @@SERVERNAME; -- Don't evict the current server

-- Display replicas that will be evicted
SELECT
    'Replicas to be evicted from AG: ' + @AGName AS Information;

SELECT * FROM @ReplicasToEvict;

-- Cursor to iterate through replicas
DECLARE replica_cursor CURSOR FOR
SELECT ReplicaServerName FROM @ReplicasToEvict;

OPEN replica_cursor;
FETCH NEXT FROM replica_cursor INTO @ReplicaName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        PRINT 'Removing replica: ' + @ReplicaName + ' from AG: ' + @AGName;

        -- Remove the replica from the AG
        SET @SQL = N'ALTER AVAILABILITY GROUP [' + @AGName + ']
                     REMOVE REPLICA ON N''' + @ReplicaName + ''';';

        EXEC sp_executesql @SQL;

        PRINT 'Successfully removed replica: ' + @ReplicaName;
    END TRY
    BEGIN CATCH
        PRINT 'Error removing replica: ' + @ReplicaName;
        PRINT 'Error Message: ' + ERROR_MESSAGE();
    END CATCH

    FETCH NEXT FROM replica_cursor INTO @ReplicaName;
END

CLOSE replica_cursor;
DEALLOCATE replica_cursor;

PRINT 'Eviction process completed.';
GO
