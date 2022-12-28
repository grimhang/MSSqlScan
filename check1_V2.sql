/* SQL Server Configuration Report  
2018-01-18     Ver1 초기완성 버전
2018-02-18     Ver2 개선 버전
2018-04-26     Ver2 최종 개선 버전
2021-04-12     Ver2 Database 쪽 옵션 추가, AG 여부 추가
2021-07-13     Ver2 sys.configuration에 order by name 추가
2022-12-26     Ver2 데이터베이스 파일 크기 정확하게 수정
-------------------------------------------------------------------------*/
USE MASTER
GO

SET NOCOUNT ON;

DECLARE
     @NodeName1 NVARCHAR(50) 		            -- Name of node 1 if clustered
    , @NodeName2 NVARCHAR(50) 		            -- Name of node 2 if clustered
    , @AccountName NVARCHAR(50) 	            -- Account name used
    , @VALUENAME NVARCHAR(20) 		            -- Detect account used in SQL 2005, see notes below
    , @InstallDate datetime 		            -- Installation date of SQL Server
    , @ProductVersion NVARCHAR(50) 	            -- Production version
    , @ProductVersionDesc NVARCHAR(100) 	    -- Production version Detail Description
    , @Instance NVARCHAR(30) 		            --  Instance name
    , @EnvironmentType VARCHAR(15) 	            -- Physical or Virtual
    , @TotalMEMORYinBytes NVARCHAR(10)          -- Total memory
    , @AuditLevel int
    , @ImagePath varchar(500)

--=================== 01. MS-SQL Server Information =================
PRINT '--##  Report Date'   -- Ver 2.0

SELECT @@SERVERNAME "Server Name", CONVERT(varchar(100), GETDATE(), 120) "Report Date"

----------------------------------------------------------------
PRINT CHAR(13) + CHAR(10) + '--##  Summary'

SET @InstallDate = (SELECT  createdate FROM sys.syslogins where name = 'NT AUTHORITY\SYSTEM')       -- NT AUTHORITY\SYSTEM's createdate

SET @ProductVersion     = CONVERT(nvarchar(50), SERVERPROPERTY('ProductVersion'))     -- If not convert, Error "Implicit conversion from data type sql_variant to nvarchar is not allowed. ...."
SET @ProductVersionDesc =   CASE
                                WHEN @ProductVersion LIKE '6.5%'   THEN 'SQL Server 6.5'
                                WHEN @ProductVersion LIKE '7.0%'   THEN 'SQL Server 7'
                                WHEN @ProductVersion LIKE '8.0%'   THEN 'SQL Server 2000'
                                WHEN @ProductVersion LIKE '9.0%'   THEN 'SQL Server 2005'  
                                WHEN @ProductVersion LIKE '10.0%'  THEN 'SQL Server 2008' 
                                WHEN @ProductVersion LIKE '10.50%' THEN 'SQL Server 2008R2' 
                                WHEN @ProductVersion LIKE '11.0%'  THEN 'SQL Server 2012' 
                                WHEN @ProductVersion LIKE '12.0%'  THEN 'SQL Server 2014' 
                                WHEN @ProductVersion LIKE '13.0%'  THEN 'SQL Server 2016'
                                WHEN @ProductVersion LIKE '14.0%'  THEN 'SQL Server 2017'
                                WHEN @ProductVersion LIKE '15.0%'  THEN 'SQL Server 2019'  -- for future use  
                            END

------------------------------------------------------------------------
--For Service Account Name - This line will work on SQL 2008R2 and higher only
--So the lines below are being used until SQL 2005 is removed/upgraded
EXECUTE  master.dbo.xp_instance_regread
        @rootkey      = N'HKEY_LOCAL_MACHINE',
        @key          = N'SYSTEM\CurrentControlSet\Services\MSSQLServer',
        @value_name   = N'ObjectName',
        @value        = @AccountName OUTPUT

------------------------------------------------------------------------
--cluster node names. Modify if there are more than 2 nodes in cluster

IF @@rowcount = 0 
    SET @NodeName1 = 'NONE' -- NONE for no cluster
ELSE
BEGIN
    SET @NodeName1 = (SELECT top 1 NodeName from sys.dm_os_cluster_nodes order by NodeName)
    SET @NodeName2 = (SELECT TOP 1 NodeName from sys.dm_os_cluster_nodes  where NodeName > @NodeName1)
END

------------------------------------------------------------------------
EXEC MASTER.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'AuditLevel', @AuditLevel OUTPUT

------------------------------------------------------------------------
EXEC MASTER.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SYSTEM\CurrentControlSet\Services\MSSQLSERVER', N'ImagePath', @ImagePath OUTPUT

