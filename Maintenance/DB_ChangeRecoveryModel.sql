/* Checks databases in FULL recovery, change to SIMPLE */

DECLARE @sql  nvarchar(max) = N'';

SELECT @sql = @sql + N'ALTER DATABASE ' + QUOTENAME(name) +
               N' SET RECOVERY SIMPLE WITH NO_WAIT;' + CHAR(13)
FROM sys.databases
WHERE recovery_model_desc = 'FULL'
 AND database_id  > 4 

--PRINT @sql;
--exec sp_executesql @sql