USE MASTER
GO

SET NOCOUNT ON;

/* SQL Server Configuration Report  
2018-01-18     V2 초기완성 버전
--------------------------- Version Control -------------------------------*/
DECLARE @ScriptVersion VARCHAR(4)
SET @ScriptVersion = '2.0' -- Version number of this script
/*-------------------------------------------------------------------------*/

DECLARE 
      @CurrentDate NVARCHAR(50) 	-- Current data/time
    , @SQLServerName NVARCHAR(50) 	--Set SQL Server Name
    , @NodeName1 NVARCHAR(50) 		-- Name of node 1 if clustered
    , @NodeName2 NVARCHAR(50) 		-- Name of node 2 if clustered
    --, @NodeName3 NVARCHAR(50) /* 	-- remove remarks if more than 2 node cluster */
    --, @NodeName4 NVARCHAR(50) /*-- remove remarks if more than 2 node cluster */
    , @AccountName NVARCHAR(50) 	-- Account name used
    , @StaticPortNumber NVARCHAR(50) -- Static port number
    , @INSTANCENAME NVARCHAR(30) 	-- SQL Server Instance Name
    , @VALUENAME NVARCHAR(20) 		-- Detect account used in SQL 2005, see notes below
    , @KERB NVARCHAR(50) 			-- Is Kerberos used or not
    , @DomainName NVARCHAR(50) 		-- Name of Domain
	, @IP NVARCHAR(20) 				-- IP address used by SQL Server
    --, @InstallDate NVARCHAR(20) -- Installation date of SQL Server
    , @InstallDate datetime 		-- Installation date of SQL Server
    , @ProductVersion NVARCHAR(30) 	-- Production version
    , @MachineName NVARCHAR(30) 	-- Server name
    , @ServerName NVARCHAR(30) 		-- SQL Server name
    , @Instance NVARCHAR(30) 		--  Instance name
    , @EDITION NVARCHAR(30) 		--SQL Server Edition
    , @ProductLevel NVARCHAR(20) 	-- Product level
    , @ISClustered NVARCHAR(20) 	-- System clustered
    , @ISIntegratedSecurityOnly NVARCHAR(50) -- Security level
    , @ISSingleUser NVARCHAR(20) 	-- System in Single User mode
    , @COLLATION NVARCHAR(30)  		-- Collation type
    , @physical_CPU_Count VARCHAR(4) -- CPU count
    , @EnvironmentType VARCHAR(15) 	-- Physical or Virtual
    , @MaxMemory NVARCHAR(10) 		-- Max memory
    , @MinMemory NVARCHAR(10) 		-- Min memory
    , @TotalMEMORYinBytes NVARCHAR(10) -- Total memory
    , @ErrorLogLocation VARCHAR(500) 	-- location of error logs
    , @TraceFileLocation VARCHAR(100) 	-- location of trace files
    , @LinkServers VARCHAR(2) 			-- Number of linked servers found

SET @CurrentDate = CONVERT(varchar(100), GETDATE(), 120)
SET @ServerName = (SELECT @@SERVERNAME)
-- PRINT '--##  SQL Server Configuration Report - Version '+@ScriptVersion

---------------------------------------------------------------------
--=================== 01. MS-SQL Server Information =================
PRINT '--##  SQL Server Report Date - Version 2.0'

SELECT @ServerName "Server Name", @CurrentDate "Report Date"
--PRINT 'Report executed on '+@ServerName+' SQL Server at '+@CurrentDate

--> SQL Server Settings <--
--PRINT '--##Loading sp_configure details'

-- EXEC sp_configure 'show advanced options', 1;
-- RECONFIGURE;

SELECT 
         [name]
        ,[description]
        ,[value] 
        ,[minimum] 
        ,[maximum] 
        ,[value_in_use]
INTO #SQL_Server_Settings
FROM master.sys.configurations;        

-- EXEC sp_configure 'show advanced options', 0;
-- RECONFIGURE;

--PRINT '--##sp_configure details loaded'

-- Detecting setting
----------------------------------------------------------------
PRINT '--##  SQL Server Summary'

SET @SQLServerName = (SELECT @@ServerName) -- SQL Server name
SET @InstallDate = (SELECT  createdate FROM sys.syslogins where sid = 0x010100000000000512000000)
SET @MachineName = (SELECT CONVERT(char(100), SERVERPROPERTY('MachineName'))) 
SET @InstanceName = CASE WHEN  (SELECT CONVERT(varchar(50), SERVERPROPERTY('InstanceName'))) IS NULL THEN 'Default Instance'
                        ELSE @InstanceName
                    END
SET @EDITION = (SELECT CONVERT(char(30), SERVERPROPERTY('EDITION')))
SET @ProductLevel = (SELECT CONVERT(char(30), SERVERPROPERTY('ProductLevel')))
SET @physical_CPU_Count = (SELECT cpu_count FROM sys.dm_os_sys_info)
------------------------------------------------------------------------
SET @ProductVersion = CONVERT(varchar(30), SERVERPROPERTY('ProductVersion'))
IF @ProductVersion LIKE '6.5%'   SET @ProductVersion = 'SQL Server 6.5'
IF @ProductVersion LIKE '7.0%'   SET @ProductVersion = 'SQL Server 7'
IF @ProductVersion LIKE '8.0%'   SET @ProductVersion = 'SQL Server 2000'
IF @ProductVersion LIKE '9.0%'   SET @ProductVersion = 'SQL Server 2005'  
IF @ProductVersion LIKE '10.0%'  SET @ProductVersion = 'SQL Server 2008' 
IF @ProductVersion LIKE '10.50%' SET @ProductVersion = 'SQL Server 2008R2' 
IF @ProductVersion LIKE '11.0%'  SET @ProductVersion = 'SQL Server 2012' 
IF @ProductVersion LIKE '12.0%'  SET @ProductVersion = 'SQL Server 2014' 
IF @ProductVersion LIKE '14.0%'  SET @ProductVersion = 'SQL Server 2016'  -- for future use
IF @ProductVersion LIKE '15.0%'  SET @ProductVersion = 'SQL Server 2017'  -- for future use
------------------------------------------------------------------------
/* This section only works on SQL 2012 and higher */

