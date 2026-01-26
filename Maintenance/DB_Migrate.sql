/*This is for TempDB*/
SELECT 'ALTER DATABASE ['+ DB_NAME(f.database_id) +'] MODIFY FILE (NAME = [' + f.name + '],'
	+ ' FILENAME = ''Z:\MSSQL\DATA\' + /*CHANGE TO NEW TEMPDB!*/
	+ RIGHT(f.physical_name, CHARINDEX('\', REVERSE(f.physical_name)) - 1)
	+ ''');'
FROM sys.master_files f
WHERE 1= 1
AND f.database_id = DB_ID(N'tempdb')



/*This is for Databases*/
SELECT 'ALTER DATABASE ['+ DB_NAME(f.database_id) +'] MODIFY FILE (NAME = [' + f.name + '],'
	+ ' FILENAME = ''H:\SQLdata\' + /*CHANGE TO NEW!*/
	+ RIGHT(f.physical_name, CHARINDEX('\', REVERSE(f.physical_name)) - 1)
	+ ''');'
FROM sys.master_files f
WHERE 1= 1
AND f.database_id > 5
AND f.type != 1