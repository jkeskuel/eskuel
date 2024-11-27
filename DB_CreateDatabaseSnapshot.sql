 DECLARE 
@sourceDb sysname,
@SQL nvarchar(max),
@SSDBName sysname,
@sourcePath nvarchar(512),
@SnapshotName sysname;
  
SET @sourceDb = 'admindb'; -- IME BAZE

SET @SnapshotName = @sourceDb +'_dbss_' + replace(convert(varchar(5),getdate(),108), ':', '') + '_' + convert(varchar, getdate(), 112)

SELECT @sourcePath = LEFT(physical_name, LEN(physical_name)- CHARINDEX('\',REVERSE(physical_name))) 
FROM sys.master_files 
WHERE database_id = DB_ID(@sourceDb) 
AND type_desc = 'ROWS'

  IF OBJECT_ID('tempdb..##DBObjects' , 'U') IS NOT NULL
   drop TABLE #DBObjects

  SELECT TOP(0) DB= CONVERT(sysname,''), *
  INTO #DBObjects
  FROM sys.database_files

  EXEC sp_Msforeachdb  'USE [?];INSERT INTO #DBObjects select ''[?]'', * from sys.database_files ';

  SELECT @SQL='CREATE DATABASE ['+@SnapshotName+'_dbss] ON ';
  SELECT @SQL+='(NAME='+NAME+',filename='''+ @sourcePath + '\' + NAME + '_ss''),'
  FROM #DBObjects 
  WHERE db='['+@sourceDb+']' 
  AND type_desc = 'ROWS';
  SELECT @SQL=substring(@SQL,1,len(@SQL)-1);

  SELECT @SQL+= ' AS SNAPSHOT OF ['+@sourceDb +']; ';

  --EXEC sys.sp_executesql @SQL;
  PRINT @SQL