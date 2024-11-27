;WITH EE AS (
    SELECT
	"database_name",
	"Timestamp",
	"transaction_id",
        CAST(blocked_process AS XML) AS EX
    FROM
        [dbo].[DBA_Blocking_20241025]
)
SELECT
	"database_name",
	"Timestamp",
	"transaction_id",
    BlockedProcess.value('@waittime', 'INT') AS BlockingTime,
    BlockedProcess.value('@spid', 'INT') AS BlockedSPID,
    BlockedInputbuf.value('.', 'NVARCHAR(MAX)') AS BlockedInputbuf,
    BlockingProcess.value('@spid', 'INT') AS BlockingSPID,
    BlockingInputbuf.value('.', 'NVARCHAR(MAX)') AS BlockingInputbuf
FROM
    EE
CROSS APPLY
    EX.nodes('/blocked-process-report') AS Report(ReportNode)
CROSS APPLY
    ReportNode.nodes('blocked-process/process') AS BP(BlockedProcess)
CROSS APPLY
    ReportNode.nodes('blocking-process/process') AS BPR(BlockingProcess)
CROSS APPLY
    BP.BlockedProcess.nodes('inputbuf') AS BI(BlockedInputbuf)
CROSS APPLY
    BPR.BlockingProcess.nodes('inputbuf') AS BII(BlockingInputbuf)
ORDER BY 2 DESC;