------------------------------------------------------------------------
SELECT KeyName, KeyVal
FROM
(
    SELECT 0 ValSeq, 'Clustered Status' as keyname          ,   CASE WHEN CONVERT(char(30), SERVERPROPERTY('ISClustered')) = 1 THEN 'Clustered'
                                                                    ELSE
                                                                    'Not Clustered'
                                                                END          KeyVal
    UNION SELECT 1 ValSeq, 'AlwaysOn AG YN' as keyname          ,   CASE WHEN SERVERPROPERTY('IsHadrEnabled') = 1 THEN 'Y'
                                                                    ELSE
                                                                    'N'
                                                                END          KeyVal
    UNION SELECT 2, 'SQLServerName\InstanceName'            , @@ServerName -- @SQLServerName
    UNION SELECT 3, 'Active Node'                           , SERVERPROPERTY('ComputerNamePhysicalNetBIOS')
    UNION SELECT 4, 'Machine Name'                          , CONVERT(char(100), SERVERPROPERTY('MachineName')) --@MachineName
    UNION SELECT 5, 'Instance Name'                         ,   CASE
                                                                    WHEN  SERVERPROPERTY('InstanceName') IS NULL THEN 'Default Instance'
                                                                    ELSE CONVERT(varchar(50), SERVERPROPERTY('InstanceName'))
                                                                END
    UNION SELECT 6, 'Install Date'                          , CONVERT(varchar(200), @InstallDate, 120)

    UNION SELECT 7, 'Production Name'                       , @ProductVersionDesc
    UNION SELECT 8, 'SQL Server Edition and Bit Level'      , CONVERT(varchar(30), SERVERPROPERTY('EDITION'))
    UNION SELECT 9, 'SQL Server Bit Level'                  , CASE WHEN CHARINDEX('64-bit', @@VERSION) > 0 THEN '64bit' else '32bit' end
    UNION SELECT 10, 'SQL Server Service Pack'              , CONVERT(varchar(30), SERVERPROPERTY('ProductLevel'))

    UNION SELECT 11, 'Logical CPU Count'                    , (SELECT cpu_count FROM sys.dm_os_sys_info)

    UNION SELECT 12, 'OS Memory'                            , (select total_physical_memory_kb / 1024       from sys.dm_os_sys_memory)
    UNION SELECT 13, 'OS Available Memory'                  , (select available_physical_memory_kb / 1024   from sys.dm_os_sys_memory)
    UNION SELECT 14, 'OS Memory Status'                     , (select system_memory_state_desc from sys.dm_os_sys_memory)
    UNION SELECT 15, 'Max Server Memory(Megabytes)'         , (select CONVERT(char(10), [value_in_use]) from  master.sys.configurations where name = 'max server memory (MB)')
    UNION SELECT 16, 'Min Server Memory(Megabytes)'         , (select CONVERT(char(10), [value_in_use]) from  master.sys.configurations where name = 'min server memory (MB)')

    UNION SELECT 17, 'Server IP Address'                    , (SELECT TOP 1 Local_Net_Address FROM sys.dm_exec_connections WHERE net_transport = 'TCP' GROUP BY Local_Net_Address ORDER BY COUNT(*) DESC)
    UNION SELECT 18, 'Port Number'                          , (SELECT TOP 1 local_tcp_port FROM sys.dm_exec_connections WHERE net_transport = 'TCP' GROUP BY local_tcp_port ORDER BY COUNT(*) DESC)
    UNION SELECT 19, 'Domain Name'                          , DEFAULT_DOMAIN()
    UNION SELECT 20, 'Service Account name'                 , @AccountName
    UNION SELECT 21, 'Node1 Name'                           , @NodeName1
    UNION SELECT 22, 'Node2 Name'                           , @NodeName2
    UNION SELECT 24, 'Security Mode'                        , CASE WHEN CONVERT(int, SERVERPROPERTY('ISIntegratedSecurityOnly')) = 1 THEN 'Windows Authentication Security Mode'
                                                                   ELSE 'SQL Server Authentication Security Mode'
                                                              END
    UNION SELECT 25, 'Audit Level'                          , CASE 
                                                                WHEN @AuditLevel = 0    THEN 'None'
                                                                WHEN @AuditLevel = 1    THEN 'Successful logins only'
                                                                WHEN @AuditLevel = 2    THEN 'Failed logins only'
                                                                WHEN @AuditLevel = 3    THEN 'Both successful and failed logins'
                                                                ELSE 'Unknown'
                                                              END
    UNION SELECT 26, 'User Mode'                            , CASE WHEN CONVERT(int, SERVERPROPERTY('ISSingleUser')) = 1 THEN 'Single User' ELSE 'Multi User' END
    UNION SELECT 27, 'SQL Server Collation Type'            , CONVERT(varchar(30), SERVERPROPERTY('COLLATION'))
    UNION SELECT 28, 'SQL Server Engine Location'           , REPLACE(SUBSTRING(@ImagePath, 2, CHARINDEX('"',  @ImagePath, 2) - 2), 'sqlservr.exe', '')
    UNION SELECT 29, 'SQL Server Errorlog Location'         , REPLACE(CAST(SERVERPROPERTY('ErrorLogFileName') AS VARCHAR(500)), 'ERRORLOG','')
    UNION SELECT 30, 'SQL Server Default Trace Location'    , REPLACE(CONVERT(VARCHAR(100), SERVERPROPERTY('ErrorLogFileName')), '\ERRORLOG','\log.trc')
    UNION SELECT 31, 'Number of Link Servers'               , (SELECT COUNT(*) FROM sys.servers WHERE is_linked ='1')
    UNION SELECT 32, 'SQL Server Engine Start Time'         , (SELECT sqlserver_start_time FROM sys.dm_os_sys_info)
) temp
ORDER BY ValSeq
------------------------------------------------------------------------
PRINT CHAR(13) + CHAR(10) + '--##  Logins'

