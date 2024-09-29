/***************************************************************************************************
Script:             Extended Events
Create Date:        23-01-2024
Author:             J. Kranjc
Description:        Script that creates Extended Events (EE) that track SQL Server traces and store them in .xel file on filesystem.
		
					Creates EE:
					* DBA_BlockedQueries
						- Traces blocking session that exceed specified duration
						- Blocking value is defined in sp_configure
						- sp_configure N'blocked process threshold (s)'
					* DBA_Deadlocks
						- Traces deadlock events
						- Returns deadlock XML and graph
					* DBA_ImplicitConversion
						- Traces implicit conversions
						- limits to conversion affecting plan generation
					* DBA_LongRunningQueries
						- Traces SQL queries that take long time to run
						- predefined value is 10 second ( in microseconds )
					
Usage:              Run the script, it generated EE on the instance with defined values.

***************************************************************************************************/


CREATE EVENT SESSION [DBA_BlockedQueries] ON SERVER 
ADD EVENT sqlserver.blocked_process_report(
    ACTION(package0.process_id,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.session_nt_username,sqlserver.sql_text)
    WHERE ([duration]>=(5000000)))
ADD TARGET package0.event_file(SET filename=N'R:\EXTENDEDEVENTS\DBA_BlockedQueries.xel',max_rollover_files=(0))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

CREATE EVENT SESSION [DBA_Deadlocks] ON SERVER 
ADD EVENT sqlserver.xml_deadlock_report(
    ACTION(package0.callstack,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.client_pid,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id,sqlserver.tsql_stack,sqlserver.username))
ADD TARGET package0.event_file(SET filename=N'R:\EXTENDEDEVENTS\DBA_Deadlocks.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

CREATE EVENT SESSION [DBA_ImplicitConversion] ON SERVER 
ADD EVENT sqlserver.plan_affecting_convert(
    ACTION(sqlserver.database_name,sqlserver.plan_handle,sqlserver.sql_text))
ADD TARGET package0.event_file(SET filename=N'R:\EXTENDEDEVENTS\ImplicitConversion.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

CREATE EVENT SESSION [DBA_LongRunningQueries] ON SERVER 
ADD EVENT sqlserver.sql_statement_completed(SET collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name)
    WHERE ([duration]>(10000000)))
ADD TARGET package0.event_file(SET filename=N'R:\EXTENDEDEVENTS\DBA_LongRunningQueries.xel')
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO


