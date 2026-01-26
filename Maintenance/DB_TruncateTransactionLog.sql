/**********************************************************************
Namen: 
- Truncate - brisanje transaction logov za baze z transaction logi večjimi od N.
- N se definira prek parametra @LogSizeParameter
- SHRINK za vse log datoteke

Uporaba:
- Skripto je potrebno zagnati večkrat, dokler ni več rezultatov
- Zagon večkrat je potreben zaradi načina pisanja transaction logov in rabe VLF
**********************************************************************/

DECLARE @DBName SYSNAME;
DECLARE @RecoveryModel VARCHAR(20);
DECLARE @LogSizeMB DECIMAL(18,2);
DECLARE @LogFileName SYSNAME;
DECLARE @LogSizeParameter INT = 5120;

-- Cursor za vse ONLINE baze - z izjemo sistemskih
DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
	SELECT name, recovery_model_desc
	FROM sys.databases
	WHERE name NOT IN ('master','model','msdb','tempdb')
	  AND state_desc = 'ONLINE';

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DBName, @RecoveryModel;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Preskoči AG sekundarne replike
    IF DATABASEPROPERTYEX(@DBName, 'IsHadrEnabled') = 1  
       AND sys.fn_hadr_is_primary_replica(@DBName) = 0  
    BEGIN
        PRINT 'Skipping database "' + @DBName + '": not primary replica on this server.';
    END
    ELSE
    BEGIN
        -- Pridobi skupno velikost transaction log-a(MB)
        SELECT @LogSizeMB = SUM(size)*8.0/1024
        FROM sys.master_files
        WHERE database_id = DB_ID(@DBName) AND type_desc = 'LOG';
        
        IF @LogSizeMB IS NULL 
        BEGIN
            -- Preskoči če ne najde transaction log-a
            PRINT 'Skipping database "' + @DBName + '": unable to determine log size.';
        END
        ELSE IF @LogSizeMB < @LogSizeParameter
        BEGIN
            -- Preskoči če je log manjši od @LogSizeParameter
            PRINT 'Database "' + @DBName + '" log size ' + CONVERT(VARCHAR(20), @LogSizeMB) + ' MB – below ' + cast(@LogSizeParameter as varchar(20))+ ' MB, skipping.';
        END
        ELSE
        BEGIN
            PRINT 'Database "' + @DBName + '" log size is ' + CONVERT(VARCHAR(20), @LogSizeMB) + ' MB – initiating log truncation and shrink...';
            
            -- Truncate transaction log-a z uporabo NUL parametra.
            IF @RecoveryModel NOT IN ('SIMPLE')
            BEGIN
                PRINT '... backing up log of ' + @DBName + ' to NUL (truncating log)...';
                EXEC('BACKUP LOG [' + @DBName + '] TO DISK = ''NUL''');
            END

            -- Shrinkanje vseh transaction log-ov.
            DECLARE log_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT name FROM sys.master_files
            WHERE database_id = DB_ID(@DBName) AND type_desc = 'LOG';
            OPEN log_cursor;
            FETCH NEXT FROM log_cursor INTO @LogFileName;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                PRINT '... shrinking log file "' + @LogFileName + '" for database ' + @DBName;
                EXEC('USE [' + @DBName + ']; DBCC SHRINKFILE(N''' + @LogFileName + ''', 0, TRUNCATEONLY)');
                FETCH NEXT FROM log_cursor INTO @LogFileName;
            END
            CLOSE log_cursor;
            DEALLOCATE log_cursor;
            
            PRINT 'Completed log truncation and shrink for database "' + @DBName + '".';
        END
    END

    FETCH NEXT FROM db_cursor INTO @DBName, @RecoveryModel;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;