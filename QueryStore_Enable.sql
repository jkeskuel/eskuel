/***************************************************************************************************
Script:             Enable Query Store
Create Date:        23-01-2024
Author:             J. Kranjc
Description:        Script that enables QUERY STORE on databases that don't have it enabled.
					Script limits MAX_STORAGE_SIZE parameter to 100 MB and enables AUTO capture mode.
					This limits the storage usage and limits what is captured, reducing the overhead.
					
Usage:              Change the WHERE clause to limit the databases listed, by default it limits to
					InDoc% and BP% databases. Skips system databases.
****************************************************************************************************
Note:				Enable global trace flags 7745 and 7752 on SQL Server instance.
					Add -T7745 and -T7752 startup parameters to SQL Server service.

Usage:	DBCC TRACEON(7752,-1)
		DBCC TRACEON(7745,-1)

Description:

Trace FLag 7745	
Forces Query Store to not flush data to disk on database shutdown.

Note: Using this trace flag may cause Query Store data not previously flushed to disk to be lost in case of shutdown.
For a SQL Server shutdown, the command SHUTDOWN WITH NOWAIT can be used instead of this trace flag to force an immediate shutdown.


Trace Flag 7752	
Enables asynchronous load of Query Store.

Note: Use this trace flag if SQL Server is experiencing high number of QDS_LOADDB waits related to Query Store synchronous load (default behavior during database recovery).
Note: Starting with SQL Server 2019 (15.x), this behavior is controlled by the Database Engine and Trace Flag 7752 has no effect.
***************************************************************************************************/

SELECT 'USE [' + db.name + ']; 
ALTER DATABASE [' + db.name + '] SET QUERY_STORE = ON; 
ALTER DATABASE [' + db.name + '] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, MAX_STORAGE_SIZE_MB = 100, QUERY_CAPTURE_MODE = AUTO);' 
FROM sys.databases db 
WHERE db.database_id > 4 /* skip system databases */ 
AND db.is_query_store_on = 0 /* check if query_store already enabled */ 
AND (db.name like 'InDoc%' or db.name like 'BP%') /* filter application databases */ 