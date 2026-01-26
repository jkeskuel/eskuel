
;with queryHash as (SELECT q.query_hash, 
		sum(rs.count_executions) cnt, 
		sum(rs.avg_cpu_time * rs.count_executions) cpu, 
		sum(rs.avg_duration * rs.count_executions) dur
	FROM sys.query_store_query q
	inner join sys.query_store_plan p
		on q.query_id = p.query_id
	inner join sys.query_store_query_text t
		on q.query_text_id = t.query_text_id
	inner join sys.query_store_runtime_stats rs
		on p.plan_id = rs.plan_id
	inner join sys.query_store_runtime_stats_interval sti
		on rs.runtime_stats_interval_id = sti.runtime_stats_interval_id
	where 1=1
	group by q.query_hash
)
SELECT qh.query_hash, qh.cpu, qh.dur, qh.cnt, COUNT(DISTINCT q.query_id) s
FROM queryHash qh
LEFT JOIN sys.query_store_query q
ON qh.query_hash = q.query_hash
GROUP BY qh.query_hash, qh.cpu, qh.dur, qh.cnt
HAVING COUNT(DISTINCT q.query_id) > 1
ORDER BY qh.cpu DESC