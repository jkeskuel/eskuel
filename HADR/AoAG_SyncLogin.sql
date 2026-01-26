SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[USP_AG_SyncLogins]
AS
SET NOCOUNT ON

CREATE TABLE #LoginTable(Loginname nvarchar(256),CScript nvarchar(max),AScript nvarchar(max))

IF (NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND  TABLE_NAME = 'AG_SyncLogins_Err')) 
		BEGIN 
			CREATE TABLE [AG_SyncLogins_Err] (ErrorNumber INT, ErrorMessage VARCHAR(MAX))
		END
IF((SELECT role FROM sys.dm_hadr_availability_replica_states WHERE is_local = 1)= 1)
	BEGIN  --- vP
	 
		IF (NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND  TABLE_NAME = 'AG_SyncLogins')) 
		BEGIN  
			CREATE TABLE [AG_SyncLogins] (Loginname nvarchar(256),CScript nvarchar(4000),AScript nvarchar(4000)) 
		END 
		ELSE 
		BEGIN 
			TRUNCATE TABLE master.[dbo].[AG_SyncLogins] 
		END

		INSERT INTO [AG_SyncLogins]
		SELECT  p.name, 
		CASE WHEN p.type IN ('G','U') THEN 
			'CREATE LOGIN ' + QUOTENAME( p.name ) + ' FROM WINDOWS WITH DEFAULT_DATABASE = [master]'
			+(CASE l.denylogin WHEN 1 THEN '; DENY CONNECT SQL TO [' +p.name+']' WHEN 0 THEN ' ' ELSE NULL END ) 
			+(CASE l.hasaccess WHEN 1 THEN ' '  WHEN 0 THEN '; REVOKE CONNECT SQL TO ['+p.name+']'  ELSE NULL END)
			+(CASE p.is_disabled WHEN 1 THEN '; ALTER LOGIN [' + QUOTENAME( p.name ) + '] DISABLE'  WHEN 0 THEN ' '  ELSE NULL END)
		ELSE 
			'CREATE LOGIN ' + QUOTENAME( p.name ) + ' WITH PASSWORD = ' + dbo.fn_hexadecimal(CAST( LOGINPROPERTY( p.name, 'PasswordHash' ) AS varbinary (256) )) + ' HASHED, SID = ' + dbo.fn_hexadecimal(p.sid) + ', DEFAULT_DATABASE = [master]' 
			+(Select CASE is_policy_checked WHEN 1 THEN ',CHECK_POLICY = OFF' WHEN 0 THEN ',CHECK_POLICY = OFF' ELSE NULL END FROM sys.sql_logins WHERE name = p.name) 
			+(Select CASE is_expiration_checked WHEN 1 THEN ', CHECK_EXPIRATION = OFF' WHEN 0 THEN ', CHECK_EXPIRATION = OFF' ELSE NULL END FROM sys.sql_logins WHERE name = p.name) 
			+(CASE l.denylogin WHEN 1 THEN '; DENY CONNECT SQL TO ' +QUOTENAME( p.name ) WHEN 0 THEN ' ' ELSE NULL END ) 
			+(CASE l.hasaccess WHEN 1 THEN ' '  WHEN 0 THEN '; REVOKE CONNECT SQL TO '+QUOTENAME( p.name ) ELSE NULL END)
			+(CASE p.is_disabled WHEN 1 THEN '; ALTER LOGIN ' + QUOTENAME( p.name ) + ' DISABLE'  WHEN 0 THEN ' '  ELSE NULL END)
				  END CScript,
		--=======================
		CASE WHEN p.type IN ('G','U') THEN 
			'ALTER LOGIN ' + QUOTENAME( p.name ) + '  WITH DEFAULT_DATABASE = [master]'
			+(CASE l.denylogin WHEN 1 THEN '; DENY CONNECT SQL TO '+QUOTENAME( p.name ) WHEN 0 THEN ' ' ELSE NULL END ) 
			+(CASE l.hasaccess WHEN 1 THEN ' '  WHEN 0 THEN '; REVOKE CONNECT SQL TO '+QUOTENAME( p.name )  ELSE NULL END)
			+(CASE p.is_disabled WHEN 1 THEN '; ALTER LOGIN ' + QUOTENAME( p.name ) + ' DISABLE'  WHEN 0 THEN ' '  ELSE NULL END)
		ELSE 
			'ALTER LOGIN ' + QUOTENAME( p.name ) + ' WITH PASSWORD = ' + dbo.fn_hexadecimal(CAST( LOGINPROPERTY( p.name, 'PasswordHash' ) AS varbinary (256) )) + ' HASHED , DEFAULT_DATABASE = [master]' 
			+(Select CASE is_policy_checked WHEN 1 THEN ',CHECK_POLICY = OFF' WHEN 0 THEN ',CHECK_POLICY = OFF' ELSE NULL END FROM sys.sql_logins WHERE name = p.name) 
			+(Select CASE is_expiration_checked WHEN 1 THEN ', CHECK_EXPIRATION = OFF' WHEN 0 THEN ', CHECK_EXPIRATION = OFF' ELSE NULL END FROM sys.sql_logins WHERE name = p.name) 
			+(CASE l.denylogin WHEN 1 THEN '; DENY CONNECT SQL TO '+QUOTENAME( p.name )  WHEN 0 THEN ' ' ELSE NULL END ) 
			+(CASE l.hasaccess WHEN 1 THEN ' '  WHEN 0 THEN '; REVOKE CONNECT SQL TO '+QUOTENAME( p.name )  ELSE NULL END)
			+(CASE p.is_disabled WHEN 1 THEN '; ALTER LOGIN ' + QUOTENAME( p.name ) + ' DISABLE'  WHEN 0 THEN ' '  ELSE NULL END)
				  END AScript 
		FROM 
		sys.server_principals p LEFT JOIN sys.syslogins l
		ON ( l.name = p.name ) WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name <> 'sa' AND p.name NOT LIKE '%#%'
		 
	END