select *
	, CASE IS_SRVROLEMEMBER('sysadmin', name) WHEN 0 THEN '' ELSE 'Y' END SysAdminYN
	, CASE IS_SRVROLEMEMBER('serveradmin', name) WHEN 0 THEN '' ELSE 'Y' END ServerAdminYN
from sys.server_principals
where type in ('S', 'U')
order by name
------------------------------------------------------------------------
PRINT CHAR(13) + CHAR(10) + '--##  Server Configuration'

SELECT [name]                               AS 'Configuration Setting'
    , (CONVERT (CHAR(20),[value_in_use] ))  AS 'Value in Use'
FROM master.sys.configurations
ORDER BY name
------------------------------------------------------------------------
PRINT CHAR(13) + CHAR(10) + '--##  Automatically executes on startup Code'

SELECT CONVERT (NVARCHAR(35), name) AS 'Name'
    , CONVERT (NVARCHAR(25), type_desc) AS 'Type'
    ,  create_date AS 'Created Date'
    ,  modify_date AS 'Modified Date'
FROM sys.procedures
WHERE is_auto_executed = 1

-------------------------------------------------------------------------------
--=================== 02. SQL Server all Services Information =================
CREATE TABLE #RegResult (ResultValue NVARCHAR(4))

CREATE TABLE #ServicesServiceStatus            
( 
     RowID INT IDENTITY(1,1)
    , ServerName NVARCHAR(30)
    , ServiceName NVARCHAR(45)
    , ServiceStatus varchar(15)
    , StatusDateTime DATETIME DEFAULT (GETDATE())
    , PhysicalServerName NVARCHAR(50)
    , ServiceAccount NVARCHAR(200)
)

DECLARE
    @ChkInstanceName nvarchar(128)
    , @ChkSrvName nvarchar(128)
    , @TrueSrvName nvarchar(128)
    , @SQLSrv NVARCHAR(128)
    , @PhysicalSrvName NVARCHAR(128)
    , @FTS nvarchar(128)
    , @RS nvarchar(128)
    , @SQLAgent NVARCHAR(128)
    , @OLAP nvarchar(128)
    , @REGKEY NVARCHAR(128)
    , @StartupAccount NVARCHAR(128)
SET @PhysicalSrvName = CAST(SERVERPROPERTY('MachineName') AS VARCHAR(128)) 
SET @ChkSrvName = CAST(SERVERPROPERTY('INSTANCENAME') AS VARCHAR(128)) 
SET @ChkInstanceName = @@ServerName

IF @ChkSrvName IS NULL                            
BEGIN 
    SET @TrueSrvName = 'MSQLSERVER'
    SET @OLAP = 'MSSQLServerOLAPService'     
    SET @FTS = 'MSSQLFDLauncher'
    SET @RS = 'ReportServer' 
    SET @SQLAgent = 'SQLSERVERAGENT'
    SET @SQLSrv = 'MSSQLSERVER'
END 
ELSE
BEGIN
    SET @TrueSrvName =  CAST(SERVERPROPERTY('INSTANCENAME') AS VARCHAR(128)) 
    SET @SQLSrv = '$' + @ChkSrvName
    SET @OLAP = 'MSOLAP' + @SQLSrv    /*Setting up proper service name*/
    SET @FTS = 'MSSQLFDLauncher' + @SQLSrv 
    SET @RS = 'ReportServer' + @SQLSrv
    SET @SQLAgent = 'SQLAgent' + @SQLSrv
    SET @SQLSrv = 'MSSQL' + @SQLSrv
