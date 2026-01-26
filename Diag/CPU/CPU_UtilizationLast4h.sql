DECLARE @ts_now BIGINT =
        (
            SELECT      TOP (1)
                        cpu_ticks / (cpu_ticks / ms_ticks)
            FROM        sys.dm_os_sys_info WITH (NOLOCK)
            ORDER BY    cpu_ticks DESC
        );
  
SELECT      TOP (256)
            y.SQLProcessUtilization                              AS [SQL Server Process CPU Utilization],
            REPLICATE('*', y.SQLProcessUtilization / 4)          AS [*************************],
            y.SystemIdle                                         AS [System Idle Process],
            100 - (y.SystemIdle + y.SQLProcessUtilization)       AS [Other Process CPU Utilization],
            DATEADD(ms, -1 * (@ts_now - y.timestamp), GETDATE()) AS [Event Time]
FROM
            (
                SELECT  x.record.value('(./Record/@id)[1]', 'int')                                                   AS record_id,
                        x.record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')         AS SystemIdle,
                        x.record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization,
                        x.timestamp
                FROM
                        (
                            SELECT  timestamp,
                                    CONVERT(XML, record) AS record
                            FROM    sys.dm_os_ring_buffers WITH (NOLOCK)
                            WHERE
                                    ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
                                    AND record LIKE N'%<SystemHealth>%'
                        ) AS x
            ) AS y
ORDER BY    y.record_id DESC
OPTION (RECOMPILE);