ELSE 
	BEGIN	
		DECLARE @AGLreplica nvarchar(256)
		DECLARE @SQL nvarchar(max)
			SELECT  @AGLreplica = hags.primary_replica 
			FROM 
			sys.dm_hadr_availability_group_states hags
			INNER JOIN sys.availability_groups ag ON ag.group_id = hags.group_id

		IF(@AGLreplica <> @@SERVERNAME)
			BEGIN
					SET @SQL = N'INSERT INTO #LoginTable
								SELECT * FROM ['+ @AGLreplica + '].master.dbo.[AG_SyncLogins]
								WHERE Loginname not like ''NT SERVICE%'''
					EXEC sp_executesql @SQL
			END
			
		SELECT * FROM #LoginTable
	END
 
DECLARE @scriptC nvarchar(max)
DECLARE @scriptA nvarchar(max)
DECLARE @login nvarchar(256)
DECLARE @counter int
DECLARE @totalCount int
SELECT @totalCount=COUNT(1) FROM #LoginTable
SET @counter = 1
WHILE(@totalCount>=@counter)
		BEGIN
			SELECT TOP 1 @scriptC=CScript,@scriptA=AScript, @login=Loginname  FROM #LoginTable

			IF NOT EXISTS(SELECT * FROM sys.syslogins WHERE name = @login)
				BEGIN TRY
					EXEC(@scriptC)
				END TRY
				BEGIN CATCH
					INSERT INTO master.dbo.[AG_SyncLogins_Err]
					SELECT ERROR_NUMBER() AS ErrorNumber,
						ERROR_MESSAGE() AS ErrorMessage;
				END CATCH
			ELSE
			BEGIN TRY
				EXEC(@scriptA)
			END TRY
				BEGIN CATCH
					INSERT INTO master.dbo.[AG_SyncLogins_Err]
					SELECT ERROR_NUMBER() AS ErrorNumber,
						ERROR_MESSAGE() AS ErrorMessage;
			END CATCH

	DELETE #LoginTable WHERE Loginname = @login
	SET @counter +=1
END 

GO


USE [master]
GO
IF OBJECT_ID('dbo.fn_hexadecimal') IS NOT NULL
    DROP FUNCTION dbo.fn_hexadecimal
GO
CREATE FUNCTION dbo.fn_hexadecimal
(
    @binvalue [varbinary](256)
)
RETURNS [nvarchar] (514)
AS
BEGIN
	DECLARE @hexvalue [nvarchar] (514)
    DECLARE @i [smallint]
    DECLARE @length [smallint]
    DECLARE @hexstring [nchar](16)

    SELECT @hexvalue = N'0x'
    SELECT @i = 1
    SELECT @length = DATALENGTH(@binvalue)
    SELECT @hexstring = N'0123456789ABCDEF'
    WHILE (@i < =  @length)
    BEGIN
        DECLARE @tempint   [smallint]
        DECLARE @firstint  [smallint]
        DECLARE @secondint [smallint]
        SELECT @tempint = CONVERT([smallint], SUBSTRING(@binvalue, @i, 1))
        SELECT @firstint = FLOOR(@tempint / 16)
        SELECT @secondint = @tempint - (@firstint * 16)
        SELECT @hexvalue = @hexvalue
            + SUBSTRING(@hexstring, @firstint  + 1, 1)
            + SUBSTRING(@hexstring, @secondint + 1, 1)
        SELECT @i = @i + 1;
	
	END
	RETURN (@hexvalue);
    
END
GO