END 
;
----- 02.1 SQL Server Service Section -----------------
-- 여기 xp_instance_regread로 바꾸기
SET @REGKEY = 'System\CurrentControlSet\Services\' + @SQLSrv

INSERT #RegResult ( ResultValue )
EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1 
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus) EXEC xp_servicecontrol N'QUERYSTATE', @SQLSrv    

    -- StartupAccount from registry
    EXEC master.sys.xp_regread
        @rootkey    = N'HKEY_LOCAL_MACHINE',
        @key        = @REGKEY,
        @value_name = N'ObjectName',
        @value      = @StartupAccount OUTPUT

    UPDATE #ServicesServiceStatus
    SET ServiceAccount = @StartupAccount
    WHERE RowID = @@identity    
END
ELSE 
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')

UPDATE #ServicesServiceStatus
set ServiceName = 'MS SQL Server Service'
where RowID = @@identity    

TRUNCATE TABLE #RegResult

----- 02.2 SQL Server Agent Service Section -----------
SET @REGKEY = 'System\CurrentControlSet\Services\' + @SQLAgent

INSERT #RegResult ( ResultValue )
EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus) EXEC xp_servicecontrol N'QUERYSTATE',@SQLAgent    

    -- StartupAccount from registry
    EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE'
        , @key = @REGKEY, @value_name = 'ObjectName', @value = @StartupAccount output
    
    UPDATE #ServicesServiceStatus
    SET ServiceAccount = @StartupAccount
    WHERE RowID = @@identity    
END    
ELSE 
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')

UPDATE #ServicesServiceStatus
set ServiceName = 'SQL Server Agent Service'
where RowID = @@identity

TRUNCATE TABLE #RegResult

----- 02.3 SQL Browser Service Section ----------------
SET @REGKEY = 'System\CurrentControlSet\Services\SQLBrowser'

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1     
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus) EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',N'sqlbrowser'
    -- StartupAccount from registry
    EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE'
        , @key = @REGKEY, @value_name = 'ObjectName', @value = @StartupAccount output
    
    UPDATE #ServicesServiceStatus
    SET ServiceAccount = @StartupAccount
    WHERE RowID = @@identity    
END        
ELSE 
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')

UPDATE #ServicesServiceStatus
set ServiceName = 'SQL Browser Service - Instance Independent'
where RowID = @@identity

TRUNCATE TABLE #RegResult

----- 02.4 Integration Service Section ----------------
DECLARE @integrationServiceIns NVARCHAR(100)

SET @integrationServiceIns = 'MsDtsServer' + 
                                            CASE
                                                WHEN @ProductVersion LIKE '6.5%'   THEN ''
                                                WHEN @ProductVersion LIKE '7.0%'   THEN ''
                                                WHEN @ProductVersion LIKE '8.0%'   THEN ''
                                                WHEN @ProductVersion LIKE '9.0%'   THEN ''      -- 2005
                                                WHEN @ProductVersion LIKE '10.%'  THEN '100'   -- 2008
                                                --WHEN @ProductVersionTemp LIKE '10.50%' THEN '105'   -- 2008 R2
                                                WHEN @ProductVersion LIKE '11.0%'  THEN '110'   -- 2012
                                                WHEN @ProductVersion LIKE '12.0%'  THEN '120'   -- 2014
                                                WHEN @ProductVersion LIKE '13.0%'  THEN '130'   -- 2016
                                                WHEN @ProductVersion LIKE '14.0%'  THEN '140'   -- 2017
                                                WHEN @ProductVersion LIKE '15.0%'  THEN '140'   -- 2019
                                                ELSE ''
                                            END

SET @REGKEY = 'System\CurrentControlSet\Services\' + @integrationServiceIns

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1 
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus) EXEC master.dbo.xp_servicecontrol N'QUERYSTATE', @integrationServiceIns
    -- StartupAccount from registry
    EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE'
        , @key = @REGKEY, @value_name = 'ObjectName', @value = @StartupAccount output
    
    UPDATE #ServicesServiceStatus
    SET ServiceAccount = @StartupAccount
    WHERE RowID = @@identity    
END            
ELSE 
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')

UPDATE #ServicesServiceStatus
set ServiceName = 'Integration Service - Instance Independent'
where RowID = @@identity

TRUNCATE TABLE #RegResult