--IF(SELECT virtual_machine_type FROM sys.dm_os_sys_info) = 1
--SET @EnvironmentType = 'Virtual'
--ELSE
--SET @EnvironmentType = 'Physical'
--PRINT '    Detection of Environment Type --> '+@EnvironmentType
------------------------------------------------------------------------

SET @MaxMemory = (select CONVERT(char(10), [value_in_use]) from  #SQL_Server_Settings where name = 'max server memory (MB)')
SET @MinMemory = (select CONVERT(char(10), [value_in_use]) from  #SQL_Server_Settings where name = 'min server memory (MB)')
------------------------------------------------------------------------
--SELECT DEC.local_net_address INTO #IP FROM sys.dm_exec_connections AS DEC WHERE DEC.session_id = @@SPID;
--SET @IP = (SELECT DEC.Local_Net_Address FROM sys.dm_exec_connections AS DEC WHERE DEC.session_id = @@SPID)
SELECT TOP 1 @IP = Local_Net_Address
FROM sys.dm_exec_connections AS DEC
WHERE net_transport = 'TCP'
GROUP BY Local_Net_Address
ORDER BY COUNT(*)
------------------------------------------------------------------------
SET @StaticPortNumber = (SELECT local_tcp_port FROM sys.dm_exec_connections WHERE session_id = @@SPID)
------------------------------------------------------------------------
SET @DomainName = DEFAULT_DOMAIN()
------------------------------------------------------------------------
--For Service Account Name - This line will work on SQL 2008R2 and higher only
--SET @AccountName = (SELECT top 1 service_account FROM sys.dm_server_services)
--So the lines below are being used until SQL 2005 is removed/upgraded
EXECUTE  master.dbo.xp_instance_regread
        @rootkey      = N'HKEY_LOCAL_MACHINE',
        @key          = N'SYSTEM\CurrentControlSet\Services\MSSQLServer',
        @value_name   = N'ObjectName',
        @value        = @AccountName OUTPUT
--PRINT '    Detection of Service Account name --> '+@AccountName
------------------------------------------------------------------------
IF (SELECT CONVERT(char(30), SERVERPROPERTY('ISClustered'))) = 1
    SET @ISClustered = 'Clustered'
ELSE
    SET @ISClustered = 'Not Clustered'

------------------------------------------------------------------------
--cluster node names. Modify if there are more than 2 nodes in cluster
SELECT NodeName INTO #nodes FROM sys.dm_os_cluster_nodes 
IF @@rowcount = 0 
BEGIN 
    SET @NodeName1 = 'NONE' -- NONE for no cluster
END
ELSE
BEGIN
    SET @NodeName1 = (SELECT top 1 NodeName from #nodes order by NodeName)
    SET @NodeName2 = (SELECT NodeName from #nodes where NodeName <> @NodeName1)
    -- Add code here if more that 2 node cluster
END

------------------------------------------------------------------------
-- SELECT net_transport, auth_scheme INTO #KERBINFO FROM sys.dm_exec_connections WHERE session_id = @@spid
-- IF @@rowcount = 0 
--     SET @KERB = 'Kerberos not used in TCP network transport'
-- ELSE
--     SET @KERB = 'TCP is using Kerberos'

IF (SELECT count(*) FROM sys.dm_exec_connections WHERE session_id = @@spid) > 0
    SET @KERB = 'Kerberos not used in TCP network transport'
ELSE
    SET @KERB = 'TCP is using Kerberos'

------------------------------------------------------------------------
IF (SELECT CONVERT(int, SERVERPROPERTY('ISIntegratedSecurityOnly'))) = 1
    SET @ISIntegratedSecurityOnly = 'Windows Authentication Security Mode'
ELSE
    SET @ISIntegratedSecurityOnly = 'SQL Server Authentication Security Mode'
------------------------------------------------------------------------
DECLARE @AuditLevel int,
                @AuditLvltxt VARCHAR(50)
EXEC MASTER.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', 
                    N'Software\Microsoft\MSSQLServer\MSSQLServer', N'AuditLevel', @AuditLevel OUTPUT

SELECT @AuditLvltxt =
	CASE 
        WHEN @AuditLevel = 0    THEN 'None'
        WHEN @AuditLevel = 1    THEN 'Successful logins only'
        WHEN @AuditLevel = 2    THEN 'Failed logins only'
        WHEN @AuditLevel = 3    THEN 'Both successful and failed logins'
    	ELSE 'Unknown'
    END
------------------------------------------------------------------------
IF (SELECT CONVERT(int, SERVERPROPERTY('ISSingleUser'))) = 1
    SET @ISSingleUser = 'Single User'
ELSE
    SET @ISSingleUser = 'Multi User'
------------------------------------------------------------------------
SET @COLLATION = (SELECT CONVERT(varchar(30), SERVERPROPERTY('COLLATION')))
------------------------------------------------------------------------
SET @ErrorLogLocation = (SELECT REPLACE(CAST(SERVERPROPERTY('ErrorLogFileName') AS VARCHAR(500)), 'ERRORLOG',''))
------------------------------------------------------------------------
SET @TraceFileLocation = (SELECT REPLACE(CONVERT(VARCHAR(100),SERVERPROPERTY('ErrorLogFileName')), '\ERRORLOG','\log.trc'))
------------------------------------------------------------------------
SET @LinkServers = (SELECT COUNT(*) FROM sys.servers WHERE is_linked ='1')
------------------------------------------------------------------------
SELECT 'SQLServerName\InstanceName' as KeyName, @SQLServerName KeyVal
UNION SELECT 'Install Date' , CONVERT(varchar(200), @InstallDate, 120)
UNION SELECT 'Machine Name' , @MachineName
UNION SELECT 'Instance Name' , @InstanceName
UNION SELECT 'SQL Server Edition and BIT Level', @EDITION
UNION SELECT 'SQL Server Bit Level', CASE WHEN CHARINDEX('64-bit', @@VERSION) > 0 THEN '64bit' else '32bit' end
UNION SELECT 'SQL Server Service Pack', @ProductLevel
UNION SELECT 'Production Name', @ProductVersion
UNION SELECT 'Logical CPU Count', @physical_CPU_Count
UNION SELECT 'Max Server Memory(Megabytes)', @MaxMemory
UNION SELECT 'Min Server Memory(Megabytes)', @MinMemory
UNION SELECT 'Server IP Address', @IP
UNION SELECT 'Port Number', @StaticPortNumber
UNION SELECT 'Domain Name', @DomainName
UNION SELECT 'Service Account name', @AccountName
UNION SELECT 'Clustered Status', @ISClustered
UNION SELECT 'Node1 Name', @NodeName1
UNION SELECT 'Node2 Name', @NodeName2
UNION SELECT 'Kerberos', @KERB
UNION SELECT 'Security Mode', @ISIntegratedSecurityOnly 
UNION SELECT 'Audit Level', @AuditLvltxt
UNION SELECT 'User Mode', @ISSingleUser
UNION SELECT 'SQL Server Collation Type', @COLLATION
--UNION SELECT 'SQL Server Engine Location', REPLACE(@ErrorLogLocation, '\Log\', '\Binn\')
UNION SELECT 'SQL Server Errorlog Location', @ErrorLogLocation
UNION SELECT 'SQL Server Default Trace Location', @TraceFileLocation
UNION SELECT 'Number of Link Servers', @LinkServers
--UNION SELECT 'OS Version', RIGHT(@@version, LEN(@@version)- 3 -charindex (' ON ', @@VERSION))
--UNION SELECT 'OS Version', RTRIM(@@VERSION)
------------------------------------------------------------------------
PRINT '--##  Server Logins'

select * from sys.server_principals where type in ('S', 'U') order by name
------------------------------------------------------------------------
PRINT '--##  SysAdmin Members'

SELECT 'Role'               = 'sysadmin'
    , 'Login\[Member Name]' = CONVERT (NVARCHAR(50), name) COLLATE DATABASE_DEFAULT 
FROM sys.server_principals
WHERE IS_SRVROLEMEMBER('sysadmin', name) = 1
ORDER BY 'Login\[Member Name]' 

------------------------------------------------------------------------
PRINT '--##  ServerAdmin Members'

IF (SELECT COUNT(*) FROM sys.server_principals WHERE (type ='R') and (name='serveradmin')) = 0
BEGIN 
    PRINT '    ** No ServerAdmin Users Detection of ** '
END
ELSE
BEGIN
    SELECT CONVERT (NVARCHAR(20),r.name) AS'Role'
            , CONVERT (NVARCHAR(50),p.name)  AS 'Login\Member Name'
    FROM    sys.server_principals r
        JOIN sys.server_role_members m  ON    r.principal_id = m.role_principal_id
        JOIN sys.server_principals p ON    p.principal_id = m.member_principal_id
    WHERE    (r.type ='R') and (r.name='serveradmin')
END

------------------------------------------------------------------------
PRINT '--##  MS-SQL Server Configuration setting' 

SELECT [name]                               AS 'Configuration Setting'
    , (CONVERT (CHAR(20),[value_in_use] ))  AS 'Value in Use'
FROM #SQL_Server_Settings
GO

------------------------------------------------------------------------
PRINT '--##  Detection of code that automatically executes on startup'

SELECT CONVERT (NVARCHAR(35), name) AS 'Name'
                , CONVERT (NVARCHAR(25), type_desc) AS 'Type'
                ,  create_date AS 'Created Date'
                ,  modify_date AS 'Modified Date'
FROM sys.procedures
WHERE is_auto_executed = 1
GO
-- IF (SELECT COUNT(*) FROM sys.procedures WHERE is_auto_executed = 1) = 0
-- BEGIN 
--     PRINT '** No code that automatically execute on startup Detection of ** '
-- END
-- ELSE
-- BEGIN
--     SELECT CONVERT (NVARCHAR(35), name) AS 'Name'
--                 , CONVERT (NVARCHAR(25), type_desc) AS 'Type'
--                 ,  create_date AS 'Created Date'
--                 ,  modify_date AS 'Modified Date'
--     FROM sys.procedures
--     WHERE is_auto_executed = 1
-- END

------------------------------------------------------------------------
PRINT '--##  SQL Service Status' 

CREATE TABLE #RegResult
(ResultValue NVARCHAR(4))

CREATE TABLE #ServicesServiceStatus            
( 
     RowID INT IDENTITY(1,1)
    ,ServerName NVARCHAR(30) 
    ,ServiceName NVARCHAR(45)
    ,ServiceStatus varchar(15)
    ,StatusDateTime DATETIME DEFAULT (GETDATE())
    ,PhysicalSrverName NVARCHAR(50)
)

DECLARE 
         @ChkInstanceName nvarchar(128)                
        ,@ChkSrvName nvarchar(128)                    
        ,@TrueSrvName nvarchar(128)                    
        ,@SQLSrv NVARCHAR(128)                        
        ,@PhysicalSrvName NVARCHAR(128)            
        ,@FTS nvarchar(128)                        
        ,@RS nvarchar(128)                            
        ,@SQLAgent NVARCHAR(128)                
        ,@OLAP nvarchar(128)                    
        ,@REGKEY NVARCHAR(128)                    

SET @PhysicalSrvName = CAST(SERVERPROPERTY('MachineName') AS VARCHAR(128)) 
SET @ChkSrvName = CAST(SERVERPROPERTY('INSTANCENAME') AS VARCHAR(128)) 
SET @ChkInstanceName = @@serverName

IF @ChkSrvName IS NULL                            
    BEGIN 
        SET @TrueSrvName = 'MSQLSERVER'
        SELECT @OLAP = 'MSSQLServerOLAPService'     
        SELECT @FTS = 'MSFTESQL' 
        SELECT @RS = 'ReportServer' 
        SELECT @SQLAgent = 'SQLSERVERAGENT'
        SELECT @SQLSrv = 'MSSQLSERVER'
    END 
ELSE
    BEGIN
        SET @TrueSrvName =  CAST(SERVERPROPERTY('INSTANCENAME') AS VARCHAR(128)) 
        SET @SQLSrv = '$'+@ChkSrvName
         SELECT @OLAP = 'MSOLAP' + @SQLSrv    /*Setting up proper service name*/
        SELECT @FTS = 'MSFTESQL' + @SQLSrv 
        SELECT @RS = 'ReportServer' + @SQLSrv
        SELECT @SQLAgent = 'SQLAgent' + @SQLSrv
        SELECT @SQLSrv = 'MSSQL' + @SQLSrv
    END 
;
/* ---------------------------------- SQL Server Service Section ----------------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\'+@SQLSrv

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1 
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus)        
    EXEC xp_servicecontrol N'QUERYSTATE',@SQLSrv
    UPDATE #ServicesServiceStatus set ServiceName = 'MS SQL Server Service' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END
ELSE 
BEGIN
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
    UPDATE #ServicesServiceStatus set ServiceName = 'MS SQL Server Service' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END

/* ---------------------------------- SQL Server Agent Service Section -----------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\' + @SQLAgent

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1 
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus)        
    EXEC xp_servicecontrol N'QUERYSTATE',@SQLAgent
    UPDATE #ServicesServiceStatus set ServiceName = 'SQL Server Agent Service' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END
ELSE 
BEGIN
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
    UPDATE #ServicesServiceStatus set ServiceName = 'SQL Server Agent Service' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity    
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END

/* ---------------------------------- SQL Browser Service Section ----------------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\SQLBrowser'

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1 
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus)        
    EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',N'sqlbrowser'
    UPDATE #ServicesServiceStatus set ServiceName = 'SQL Browser Service - Instance Independent' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END
ELSE 
BEGIN
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
    UPDATE #ServicesServiceStatus set ServiceName = 'SQL Browser Service - Instance Independent' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END

/* ---------------------------------- Integration Service Section ----------------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\MsDtsServer'

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1 
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus)        
    EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',N'MsDtsServer'
    UPDATE #ServicesServiceStatus set ServiceName = 'Integration Service - Instance Independent' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END
ELSE 
BEGIN
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
    UPDATE #ServicesServiceStatus set ServiceName = 'Intergration Service - Instance Independent' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END

/* ---------------------------------- Reporting Service Section ------------------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\'+@RS

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1 
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus)        
    EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',@RS
    UPDATE #ServicesServiceStatus set ServiceName = 'Reporting Service' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END
ELSE 
BEGIN
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
    UPDATE #ServicesServiceStatus set ServiceName = 'Reporting Service' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END

/* ---------------------------------- Analysis Service Section -------------------------------------------------*/
IF @ChkSrvName IS NULL                                
    BEGIN 
    SET @OLAP = 'MSSQLServerOLAPService'
    END
ELSE    
    BEGIN
    SET @OLAP = 'MSOLAP'+'$'+@ChkSrvName
    SET @REGKEY = 'System\CurrentControlSet\Services\' + @OLAP
END

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1 
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus)        
    EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',@OLAP
    UPDATE #ServicesServiceStatus set ServiceName = 'Analysis Services' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END
ELSE 
BEGIN
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
    UPDATE #ServicesServiceStatus set ServiceName = 'Analysis Services' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END

/* ---------------------------------- Full Text Search Service Section -----------------------------------------*/
SET @REGKEY = 'System\CurrentControlSet\Services\'+@FTS

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1 
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus)        
    EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',@FTS
    UPDATE #ServicesServiceStatus set ServiceName = 'Full Text Search Service' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END
ELSE 
BEGIN
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')
    UPDATE #ServicesServiceStatus set ServiceName = 'Full Text Search Service' where RowID = @@identity
    UPDATE #ServicesServiceStatus set ServerName = @TrueSrvName where RowID = @@identity
    UPDATE #ServicesServiceStatus set PhysicalSrverName = @PhysicalSrvName where RowID = @@identity
    TRUNCATE TABLE #RegResult
END

SELECT ServerName as 'SQL Server\Instance Name'
            , ServiceName as 'Service Name'
            , ServiceStatus as 'Service Status'
            , StatusDateTime as 'Status Date\Time'
            FROM  #ServicesServiceStatus;        
------------------------------------------------------------------------
PRINT '--##  Location of Database files'

SELECT CONVERT(NVARCHAR(3), database_id) AS 'Database ID'
            , DB_NAME(database_id) AS 'Database Name'
            , CONVERT(NVARCHAR(45), name) AS 'DB Logical Name'            
            , CONVERT(NVARCHAR(100), physical_name) AS 'Physical Location'
            , CONVERT(NVARCHAR(16), type_desc) AS 'Type'
            , CONVERT(numeric(10, 2), size * 8 / 1024.0) "FileSize(MB)"
FROM sys.master_files 
GO
------------------------------------------------------------------------
PRINT '--##  permissions of the users for each database'
DECLARE @DB_USers TABLE(DBName sysname, UserName sysname, LoginType sysname, AssociatedRole varchar(max),create_date datetime,modify_date datetime)
INSERT @DB_USers EXEC sp_MSforeachdb'
    use [?]
    SELECT ''?'' AS DB_Name,
        case prin.name when ''dbo'' then prin.name + '' (''+ (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') + '')'' else prin.name end AS UserName,
        prin.type_desc AS LoginType,
        isnull(USER_NAME(mem.role_principal_id),'''') AS AssociatedRole ,create_date,modify_date
    FROM sys.database_principals prin
    LEFT OUTER JOIN sys.database_role_members mem ON prin.principal_id=mem.member_principal_id
    WHERE prin.sid IS NOT NULL and prin.sid NOT IN (0x00) and
    prin.is_fixed_role <> 1 AND prin.name NOT LIKE ''##%'''
SELECT dbname,username ,logintype ,create_date ,modify_date ,STUFF((SELECT ',' + CONVERT(VARCHAR(500),associatedrole)
    FROM @DB_USers user2
WHERE user1.DBName=user2.DBName
    AND user1.UserName = user2.UserName
        FOR XML PATH('') ),1,1,'') AS Permissions_user
        FROM @DB_USers user1
GROUP BY dbname,username ,logintype ,create_date ,modify_date
HAVING dbname not in ('tempdb')
ORDER BY DBName,username
GO

------------------------------------------------------------------------
PRINT '--##  Database Collation type'

--PRINT ' Case sensitivity Descriptions'
--PRINT ' Case Insensitive = CI                Case Sensitive = CS'
--PRINT ' Accent Insensitive = AI            Accent Sensitive = AS'
--PRINT ' Kanatype Insensitive = null        Kanatype Sensitive = KS'
--PRINT ' Width Insensitive = null            Width Sensitive = WS'

-- SELECT NAME, COLLATION_NAME
-- 	INTO #Collation
-- FROM sys.Databases ORDER BY DATABASE_ID ASC;

-- SELECT 
--       CONVERT(nvarchar(35), name) as 'Database Name'
--     , CONVERT(nvarchar(35), COLLATION_NAME) as 'Collation Type'
-- FROM #Collation
-- go
;WITH Collation_CTE (NAME, COLLATION_NAME)  
AS  
(  
	SELECT NAME, COLLATION_NAME
	FROM sys.Databases
)  
SELECT 
      CONVERT(nvarchar(35), name) as 'Database Name'
    , CONVERT(nvarchar(35), COLLATION_NAME) as 'Collation Type'
FROM Collation_CTE
GO
------------------------------------------------------------------------
PRINT '--##  Database Hard Drive Space Available'   

CREATE TABLE #HD_space
    (Drive varchar(2) NOT NULL,
    [MB free] int NOT NULL)

INSERT INTO #HD_space(Drive, [MB free])
EXEC master.sys.xp_fixeddrives;

SELECT  CONVERT(nvarchar(45), sys.databases.name) as 'Database Name'
            , CONVERT(VARCHAR,SUM(size)*8/1024) AS 'Total disk space (Megabytes)'
 FROM sys.databases 
    JOIN sys.master_files 
    ON sys.databases.database_id=sys.master_files.database_id
GROUP BY sys.databases.name
ORDER BY sys.databases.name 
GO
------------------------------------------------------------------------
PRINT '--##  OS Hard Drive Space Available'

SELECT Drive AS 'Drive Letter'
        ,[MB free]  AS 'Free Disk Space (Megabytes)'
        FROM #HD_space
IF @@rowcount = 0 
BEGIN 
    PRINT '** No Hard Drive Information ** '
END

------------------------------------------------------------------------
PRINT '--##  Database Information'

SELECT 
     D.database_id
    ,D.[name]    
    ,D.[create_date]
    ,D.[compatibility_level] 
    ,D.[user_access_desc]
    ,D.[state_desc]
    ,D.[recovery_model_desc]
        INTO #Databases_Details
FROM SYS.DATABASES D 
    INNER JOIN sys.master_files S       ON D.database_id= S.database_id
WHERE s.file_id = 1 
GO

SELECT 
     database_id AS 'Database ID'
    ,CONVERT(nvarchar(45), [name]) AS 'Name'
    ,CONVERT(nvarchar(5), [compatibility_level]) AS 'Compatibility'
    ,CONVERT(nvarchar(15), [user_access_desc]) AS 'User Access'
    ,CONVERT(nvarchar(10), [state_desc]) AS 'Status'
    ,CONVERT(nvarchar(10), [recovery_model_desc]) AS 'Recovery Model'
FROM #Databases_Details;
GO

------------------------------------------------------------------------
PRINT '--##  Database Backup Information'

SELECT     
    B.name as Database_Name
    , ISNULL(STR(ABS(DATEDIFF(day, GetDate()
    , MAX(Backup_finish_date))))
    , 'NEVER') as DaysSinceLastBackup
    , ISNULL(Convert(char(10)
    , MAX(backup_finish_date)
    , 101)
    , 'NEVER') as LastBackupDate
        INTO #Last_Backup_Dates
FROM master.dbo.sysdatabases B 
    LEFT OUTER JOIN msdb.dbo.backupset A        ON A.database_name = B.name AND A.type = 'D' 
GROUP BY B.Name 
HAVING B.name not in ('tempdb')
ORDER BY B.name;

SELECT 
     CONVERT(nvarchar(45),Database_Name) AS 'Database Name'
    ,DaysSinceLastBackup AS 'Days Since Backup Date'
    ,LastBackupDate AS 'Last Date Backed Up'
 FROM #Last_Backup_Dates
    -- IF @@rowcount = 0 
    -- BEGIN 
    --     PRINT '** No SQL Backup Information ** '
    -- END;
------------------------------------------------------------------------
PRINT '--##  SQL Job Status'
SELECT name JobName
	, CASE enabled WHEN 0 THEN 'N' ELSE 'Y' END EnableYN
FROM msdb.dbo.sysjobs
ORDER BY name
-- SELECT name
--     INTO #Failed_SQL_Jobs
-- FROM msdb.dbo.sysjobs A, msdb.dbo.sysjobservers B 
-- WHERE A.job_id = B.job_id AND B.last_run_outcome = 0 ;

-- IF (SELECT COUNT(*) FROM #Failed_SQL_Jobs) = 0 
-- BEGIN 
--     --PRINT '** No SQL Job Information ** '
--     SELECT '' AS 'SQL Job Name' FROM #Failed_SQL_Jobs where 1 = 0
-- END
-- ELSE
-- BEGIN
--     SELECT CONVERT(nvarchar(75), name) AS 'SQL Job Name' FROM #Failed_SQL_Jobs
-- END
-- ------------------------------------------------------------------------
-- SELECT name
--     INTO #Disabled_Jobs
-- FROM msdb.dbo.sysjobs 
-- WHERE enabled = 0
-- ORDER BY name;

-- SELECT CONVERT(nvarchar(75), name) AS 'Disabled SQL Jobs' FROM #Disabled_Jobs
-- IF @@rowcount = 0 
-- BEGIN 
--     PRINT '** No Disabled Job Information ** '
-- END;

------------------------------------------------------------------------
PRINT '--##  SQL Server Agent Job Step Info'

SELECT 
    j.[job_id] AS [JobID]
    , j.[name] AS [JobName]
    , [svr].[name] AS [OriginatingServerName]
    , [js].[step_id] AS [JobStartStepNo]
    , [js].[step_name] AS [JobStartStepName]
    , CASE j.[delete_level]
        WHEN 0 THEN 'Never'
        WHEN 1 THEN 'On Success'
        WHEN 2 THEN 'On Failure'
        WHEN 3 THEN 'On Completion'
      END AS [JobDeletionCriterion]
     , js.step_id
     , js.step_name
     , js.subsystem
     --, js.command   // 줄바꿈 포맷이 깨져서 주석처리
     , js.on_success_action
     , js.on_fail_step_id
     , js.database_name
     , js.last_run_date
FROM 
    [msdb].[dbo].[sysjobs] AS j    
    LEFT JOIN [msdb].[sys].[servers] AS [svr]                ON j.[originating_server_id] = [svr].[server_id]
    LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [js]            ON j.job_id = [js].[job_id] --AND j.[start_step_id] = [js].[step_id]
WHERE j.[name] not in ('syspolicy_purge_history')
ORDER BY [JobName], js.step_id
GO


------------------------------------------------------------------------
PRINT '--##  List of SQL Server Agent - Alerts'
select * from  msdb.dbo.sysalerts 
------------------------------------------------------------------------
PRINT '--##  List of SQL Server Agent - Operators'
SELECT name, email_address, enabled FROM MSDB.dbo.sysoperators ORDER BY name
------------------------------------------------------------------------
PRINT '--##  List of SSIS packages in MSDB'
select name, description, createdate from msdb..sysssispackages where description not like 'System Data Collector Package'
GO
------------------------------------------------------------------------
PRINT '--##  Link Servers'
SELECT * INTO #LinkInfo  FROM sys.servers WHERE is_linked ='1'

SELECT 
    CONVERT(nvarchar(25), name) as 'Name'
  , CONVERT(nvarchar(25), product) as 'Product'
  , CONVERT(nvarchar(25), provider) as 'Provider'
  , CONVERT(nvarchar(25),data_source) as 'Data Source'
 /* Uncomment the following if you want more information */
  --, CONVERT(nvarchar(20),location) as 'Location'     
  --, CONVERT(nvarchar(20),provider_string) as 'Provider String'   
  --, CONVERT(nvarchar(20),[catalog]) as 'Catalog'   
  --,connect_timeout 
  --,query_timeout 
  --,is_linked 
  --,is_remote_login_enabled 
  --,is_rpc_out_enabled 
  --,is_data_access_enabled
  --,is_collation_compatible 
  --,uses_remote_collation 
  --,CONVERT(nvarchar(20),collation_name)  
  --,lazy_schema_validation 
  --,is_system 
  --,is_publisher 
  --,is_subscriber 
  --,is_distributor 
  --,is_nonsql_subscriber 
  --,is_remote_proc_transaction_promotion_enabled 
  --,modify_date
FROM #LinkInfo

-- IF @@rowcount = 0 
-- BEGIN 
--         PRINT '** No link server connections Detection of ** '
-- END
-- ELSE
-- BEGIN
PRINT '--##  List all Linked Servers and their associated login'
SELECT ss.server_id ,ss.name 
    , 'Server ' = Case ss.Server_id   when 0 then 'Current Server'   else 'Remote Server'   end
    , ss.data_source, ss.product , ss.provider  , ss.catalog  
    , 'Local Login ' = case sl.uses_self_credential   when 1 then 'Uses Self Credentials' else ssp.name end
    , 'Remote Login Name' = sl.remote_name 
    , 'RPC Out Enabled'    = case ss.is_rpc_out_enabled when 1 then 'True' else 'False' end 
    , 'Data Access Enabled' = case ss.is_data_access_enabled when 1 then 'True' else 'False' end
    , ss.modify_date
FROM sys.Servers ss  
    LEFT JOIN sys.linked_logins sl ON ss.server_id = sl.server_id
    LEFT JOIN sys.server_principals ssp ON ssp.principal_id = sl.local_principal_id
--END
------------------------------------------------------------------------
PRINT '--##  Script out the Logon Triggers of the server, if any exists'
SELECT SSM.definition FROM sys.server_triggers AS ST JOIN sys.server_sql_modules AS SSM ON ST.object_id = SSM.object_id
------------------------------------------------------------------------
PRINT '--##  REPLICATION - List Publication or Subscription articles'

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' AND TABLE_NAME='sysextendedarticlesview') 
(
    SELECT  sub.srvname,  pub.name, art.name2, art.dest_table, art.dest_owner
    FROM sysextendedarticlesview art
        inner join syspublications pub on (art.pubid = pub.pubid)
        inner join syssubscriptions sub on (sub.artid = art.artid)
    )
ELSE
    --SELECT 'No Publication or Subcsription articles were found'
    SELECT  '' srvname,  '' name, '' name2, '' dest_table, '' dest_owner
    FROM SYS.objects
    WHERE 1 = 0
GO
------------------------------------------------------------------------
PRINT '--##  SQL Mail Information'

CREATE TABLE #Database_Mail_Details
(Status NVARCHAR(7))

IF EXISTS(SELECT * FROM master.sys.configurations WHERE configuration_id = 16386 AND value_in_use =1)
BEGIN
    INSERT INTO #Database_Mail_Details (Status)
    Exec msdb.dbo.sysmail_help_status_sp
END


IF (SELECT COUNT (*) FROM #Database_Mail_Details) = 0
BEGIN
    --PRINT '** No Database Mail Service Status Information ** '
    SELECT [Status] AS 'Database Mail Service Status' FROM #Database_Mail_Details WHERE 1=0
END
ELSE
BEGIN
    SELECT [Status] AS 'Database Mail Service Status' FROM #Database_Mail_Details
END;

------------------------------------------------------------------------
PRINT '--##  Database Mail Service Statu'

CREATE TABLE #Database_Mail_Details2
    (principal_id VARCHAR(4)
    ,principal_name VARCHAR(35)
    ,profile_id VARCHAR(4)
    ,profile_name VARCHAR(35)
    ,is_default VARCHAR(4))

INSERT INTO #Database_Mail_Details2
    (principal_id
    ,principal_name
    ,profile_id
    ,profile_name
    ,is_default)
EXEC msdb.dbo.sysmail_help_principalprofile_sp ;

SELECT 
    principal_id  
    , principal_name
    ,profile_id
    ,profile_name
    ,is_default
FROM #Database_Mail_Details2

--IF @@rowcount = 0 
--BEGIN 
--    --PRINT ' ** No SQL Mail Service Details Information **'
--    SELECT * FROM #Database_Mail_Details2 WHERE 1 =0

--END;

------------------------------------------------------------------------
PRINT '--##  Database Mirroring Status'

SELECT DB.name,
    CASE
        WHEN MIRROR.mirroring_state is NULL THEN 'Database Mirroring not configured and/or set'
        ELSE 'Mirroring is configured and/or set'
    END AS MirroringState
        INTO #Database_Mirror_Stats
FROM sys.databases DB
    JOIN sys.database_mirroring MIRROR      ON DB.database_id=MIRROR.database_id WHERE DB.database_id > 4 ORDER BY DB.NAME;

-- IF (SELECT COUNT(*) FROM #Database_Mirror_Stats) = 0
-- BEGIN
--         PRINT ' ** No Mirroring Information Detection of **'
        
-- END
-- ELSE
-- BEGIN
SELECT CONVERT(nvarchar(35),name)   AS 'Database Name'
    ,MirroringState                 AS 'Mirroring State'
FROM #Database_Mirror_Stats
--END;
------------------------------------------------------------------------
PRINT '--##  Database Mirroring Database'

SELECT db_name(database_id) as 'Mirror DB_Name', 
    CASE mirroring_state 
        WHEN 0 THEN 'Suspended' 
        WHEN 1 THEN 'Disconnected from other partner' 
        WHEN 2 THEN 'Synchronizing' 
        WHEN 3 THEN 'Pending Failover' 
        WHEN 4 THEN 'Synchronized' 
        WHEN null THEN 'Database is inaccesible or is not mirrored' 
    END as 'Mirroring_State', 
    CASE mirroring_role 
        WHEN 1 THEN 'Principal' 
        WHEN 2 THEN 'Mirror' 
        WHEN null THEN 'Database is not mirrored or is inaccessible' 
    END as 'Mirroring_Role', 
    CASE mirroring_safety_level 
        WHEN 0 THEN 'Unknown state' 
        WHEN 1 THEN 'OFF (Asynchronous)' 
        WHEN 2 THEN 'FULL (Synchronous)' 
        WHEN null THEN 'Database is not mirrored or is inaccessible' 
    END as 'Mirror_Safety_Level', 
    Mirroring_Partner_Name as 'Mirror_Endpoint', 
    Mirroring_Partner_Instance as 'Mirror_ServerName', 
    Mirroring_Witness_Name as 'Witness_Endpoint', 
    CASE Mirroring_Witness_State 
        WHEN 0 THEN 'Unknown' 
        WHEN 1 THEN 'Connected' 
        WHEN 2 THEN 'Disconnected' 
        WHEN null THEN 'Database is not mirrored or is inaccessible' 
    END as 'Witness_State', 
    Mirroring_Connection_Timeout as 'Failover Timeout in seconds', 
    Mirroring_Redo_Queue, 
    Mirroring_Redo_Queue_Type 
    INTO #DB_Mirror_Details
    FROM sys.Database_mirroring WHERE mirroring_role is not null;

-- IF (SELECT COUNT(*) FROM #DB_Mirror_Details) = 0
-- BEGIN 
--     --PRINT ' ** No Mirroring Configuration Information Detection of**'
--     SELECT * FROM #DB_Mirror_Details WHERE 1 = 0
-- END
-- ELSE
-- BEGIN
SELECT * FROM #DB_Mirror_Details
--END

------------------------------------------------------------------------
PRINT '--##  Database Log Shipping Status'
CREATE TABLE #LogShipping
    ([status] BIT
    , [is_primary] BIT
    , [server] sysname
    , [database_name] sysname
    , [time_since_last_backup] INT
    , [last_backup_file] NVARCHAR(50)
    , [backup_threshold] INT
    , [is_backup_alert_enabled] BIT
    , [time_since_last_copy] INT
    , [last_copied_file] NVARCHAR(50)
    , [time_since_last_restore] INT
    , [last_restored_file]  NVARCHAR(50)
    , [last_restored_latency] INT
    , [restore_threshold] INT
    , [is_restore_alert_enabled] BIT)
INSERT INTO #LogShipping
EXEC sp_help_log_shipping_monitor;

IF (SELECT COUNT(*) FROM #LogShipping) = 0
    BEGIN 
        -- PRINT '** No Database Log Shipping Information Detection of ** '
        SELECT * FROM #LogShipping WHERE 1 = 0
    END
    ELSE
    BEGIN
        SELECT * FROM #LogShipping
    END

------------------------------------------------------------------------
PRINT '--##  Report Server (SSRS) Reports Information'

IF EXISTS (SELECT name FROM sys.databases where name = 'ReportServer')
BEGIN
    -- IF (SELECT COUNT(*) FROM reportserver.dbo.Catalog) = 0
    -- BEGIN 
    --     --PRINT '** No Report Server (SSRS) Reports Information ** '
    --     SELECT '' AS 'Role Name'
    --         , '' AS 'User Name'
    --         , '' AS 'Report Name'
    --         , '' AS 'Catalog Type'
    --         , '' AS 'Description'
    --     FROM SYS.objects
    --     WHERE 1 = 0
    -- END
    -- ELSE
    -- BEGIN
        SELECT CONVERT(nvarchar(20),Rol.RoleName) AS 'Role Name'
            ,CONVERT(nvarchar(35),Us.UserName) AS 'User Name'
            ,CONVERT(nvarchar(35),Cat.[Name]) AS 'Report Name'
            ,CASE Cat.Type WHEN 1 THEN 'Folder' WHEN 2 THEN 'Report' 
                WHEN 3 THEN 'Resource' WHEN 4 THEN 'Linked Report' 
                WHEN 3 THEN 'Data Source' ELSE '' END AS 'Catalog Type'
            ,CONVERT(nvarchar(35),Cat.Description) AS'Description'
        FROM reportserver.dbo.Catalog Cat 
            INNER JOIN reportserver.dbo.Policies Pol ON Cat.PolicyID = Pol.PolicyID
            INNER JOIN reportserver.dbo.PolicyUserRole PUR ON Pol.PolicyID = PUR.PolicyID 
            INNER JOIN reportserver.dbo.Users Us ON PUR.UserID = Us.UserID 
            INNER JOIN reportserver.dbo.Roles Rol ON PUR.RoleID = Rol.RoleID
        WHERE   Cat.Type in (1,2)
        ORDER BY Cat.PATH 
    -- END
END
ELSE
BEGIN 
    --PRINT '** No SSRS Reports Information Detection of ** '
    SELECT '' AS 'Role Name'
        , '' AS 'User Name'
        , '' AS 'Report Name'
        , '' AS 'Catalog Type'
        , '' AS 'Description'
    FROM SYS.objects
    WHERE 1 = 0
END
------------------------------------------------------------------------
PRINT '--##  SQL Server base folder & Port Info'

if (CONVERT(decimal(5, 1), CONVERT(char(4), SERVERPROPERTY('ProductVersion'))) >= 11.0 )    -- Windows 2012 이상만 sys.dm_server_registry 이용. 2008 r2 sp1부터 가능하지만 귀찮
BEGIN
    select *
    from sys.dm_server_registry
    where (
            (registry_key = 'HKLM\SYSTEM\CurrentControlSet\Services\MSSQLSERVER' and value_name = 'ImagePath')
                or (registry_key like '%SuperSocketNetLib\Tcp\IP%')
        )
        and registry_key not in
        (
            SELECT registry_key
            FROM sys.dm_server_registry
            WHERE registry_key like '%SuperSocketNetLib\Tcp\IP%' AND value_name = 'Enabled' and value_data = 0
        )
END
ELSE
BEGIN
    ------------------------------------------------------------------------
    DECLARE @HkeyLocal nvarchar(18)
    Declare @Instance varchar(100)
    DECLARE @MSSqlServerRegPath nvarchar(200)
    DECLARE @TcpPort nvarchar(100)
    DECLARE @TcpDynamicPorts nvarchar(100)
    
    DECLARE @InstanceVersion  varchar(100)


    SET @InstanceVersion = CASE CONVERT(char(4), SERVERPROPERTY('ProductVersion'))
                            WHEN '9.00' THEN '9'
                            WHEN '10.0' THEN '10'
                            WHEN '10.5' THEN '10_50'
                            WHEN '11.0' THEN '11'
                            WHEN '12.0' THEN '12'
                        END
    SET @Instance ='MSSQL' + @InstanceVersion + '.' +  CONVERT(VARCHAR(50), SERVERPROPERTY('InstanceName'))
    --PRINT @Instance
    --SET @Instance ='MSSQL10_50.SQLEXPRESS'
    SET @HkeyLocal=N'HKEY_LOCAL_MACHINE'
    SET @MSSqlServerRegPath=N'SOFTWARE\Microsoft\\Microsoft SQL Server\'
        + @Instance + '\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
    
    --Print @MSSqlServerRegPath
    EXEC xp_instance_regread @HkeyLocal    , @MSSqlServerRegPath    , N'TcpPort'    , @TcpPort OUTPUT
    EXEC xp_instance_regread @HkeyLocal    , @MSSqlServerRegPath    , N'TcpDynamicPorts'    , @TcpDynamicPorts OUTPUT

    SELECT @HkeyLocal + '\' +  @MSSqlServerRegPath registry_key, 'TcpPort' value_name, isnull(@TcpPort, '') as value_data
    union all SELECT @HkeyLocal + '\' +  @MSSqlServerRegPath registry_key, 'TcpDynamicPorts' , isnull(@TcpDynamicPorts, '') as value_data 

END    
GO

------------------------------------------------------------------------
PRINT '--##  SQL Server Fulltext Info'

SELECT * from sys.fulltext_indexes ;
GO

------------------------------------------------------------------------
PRINT '--##  List all System and Mirroring endpoints'

select * from sys.endpoints 
GO

------------------------------------------------------------------------
-- Performing clean up
--DROP TABLE #KERBINFO;
DROP TABLE #nodes;
--DROP TABLE #IP;
DROP TABLE #SQL_Server_Settings;
DROP TABLE #ServicesServiceStatus;    
DROP TABLE #RegResult;    
DROP TABLE #LinkInfo;
DROP TABLE #HD_space;
DROP TABLE #Last_Backup_Dates;
-- DROP TABLE #Failed_SQL_Jobs;
-- DROP TABLE #Disabled_Jobs;
DROP TABLE #Database_Mail_Details;
DROP TABLE #Database_Mail_Details2;
DROP TABLE #Database_Mirror_Stats;
DROP TABLE #DB_Mirror_Details;
DROP TABLE #LogShipping;
DROP TABLE #Databases_Details;

GO


