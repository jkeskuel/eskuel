;WITH primary_data AS (SELECT grp.name , dbs.database_name, rep.replica_server_name, 
st.is_primary_replica, st.synchronization_state_desc, st.synchronization_health_desc,
st.database_state_desc
FROM SYS.dm_hadr_database_replica_states st
LEFT JOIN sys.availability_groups grp
                on st.group_id = grp.group_id
LEFT JOIN sys.availability_databases_cluster dbs
                on st.group_database_id = dbs.group_database_id
LEFT JOIN sys.availability_replicas rep
                ON st.group_id=rep.group_id and st.replica_id= rep.replica_id
                WHERE st.is_primary_replica = 1),
secondary_data AS (SELECT grp.name , dbs.database_name, rep.replica_server_name, 
st.is_primary_replica, st.synchronization_state_desc, st.synchronization_health_desc,
st.database_state_desc
FROM SYS.dm_hadr_database_replica_states st
LEFT JOIN sys.availability_groups grp
                on st.group_id = grp.group_id
LEFT JOIN sys.availability_databases_cluster dbs
                on st.group_database_id = dbs.group_database_id
LEFT JOIN sys.availability_replicas rep
                ON st.group_id=rep.group_id and st.replica_id= rep.replica_id
WHERE st.is_primary_replica = 0)
SELECT pd.name, pd.database_name,
pd.replica_server_name as primary_server,
pd.synchronization_health_desc as primary_synchronization_health,
pd.synchronization_state_desc as primary_synchronization_state,
sd.replica_server_name as secondary_server,
sd.synchronization_health_desc as secondary_synchronization_health,
sd.synchronization_state_desc as secondary_synchronization_state
FROM primary_data pd
INNER JOIN secondary_data sd
                on pd.name = sd.name and pd.database_name = sd.database_name
