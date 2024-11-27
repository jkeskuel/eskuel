SELECT 
    CONVERT (varchar(30), GETDATE(), 121) as [RunTime],
    DATEADD (ms, rbf.[timestamp] - tme.ms_ticks, GETDATE()) as [Notification_Time],
    CAST(record as xml).value('(//SPID)[1]', 'bigint') as SPID,
    CAST(record as xml).value('(//ErrorCode)[1]', 'varchar(255)') as Error_Code,
    CAST(record as xml).value('(//CallingAPIName)[1]', 'varchar(255)') as [CallingAPIName],
    CAST(record as xml).value('(//APIName)[1]', 'varchar(255)') as [APIName],
    CAST(record as xml).value('(//Record/@id)[1]', 'bigint') AS [Record Id],
    CAST(record as xml).value('(//Record/@type)[1]', 'varchar(30)') AS [Type],
    CAST(record as xml).value('(//Record/@time)[1]', 'bigint') AS [Record Time],
    tme.ms_ticks as [Current Time]
from sys.dm_os_ring_buffers rbf
cross join sys.dm_os_sys_info tme
where rbf.ring_buffer_type = 'RING_BUFFER_SECURITY_ERROR' 
--and cast(record as xml).value('(//SPID)[1]', 'int') = XspidNo
ORDER BY rbf.timestamp ASC


 SELECT CONVERT (varchar(30), GETDATE(), 121) as [RunTime],
    dateadd (ms, (rbf.[timestamp] - tme.ms_ticks), GETDATE()) as Time_Stamp,
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/RecordType)[1]', 'varchar(50)') AS [Action], 
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/RecordSource)[1]', 'varchar(50)') AS [Source], 
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/Spid)[1]', 'int') AS [SPID],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/RemoteHost)[1]', 'varchar(100)') AS [RemoteHost],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/RemotePort)[1]', 'varchar(25)') AS [RemotePort],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/LocalPort)[1]', 'varchar(25)') AS [LocalPort],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsBuffersInformation/TdsInputBufferError)[1]', 'varchar(25)') AS [TdsInputBufferError],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsBuffersInformation/TdsOutputBufferError)[1]', 'varchar(25)') AS [TdsOutputBufferError],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsBuffersInformation/TdsInputBufferBytes)[1]', 'varchar(25)') AS [TdsInputBufferBytes],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/PhysicalConnectionIsKilled)[1]', 'int') AS [isPhysConnKilled], 
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/DisconnectDueToReadError)[1]', 'int') AS [DisconnectDueToReadError],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/NetworkErrorFoundInInputStream)[1]', 'int') AS [NetworkErrorFound],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/ErrorFoundBeforeLogin)[1]', 'int') AS [ErrorBeforeLogin],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/SessionIsKilled)[1]', 'int') AS [isSessionKilled],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/NormalDisconnect)[1]', 'int') AS [NormalDisconnect],
    cast(record as xml).value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/NormalLogout)[1]', 'int') AS [NormalLogout],
    cast(record as xml).value('(//Record/@id)[1]', 'bigint') AS [Record Id], 
    cast(record as xml).value('(//Record/@type)[1]', 'varchar(30)') AS [Type], 
    cast(record as xml).value('(//Record/@time)[1]', 'bigint') AS [Record Time],
    tme.ms_ticks as [Current Time]
FROM sys.dm_os_ring_buffers rbf
cross join sys.dm_os_sys_info tme
where rbf.ring_buffer_type = 'RING_BUFFER_CONNECTIVITY' and cast(record as xml).value('(//Record/ConnectivityTraceRecord/Spid)[1]', 'int') <> 0
--and cast(record as xml).value('(//Record/ConnectivityTraceRecord/Spid)[1]', 'int') = 2988
ORDER BY rbf.timestamp ASC


