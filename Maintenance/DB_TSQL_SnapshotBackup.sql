/*Take a T-SQL snapshot backup with METADATA ONLY
also useful for AG seeding to trigger backup chain*/

USE [master];
GO

DECLARE @LikeFilter       nvarchar(200) = N'Baza%'; 
DECLARE @BackupFolder     nvarchar(4000) = N'D:\SQL2022\Backup';  -- Backup pot, BREZ \ !
DECLARE @Stamp            nvarchar(32)  =  -- Ne diraj!
    CONVERT(nvarchar(8),  SYSDATETIME(), 112) + N'_' +
    REPLACE(CONVERT(nvarchar(8), SYSDATETIME(), 108),':','');
DECLARE @BackupPath       nvarchar(4000) = @BackupFolder + N'\Group_' + @Stamp + N'.bmk';
DECLARE @sql nvarchar(max);
DECLARE @groupList nvarchar(max);

IF TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) < 16
    THROW 55555, 'Deluje samo na SQL2022 ali novejši!', 1;

-- Seznam baz, samo ONLINE in BREZ sistemskih
;WITH DbList AS (
    SELECT name
    FROM sys.databases
    WHERE database_id > 4
      AND state_desc = 'ONLINE'
      AND name LIKE @LikeFilter
)
SELECT @groupList = STRING_AGG(QUOTENAME(name), N', ')
FROM DbList;

IF @groupList IS NULL OR LEN(@groupList) = 0
    THROW 55556, 'Baza s tem filtrom ne obstaja!', 1;


-- Zažene snasphotanje
BEGIN TRY

    SET @sql = N'ALTER SERVER CONFIGURATION
                 SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON
                 (GROUP = (' + @groupList + N'));';
    EXEC sp_executesql @sql;


    SET @sql = N'BACKUP GROUP ' + @groupList + N'
                TO DISK = @p
                WITH METADATA_ONLY, FORMAT;';
    EXEC sp_executesql @sql, N'@p nvarchar(4000)', @p = @BackupPath;

END TRY
-- Za vsak slucaj, da baze ne ostanejo zamrznjene
BEGIN CATCH
   SET @sql = N'ALTER SERVER CONFIGURATION
                SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF
                (GROUP = (' + @groupList + N'));';
   EXEC sp_executesql @sql;
END CATCH;

PRINT N'Backup uspešen, pot backupa: ' + @BackupPath;