----- 02.5 Reporting Service Section ------------------
SET @REGKEY = 'System\CurrentControlSet\Services\' + @RS

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus) EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',@RS
    -- StartupAccount from registry
    EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE'
        , @key = @REGKEY, @value_name = 'ObjectName', @value = @StartupAccount output
    
    UPDATE #ServicesServiceStatus
    SET ServiceAccount = @StartupAccount
    WHERE RowID = @@identity    
END
ELSE 
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')

UPDATE #ServicesServiceStatus
set ServiceName = 'Reporting Service'
where RowID = @@identity

TRUNCATE TABLE #RegResult

----- 02.6 Analysis Service Section -------------------
IF @ChkSrvName IS NULL                                
    SET @OLAP = 'MSSQLServerOLAPService'
ELSE    
    SET @OLAP = 'MSOLAP'+'$'+@ChkSrvName

SET @REGKEY = 'System\CurrentControlSet\Services\' + @OLAP

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus) EXEC master.dbo.xp_servicecontrol N'QUERYSTATE', @OLAP

    -- StartupAccount from registry
    EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE'
        , @key = @REGKEY, @value_name = 'ObjectName', @value = @StartupAccount output
    
    UPDATE #ServicesServiceStatus
    SET ServiceAccount = @StartupAccount
    WHERE RowID = @@identity
END
ELSE 
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')

UPDATE #ServicesServiceStatus
set ServiceName = 'Analysis Services'
where RowID = @@identity

TRUNCATE TABLE #RegResult

----- 02.7 Full Text Search Service Section -----------
SET @REGKEY = 'System\CurrentControlSet\Services\' + @FTS

INSERT #RegResult ( ResultValue ) EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@REGKEY