SELECT CONVERT (varchar(30), GETDATE(), 121) as [RunTime],
    dateadd (ms, (rbf.[timestamp] - tme.ms_ticks), GETDATE()) as Time_Stamp,
    cast(record as xml).value('(//Exception//Error)[1]', 'varchar(255)') as [Error],
    cast(record as xml).value('(//Exception/Severity)[1]', 'varchar(255)') as [Severity],
    cast(record as xml).value('(//Exception/State)[1]', 'varchar(255)') as [State],
    msg.description,
    cast(record as xml).value('(//Exception/UserDefined)[1]', 'int') AS [isUserDefinedError],
    cast(record as xml).value('(//Record/@id)[1]', 'bigint') AS [Record Id],
    cast(record as xml).value('(//Record/@type)[1]', 'varchar(30)') AS [Type], 
    cast(record as xml).value('(//Record/@time)[1]', 'bigint') AS [Record Time],
    tme.ms_ticks as [Current Time]
from sys.dm_os_ring_buffers rbf
cross join sys.dm_os_sys_info tme
cross join sys.sysmessages msg
where rbf.ring_buffer_type = 'RING_BUFFER_EXCEPTION' --and cast(record as xml).value('(//SPID)[1]', 'int') <> 0--in (122,90,161,179)
and msg.error = cast(record as xml).value('(//Exception//Error)[1]', 'varchar(500)') and msg.msglangid = 1033 --and [Error] = 4002
ORDER BY rbf.timestamp ASC



SELECT CONVERT (varchar(30), GETDATE(), 121) as [RunTime],
    dateadd (ms, (rbf.[timestamp] - tme.ms_ticks), GETDATE()) as [Notification_Time], 
    cast(record as xml).value('(//Record/ResourceMonitor/Notification)[1]', 'varchar(30)') AS [Notification_type], 
    cast(record as xml).value('(//Record/MemoryRecord/MemoryUtilization)[1]', 'bigint') AS [MemoryUtilization %], 
    cast(record as xml).value('(//Record/MemoryNode/@id)[1]', 'bigint') AS [Node Id], 
    cast(record as xml).value('(//Record/ResourceMonitor/IndicatorsProcess)[1]', 'int') AS [Process_Indicator],
    cast(record as xml).value('(//Record/ResourceMonitor/IndicatorsSystem)[1]', 'int') AS [System_Indicator],
    cast(record as xml).value('(//Record/MemoryNode/ReservedMemory)[1]', 'bigint') AS [SQL_ReservedMemory_KB], 
    cast(record as xml).value('(//Record/MemoryNode/CommittedMemory)[1]', 'bigint') AS [SQL_CommittedMemory_KB], 
    cast(record as xml).value('(//Record/MemoryNode/AWEMemory)[1]', 'bigint') AS [SQL_AWEMemory], 
    cast(record as xml).value('(//Record/MemoryNode/SinglePagesMemory)[1]', 'bigint') AS [SinglePagesMemory], 
    cast(record as xml).value('(//Record/MemoryNode/MultiplePagesMemory)[1]', 'bigint') AS [MultiplePagesMemory], 
    cast(record as xml).value('(//Record/MemoryRecord/TotalPhysicalMemory)[1]', 'bigint') AS [TotalPhysicalMemory_KB], 
    cast(record as xml).value('(//Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'bigint') AS [AvailablePhysicalMemory_KB], 
    cast(record as xml).value('(//Record/MemoryRecord/TotalPageFile)[1]', 'bigint') AS [TotalPageFile_KB], 
    cast(record as xml).value('(//Record/MemoryRecord/AvailablePageFile)[1]', 'bigint') AS [AvailablePageFile_KB], 
    cast(record as xml).value('(//Record/MemoryRecord/TotalVirtualAddressSpace)[1]', 'bigint') AS [TotalVirtualAddressSpace_KB], 
    cast(record as xml).value('(//Record/MemoryRecord/AvailableVirtualAddressSpace)[1]', 'bigint') AS [AvailableVirtualAddressSpace_KB], 
    cast(record as xml).value('(//Record/@id)[1]', 'bigint') AS [Record Id], 
    cast(record as xml).value('(//Record/@type)[1]', 'varchar(30)') AS [Type],
    cast(record as xml).value('(//Record/@time)[1]', 'bigint') AS [Record Time],
    tme.ms_ticks as [Current Time]
FROM sys.dm_os_ring_buffers rbf
cross join sys.dm_os_sys_info tme
where rbf.ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR' --and cast(record as xml).value('(//Record/ResourceMonitor/Notification)[1]', 'varchar(30)') = 'RESOURCE_MEMPHYSICAL_LOW'
ORDER BY rbf.timestamp ASC



