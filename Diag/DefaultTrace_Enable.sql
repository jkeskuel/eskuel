/***************************************************************************************************
Script:             Store default trace events
Create Date:        23-01-2024
Author:             J. Kranjc
Description:        Script that creates a table in DBA database for storing default trace events.
					Creates 2 procedures, one for filling data and one for cleaning stale records.
					Creates SQL Agent Job to run the procedures every hour.
					
Usage:              Change the database name.
					Check the database name in SQL Agent job script

***************************************************************************************************/

/*	Create table dbo.DefaultTrace_History with default trace events. */
USE [$DbAdmin] 
GO

DECLARE @path NVARCHAR(260);
SELECT @path = REVERSE(SUBSTRING(REVERSE([path]), 
 CHARINDEX('\', REVERSE([path])), 260)) + N'log.trc'
  FROM sys.traces WHERE is_default = 1;
SELECT  
 TextData = CONVERT(NVARCHAR(MAX), TextData),
 DatabaseID,
 HostName,
 ApplicationName,
 LoginName,
 SPID,
 StartTime,
 EndTime,
 Duration,
 ObjectID,
 ObjectType,
 IndexID,
 EventClass,
 [FileName],
 RowCounts,
 IsSystem,
 SqlHandle = CONVERT(VARBINARY(MAX), SqlHandle)
INTO dbo.DefaultTrace_History
FROM sys.fn_trace_gettable(@path, DEFAULT);
CREATE CLUSTERED INDEX IX_StartTime ON dbo.DefaultTrace_History(StartTime);

USE [$DbAdmin]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*	Fills table dbo.DefaultTrace_History with default trace events. */
CREATE OR ALTER PROCEDURE [dbo].[DBA_FillDefaultTraceHistory]

AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @path NVARCHAR(260);
	DECLARE @maxDT DATETIME;

	SELECT @path = REVERSE(SUBSTRING(REVERSE([path]), CHARINDEX('\', REVERSE([path])), 260)) + N'log.trc'
	FROM sys.traces WHERE is_default = 1;
	
	SELECT @maxDT = MAX(StartTime)
	FROM [$DbAdmin].[dbo].[DefaultTrace_History];

	BEGIN TRY
		BEGIN TRANSACTION
		INSERT INTO [$DbAdmin].[dbo].[DefaultTrace_History]
			SELECT  
			TextData = CONVERT(NVARCHAR(MAX), TextData),
			DatabaseID,	HostName,ApplicationName,LoginName,
			SPID,StartTime,	EndTime,Duration,ObjectID,
			ObjectType,	IndexID,EventClass,	[FileName],	RowCounts,
			IsSystem,
			SqlHandle = CONVERT(VARBINARY(MAX), SqlHandle)
			FROM sys.fn_trace_gettable(@path, DEFAULT)
			WHERE StartTime > @maxDT;
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		INSERT INTO dbo.DBErrors
		VALUES
		(SUSER_SNAME(),
		 ERROR_NUMBER(),
		 ERROR_STATE(),
		 ERROR_SEVERITY(),
		 ERROR_LINE(),
		 ERROR_PROCEDURE(),
		 ERROR_MESSAGE(),
		 GETDATE());
		/* Transaction uncommittable */
		IF (XACT_STATE()) = -1
		  ROLLBACK TRANSACTION
 
		/* Transaction committable */
		IF (XACT_STATE()) = 1
		  COMMIT TRANSACTION
	END CATCH
END
GO

/* Deletes records from table dbo.DefaultTrace_History, that are older than 15 Days. */
CREATE OR ALTER PROCEDURE [dbo].[DBA_CleanDefaultTraceHistory] 

AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @retDT datetime2

	SELECT @retDT =  DATEADD(DAY, -15, CURRENT_TIMESTAMP)

	BEGIN TRY
		BEGIN TRANSACTION
			DELETE [$DbAdmin].dbo.DefaultTrace_History 
			WHERE StartTime < @retDT;
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		INSERT INTO dbo.DBErrors
		VALUES
		(SUSER_SNAME(),
		 ERROR_NUMBER(),
		 ERROR_STATE(),
		 ERROR_SEVERITY(),
		 ERROR_LINE(),
		 ERROR_PROCEDURE(),
		 ERROR_MESSAGE(),
		 GETDATE());
		/* Transaction uncommittable */
		IF (XACT_STATE()) = -1
		  ROLLBACK TRANSACTION
 
		/* Transaction committable */
		IF (XACT_STATE()) = 1
		  COMMIT TRANSACTION
	END CATCH
END
GO


/* Create SQL Agent job, that runs the procedures.
!!!!! Change the database context to the corrent DBA database */

USE [msdb]
GO

/****** Object:  Job [$DBA_Hourly_DefaultTraceHistory]    Script Date: 23. 01. 2024 13:37:21 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [DBA]    Script Date: 23. 01. 2024 13:37:21 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'DBA' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'DBA'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'$DBA_Hourly_DefaultTraceHistory', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'DBA', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [FillDelta]    Script Date: 23. 01. 2024 13:37:21 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'FillDelta', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.DBA_FillDefaultTraceHistory', 
		@database_name=N'$DbAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Cleanup]    Script Date: 23. 01. 2024 13:37:21 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Cleanup', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC  [dbo].[DBA_CleanDefaultTraceHistory]', 
		@database_name=N'$DbAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Recurring_EveryHour', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20240120, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'35402100-440a-47d9-8eb6-446d0c46872d'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO