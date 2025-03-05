IF EXISTS (
    SELECT 1 
    FROM sys.server_event_sessions 
    WHERE name = 'DBA_BlockedQueries'
)
BEGIN
    PRINT 'Dropping existing event session: DBA_BlockedQueries';
    DROP EVENT SESSION [DBA_BlockedQueries] ON SERVER;
END;
CREATE EVENT SESSION [DBA_BlockedQueries] ON SERVER 
ADD EVENT sqlserver.blocked_process_report(
    ACTION(package0.process_id,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_id,sqlserver.database_name,sqlserver.session_nt_username,sqlserver.sql_text)
    WHERE ([duration]>=(5000000)))
ADD TARGET package0.event_file(SET filename=N'DBA_BlockedQueries.xel',max_file_size=(512),max_rollover_files=(4))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

IF EXISTS (
    SELECT 1 
    FROM sys.server_event_sessions 
    WHERE name = 'DBA_Deadlocks'
)
BEGIN
    PRINT 'Dropping existing event session: DBA_Deadlocks';
    DROP EVENT SESSION [DBA_Deadlocks] ON SERVER;
END;
CREATE EVENT SESSION [DBA_Deadlocks] ON SERVER 
ADD EVENT sqlserver.xml_deadlock_report(
    ACTION(package0.callstack,sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.client_pid,sqlserver.database_id,sqlserver.database_name,sqlserver.is_system,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id,sqlserver.tsql_stack,sqlserver.username))
ADD TARGET package0.event_file(SET filename=N'DBA_Deadlocks.xel',max_file_size=(512),max_rollover_files=(4))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

IF EXISTS (
    SELECT 1 
    FROM sys.server_event_sessions 
    WHERE name = 'DBA_Diagnostics'
)
BEGIN
    PRINT 'Dropping existing event session: DBA_Diagnostics';
    DROP EVENT SESSION [DBA_Diagnostics] ON SERVER;
END;
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
ADD TARGET package0.event_file(SET filename=N'DBA_Diagnostics.xel',max_file_size=(512),max_rollover_files=(4))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO

IF EXISTS (
    SELECT 1 
    FROM sys.server_event_sessions 
    WHERE name = 'DBA_WaitEvents'
)
BEGIN
    PRINT 'Dropping existing event session: DBA_WaitEvents';
    DROP EVENT SESSION [DBA_WaitEvents] ON SERVER;
END;
CREATE EVENT SESSION [DBA_WaitEvents] ON SERVER 
ADD EVENT sqlos.wait_completed(
    ACTION(package0.callstack,sqlserver.database_id,sqlserver.database_name,sqlserver.session_id,sqlserver.sql_text,sqlserver.transaction_id,sqlserver.transaction_sequence)
    WHERE ([package0].[greater_than_uint64]([duration],(4000)) AND ([package0].[greater_than_equal_uint64]([wait_type],'LATCH_NL') AND ([package0].[greater_than_equal_uint64]([wait_type],'PAGELATCH_NL') AND [package0].[less_than_equal_uint64]([wait_type],'PAGELATCH_DT') OR [package0].[less_than_equal_uint64]([wait_type],'LATCH_DT') OR [package0].[greater_than_equal_uint64]([wait_type],'PAGEIOLATCH_NL') AND [package0].[less_than_equal_uint64]([wait_type],'PAGEIOLATCH_DT') OR [package0].[greater_than_equal_uint64]([wait_type],'IO_COMPLETION') AND [package0].[less_than_equal_uint64]([wait_type],'NETWORK_IO') OR [package0].[equal_uint64]([wait_type],'RESOURCE_SEMAPHORE') OR [package0].[equal_uint64]([wait_type],'SOS_WORKER') OR [package0].[greater_than_equal_uint64]([wait_type],'FCB_REPLICA_WRITE') AND [package0].[less_than_equal_uint64]([wait_type],'WRITELOG') OR [package0].[equal_uint64]([wait_type],'CMEMTHREAD') OR [package0].[equal_uint64]([wait_type],'TRACEWRITE') OR [package0].[equal_uint64]([wait_type],'RESOURCE_SEMAPHORE_MUTEX')) OR [package0].[greater_than_uint64]([duration],(15000)) AND [package0].[less_than_equal_uint64]([wait_type],'LCK_M_RX_X'))))
ADD TARGET package0.event_file(SET filename=N'DBA_WaitEvents.xel',max_file_size=(512),max_rollover_files=(4))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

ALTER EVENT SESSION [DBA_BlockedQueries] ON SERVER  
STATE = start;  
GO  

ALTER EVENT SESSION [DBA_Deadlocks] ON SERVER  
STATE = start;  
GO  

ALTER EVENT SESSION [DBA_Diagnostics] ON SERVER  
STATE = start;  
GO  

ALTER EVENT SESSION [DBA_WaitEvents] ON SERVER  
STATE = start;  
GO  