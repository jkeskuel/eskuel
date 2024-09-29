/*
Seja za spremljanje dolgih/pozresnih poizvedb
*/

CREATE EVENT SESSION [DBA_Diagnostics] ON SERVER 
ADD EVENT sqlserver.rpc_completed(SET collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_connection_id,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id,sqlserver.transaction_id,sqlserver.username)
    WHERE ([package0].[greater_than_equal_uint64]([duration],(4000000)) OR [package0].[not_equal_uint64]([result],'OK'))),
ADD EVENT sqlserver.sp_statement_completed(SET collect_object_name=(1),collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_connection_id,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id,sqlserver.transaction_id,sqlserver.username)
    WHERE ([package0].[greater_than_equal_int64]([duration],(4000000)))),
ADD EVENT sqlserver.sql_batch_completed(SET collect_batch_text=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_connection_id,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id,sqlserver.transaction_id,sqlserver.username)
    WHERE ([package0].[greater_than_equal_uint64]([duration],(4000000)) OR [package0].[not_equal_uint64]([result],'OK'))),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.client_app_name,sqlserver.client_connection_id,sqlserver.client_hostname,sqlserver.database_name,sqlserver.plan_handle,sqlserver.query_hash,sqlserver.query_plan_hash,sqlserver.session_id,sqlserver.transaction_id,sqlserver.username)
    WHERE ([duration]>=(4000000)))
ADD TARGET package0.event_file(SET filename=N'DBA_Diagnostics.xel',max_file_size=(100),max_rollover_files=(20))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO

/*
Seja za spremljanje blokiranj
Konfiguracija je za blokiranja, ki trajajo več kot 6 sekund
*/

CREATE EVENT SESSION [DBA_BlockedQueries] ON SERVER 
ADD EVENT sqlserver.blocked_process_report(
    ACTION(package0.process_id,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.session_nt_username,sqlserver.sql_text)
    WHERE ([duration]>=(6000000)))
ADD TARGET package0.event_file(SET filename=N'DBA_BlockedQueries.xel',max_rollover_files=(5))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

/*
Zagon obeh sej
*/

ALTER EVENT SESSION [DBA_Diagnostics] ON SERVER  
STATE = start;  
GO  

ALTER EVENT SESSION [DBA_BlockedQueries] ON SERVER  
STATE = start;  
GO  

/*
Spodnji ukaz vklopi dodatne opcije, nato nastavi blocked process threshold na 6 sekund
Tako lahko seja zgoraj "lovi" blokiranja, drugace je privzeta vrednost 15 sekund
*/

sp_configure 'show advanced options', 1;
GO

RECONFIGURE;
GO

sp_configure 'blocked process threshold', 6;
GO

RECONFIGURE;
GO

sp_configure 'show advanced options', 0;
GO

RECONFIGURE;
GO