IF (SELECT ResultValue FROM #RegResult) = 1
BEGIN
    INSERT #ServicesServiceStatus (ServiceStatus) EXEC master.dbo.xp_servicecontrol N'QUERYSTATE',@FTS
    
    -- StartupAccount from registry
    EXEC master.sys.xp_regread @rootkey='HKEY_LOCAL_MACHINE'
        , @key = @REGKEY, @value_name = 'ObjectName', @value = @StartupAccount output
    
    UPDATE #ServicesServiceStatus
    SET ServiceAccount = @StartupAccount
    WHERE RowID = @@identity
END
ELSE
    INSERT INTO #ServicesServiceStatus (ServiceStatus) VALUES ('NOT INSTALLED')

UPDATE #ServicesServiceStatus
set ServiceName = 'Full Text Search Service'
where RowID = @@identity

TRUNCATE TABLE #RegResult

----- 02.8 ServerName Update --------------------------
UPDATE #ServicesServiceStatus
set ServerName = @TrueSrvName, PhysicalServerName = @PhysicalSrvName

----- 02.9 Total Service Section ----------------------
PRINT CHAR(13) + CHAR(10) + '--##  SQL Server All Services' 

SELECT ServerName as 'SQLServer\InstanceName'
    , ServiceName
    , ServiceStatus
    , ServiceAccount    -- 2019-04-12 add
    , StatusDateTime
FROM  #ServicesServiceStatus;        

DROP TABLE #ServicesServiceStatus;   
DROP TABLE #RegResult;

--=================== 03. OS Hard Drive Space Information =================
PRINT CHAR(13) + CHAR(10) + '--##  OS Hard Drive Space Available'

CREATE TABLE #HD_space
(
    Drive varchar(2) NOT NULL,
    [MB free] int NOT NULL
)

INSERT INTO #HD_space(Drive, [MB free])
EXEC master.sys.xp_fixeddrives;

SELECT Drive AS 'Drive Letter'
    ,[MB free]  AS 'Free Disk Space (Megabytes)'
FROM #HD_space
GO

DROP TABLE #HD_space;
--=================== 04. Database Information =================
----- 04.1 Database Section ---------------------
PRINT CHAR(13) + CHAR(10) + '--##  Databases'

SELECT 
    D.database_id 'Database ID'
    , D.name AS 'DBName'
    , Max(D.collation_name)			    AS 'Collation'
    , Max(D.compatibility_level)	    AS 'Compatibility'
    , Max(D.user_access_desc)		    AS 'User Access'
    , Max(D.state_desc)				    AS 'Status'
    , Max(D.recovery_model_desc)	    AS 'Recovery Model'
    , MAX(SUSER_SNAME(D.owner_sid))     AS 'DBOwnerName'
    , SUM(CASE WHEN F.type_desc ='ROWS' THEN CAST(F.size AS BIGINT) ELSE 0 END) * 8/ 1024	AS TotalDataDiskSpace_MB
    , SUM(CASE WHEN F.type_desc ='LOG' THEN CAST(F.size AS BIGINT) ELSE 0 END) * 8 / 1024 	AS TotalLogDiskSpace_MB
    , MAX(D.snapshot_isolation_state_desc)                                                  AS 'Snapshot Isolation State'
    , CASE D.is_read_committed_snapshot_on WHEN 0 THEN 'False' ELSE 'True'  END             AS 'Is ReadCommitted Snapshot On'
    , MAX(D.log_reuse_wait_desc)                                                            AS 'Log Reuse Wait Desc'
    , MAX(D.target_recovery_time_in_seconds)                                                AS 'Target Recovery Time_Sec'
FROM SYS.DATABASES D
    JOIN sys.master_files F					ON D.database_id= F.database_id
    LEFT JOIN
    (
        SELECT database_name, MAX(backup_finish_date) MY_DATE
        FROM msdb.dbo.backupset
        WHERE 1=1
            --DATABASE_NAME ='TL_REPORT'
            AND type = 'D'	-- Data backup only
        GROUP BY database_name
    ) B			ON B.database_name = D.name 
--WHERE D.name NOT IN ('master', 'model', 'tempdb')
    --AND D.DATABASE_ID = 9 AND type_desc ='ROWS'
GROUP BY D.database_id, D.[name], D.is_read_committed_snapshot_on
ORDER BY D.[name]
GO

----- 04.2 Database File Section ---------------------
PRINT CHAR(13) + CHAR(10) + '--##  Database Files'

SELECT 
    D.name AS 'DBName'
    , S.database_id, S.[file_id], S.type, S.type_desc, S.data_space_id, S.name, S.physical_name, S.state, S.state_desc
    , S.size / 128 AS DBSize_MB, S.max_size, S.growth / 128 AS growth_MB
    -- , S.*
FROM SYS.DATABASES D
    INNER JOIN sys.master_files S       ON D.database_id= S.database_id
--WHERE D.name NOT IN ('model')
ORDER BY D.[name], s.file_id
GO

----- 04.3 Database users Section ---------------------
PRINT CHAR(13) + CHAR(10) + '--##  Database users Permissions'

DECLARE @DB_USers TABLE(DBName sysname, UserName sysname, LoginType sysname, AssociatedRole varchar(max),create_date datetime,modify_date datetime)
INSERT @DB_USers EXEC sp_MSforeachdb'
    use [?]
    SELECT ''?'' AS DB_Name,
        case prin.name when ''dbo'' then prin.name + '' (''+ (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') + '')'' else prin.name end AS UserName,
        prin.type_desc AS LoginType,
        isnull(USER_NAME(mem.role_principal_id),'''') AS AssociatedRole ,create_date,modify_date
    FROM sys.database_principals prin
        LEFT JOIN sys.database_role_members mem ON prin.principal_id=mem.member_principal_id
    WHERE prin.sid IS NOT NULL and prin.sid NOT IN (0x00)
        AND prin.is_fixed_role <> 1 AND prin.name NOT LIKE ''##%'''

SELECT dbname,username ,logintype     
    , create_date ,modify_date , STUFF((SELECT ',' + CONVERT(VARCHAR(500),associatedrole)
FROM @DB_USers user2
WHERE user1.DBName=user2.DBName
    AND user1.UserName = user2.UserName
        FOR XML PATH('') ),1,1,'') AS Permissions_user
        FROM @DB_USers user1
GROUP BY dbname,username ,logintype ,create_date ,modify_date
HAVING dbname not in ('tempdb')
ORDER BY DBName,username
GO

----- 04.4 Database Mail Service Section --------------
PRINT CHAR(13) + CHAR(10) + '--##  Database Mail Service'

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

DROP TABLE #Database_Mail_Details2;

----- 04.5 Database Mirroring Service Section ---------
PRINT CHAR(13) + CHAR(10) + '--##  Database Mirroring'

SELECT CONVERT(nvarchar(35),DBName)   AS 'Database Name'
    , MirroringState                 AS 'Mirroring State'
FROM 
(
    SELECT DB.name DBName,
        'Mirroring is dnabled'  AS MirroringState
    FROM sys.databases DB
    JOIN sys.database_mirroring MIRROR      ON DB.database_id = MIRROR.database_id
    WHERE DB.database_id > 4 
        and MIRROR.mirroring_state is not null
) T
ORDER BY DBName;

----- 04.6 Database Mirroring Database Section --------
PRINT CHAR(13) + CHAR(10) + '--##  Database Mirroring Database'

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
FROM sys.Database_mirroring
WHERE mirroring_role is not null;

----- 04.7 Database Log Shipping Section --------------
PRINT CHAR(13) + CHAR(10) + '--##  Database Log Shipping'

IF (CONVERT(VARchar(30), SERVERPROPERTY('EDITION')) LIKE 'Express%')
BEGIN
    SELECT 
        '' [status]
        , '' [is_primary]
        , '' [server]
        , '' [database_name]
        , '' [time_since_last_backup]
        , '' [last_backup_file]
        , '' [backup_threshold]
        , '' [is_backup_alert_enabled]
        , '' [time_since_last_copy]
        , '' [last_copied_file]
        , '' [time_since_last_restore]
        , '' [last_restored_file]
        , '' [last_restored_latency]
        , '' [restore_threshold] 
        , '' [is_restore_alert_enabled]
    FROM SYS.objects
    WHERE 1 = 0
END    
ELSE    
BEGIN
    CREATE TABLE #LogShipping
    (   [status] BIT
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
        , [is_restore_alert_enabled] BIT
    )
    INSERT INTO #LogShipping
    EXEC sp_help_log_shipping_monitor;
    
    SELECT * FROM #LogShipping

    DROP TABLE #LogShipping
END

--=================== 05. SQL Job Information =================
----- 05.1 SQL Job Section --------------
PRINT CHAR(13) + CHAR(10) + '--##  SQL Jobs'

SELECT name JobName
    , CASE enabled WHEN 0 THEN 'N' ELSE 'Y' END EnableYN
FROM msdb.dbo.sysjobs
where name not in ('syspolicy_purge_history')
ORDER BY name

----- 05.2 SQL Job Step Section --------------
PRINT CHAR(13) + CHAR(10) + '--##  SQL Job Steps'

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

----- 05.3 SQL Job Alerts Section --------------
PRINT CHAR(13) + CHAR(10) + '--##  SQLServerAgent_Alerts'

select * from  msdb.dbo.sysalerts 

----- 05.4 SQL Job Operators Section -----------
PRINT CHAR(13) + CHAR(10) + '--##  SQLServerAgent_Operators'

SELECT name, email_address, enabled FROM MSDB.dbo.sysoperators ORDER BY name

----- 05.5 SSISPackagesInMSDB Section -----------
PRINT CHAR(13) + CHAR(10) + '--##  SSISPackagesInMSDB'

select name, description, createdate
from msdb..sysssispackages
where description not like 'System Data Collector Package'
GO

--=================== 06. Linked Servers =================
----- 06.1 Linked Servers Section -----------
PRINT CHAR(13) + CHAR(10) + '--##  Linked Servers'

SELECT 
    CONVERT(nvarchar(25), name) as 'Name'
, CONVERT(nvarchar(25), product) as 'Product'
, CONVERT(nvarchar(25), provider) as 'Provider'
, CONVERT(nvarchar(25),data_source) as 'Data Source'
FROM sys.servers
WHERE is_linked ='1'
order by name

----- 06.2 Linked Servers Logins Section ------
PRINT CHAR(13) + CHAR(10) + '--##  Linked Servers Logins'

SELECT s.server_id ,s.name 
    , CASE s.Server_id   WHEN 0 THEN 'Current Server'   ELSE 'Remote Server' END			AS 'Server'
    , s.data_source, s.product , s.provider  , s.catalog  
    , CASE sl.uses_self_credential   WHEN 1 THEN 'Uses Self Credentials' ELSE ssp.name END	AS 'Local Login'
    , sl.remote_name AS 'Remote Login Name'
    , CASE s.is_rpc_out_enabled WHEN 1 THEN 'True' ELSE 'False' END							AS 'RPC Out Enabled'
    , CASE s.is_data_access_enabled WHEN 1 THEN 'True' ELSE 'False' END						AS 'Data Access Enabled'
    , s.modify_date
FROM sys.Servers s
    LEFT JOIN sys.linked_logins sl ON s.server_id = sl.server_id
    LEFT JOIN sys.server_principals ssp ON ssp.principal_id = sl.local_principal_id
WHERE s.server_id <> 0
order by s.name
GO

--=================== 07. ETC =============================
----- 07.1 Logon Triggers Section -----------
PRINT CHAR(13) + CHAR(10) + '--##  SQL Server Logon Triggers'

SELECT SSM.definition
FROM sys.server_triggers AS ST
    JOIN sys.server_sql_modules AS SSM      ON ST.object_id = SSM.object_id

----- 07.2 Logon Triggers Section -----------
PRINT CHAR(13) + CHAR(10) + '--##  REPLICATION'

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' AND TABLE_NAME='sysextendedarticlesview') 
(
    SELECT  sub.srvname,  pub.name, art.name2, art.dest_table, art.dest_owner
    FROM sysextendedarticlesview art
        inner join syspublications pub on (art.pubid = pub.pubid)
        inner join syssubscriptions sub on (sub.artid = art.artid)
    )
ELSE
    SELECT  '' srvname,  '' name, '' name2, '' dest_table, '' dest_owner
    FROM SYS.objects
    WHERE 1 = 0
GO

----- 07.3 SQL Mail Section -----------
PRINT CHAR(13) + CHAR(10) + '--##  SQL Mail'

CREATE TABLE #Database_Mail_Details
(Status NVARCHAR(7))

IF EXISTS(SELECT * FROM master.sys.configurations WHERE configuration_id = 16386 AND value_in_use =1)
BEGIN
    INSERT INTO #Database_Mail_Details (Status)
    Exec msdb.dbo.sysmail_help_status_sp
END

SELECT [Status] AS 'Database Mail Service Status'
FROM #Database_Mail_Details;
GO

DROP TABLE #Database_Mail_Details;

----- 07.4 Report Server (SSRS) Section -----------
PRINT CHAR(13) + CHAR(10) + '--##  Report Server (SSRS)'

IF EXISTS (SELECT name FROM sys.databases where name = 'ReportServer')
BEGIN
    SELECT CONVERT(nvarchar(20),Rol.RoleName) AS 'Role Name'
        ,CONVERT(nvarchar(35),Us.UserName) AS 'User Name'
        ,CONVERT(nvarchar(35),Cat.[Name]) AS 'Report Name'
        ,CASE Cat.Type
            WHEN 1 THEN 'Folder'
            WHEN 2 THEN 'Report' 
            WHEN 3 THEN 'Resource'
            WHEN 4 THEN 'Linked Report' 
            WHEN 5 THEN 'Data Source' ELSE ''
        END AS 'Catalog Type'
        ,CONVERT(nvarchar(35),Cat.Description) AS'Description'
    FROM reportserver.dbo.Catalog Cat 
        JOIN reportserver.dbo.Policies Pol        ON Cat.PolicyID = Pol.PolicyID
        JOIN reportserver.dbo.PolicyUserRole PUR  ON Pol.PolicyID = PUR.PolicyID 
        JOIN reportserver.dbo.Users Us            ON PUR.UserID = Us.UserID 
        JOIN reportserver.dbo.Roles Rol           ON PUR.RoleID = Rol.RoleID
    WHERE Cat.Type in (1, 2)
    ORDER BY Cat.PATH 
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
GO

----- 07.5 Engine base folder & Port Section -----------
PRINT CHAR(13) + CHAR(10) + '--##  Engine base folder & Port Info'

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
    DECLARE @HkeyLocal nvarchar(18)
        , @Instance varchar(100)
        , @MSSqlServerRegPath nvarchar(200)
        , @TcpPort nvarchar(100)
        , @TcpDynamicPorts nvarchar(100)
        , @InstanceVersion  varchar(100)

    SET @InstanceVersion = 
        CASE CONVERT(char(4), SERVERPROPERTY('ProductVersion'))
            WHEN '9.00' THEN '9'
            WHEN '10.0' THEN '10'
            WHEN '10.5' THEN '10_50'
            WHEN '11.0' THEN '11'
            WHEN '12.0' THEN '12'
        END

    SET @Instance = 'MSSQL' + @InstanceVersion + '.' +  CONVERT(VARCHAR(50), ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER')) 

    --SET @Instance ='MSSQL10_50.SQLEXPRESS'
    SET @HkeyLocal=N'HKEY_LOCAL_MACHINE'
    SET @MSSqlServerRegPath=N'SOFTWARE\Microsoft\\Microsoft SQL Server\'
        + @Instance + '\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
    
    --Print @MSSqlServerRegPath
    EXEC xp_instance_regread @HkeyLocal    , @MSSqlServerRegPath    , N'TcpPort'    , @TcpPort OUTPUT
    EXEC xp_instance_regread @HkeyLocal    , @MSSqlServerRegPath    , N'TcpDynamicPorts'    , @TcpDynamicPorts OUTPUT

    SELECT @HkeyLocal + '\' + @MSSqlServerRegPath registry_key, 'TcpPort' value_name, isnull(@TcpPort, '') as value_data
    union all
    SELECT @HkeyLocal + '\' + @MSSqlServerRegPath registry_key, 'TcpDynamicPorts' , isnull(@TcpDynamicPorts, '') as value_data 
END
GO

----- 07.6 Fulltext Section ---------------
PRINT CHAR(13) + CHAR(10) + '--##  Fulltext'

SELECT * FROM sys.fulltext_indexes;
GO

----- 07.7 Fulltext Section ---------------
PRINT CHAR(13) + CHAR(10) + '--##  List all endpoints'

SELECT * FROM sys.endpoints
GO
