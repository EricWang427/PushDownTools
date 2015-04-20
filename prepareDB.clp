
--create db FEDDB;

--create db DSDB;

--SET DBM CFG USING FEDERATED YES;

--connect to FEDDB;
--update db cfg using string_units codeunits32;
--connect reset;

CONNECT TO FEDDB;

DROP WRAPPER DRDA;
CREATE WRAPPER DRDA;

DROP SERVER PDSERVER;
CREATE SERVER PDSERVER TYPE DB2/UDB VERSION 10.5 WRAPPER DRDA AUTHORIZATION "iifvt66" PASSWORD "passw0rd" OPTIONS (DBNAME 'DSDB');

CREATE USER MAPPING FOR iifvt66 SERVER PDSERVER OPTIONS (REMOTE_AUTHID 'iifvt66', REMOTE_PASSWORD 'passw0rd');

SET PASSTHRU PDSERVER;

DROP TABLE T1;

CREATE TABLE T1
(
--	BOL     BOOLEAN                         ,
	SMI     SMALLINT                        ,
	ITG     INTEGER                         ,
	BGI     BIGINT                          ,
	
	DCM     DECIMAL(16, 10)                 ,
	
	REL     REAL                            ,
	DOB     DOUBLE                          ,
	DCF     DECFLOAT                        ,
	
	CHA     CHAR(63)                        ,
	VCH     VARCHAR(128)                    ,
--	LVC     LONG VARCHAR(128)               ,
	
	GPH     GRAPHIC(63)                     ,
	VGP     VARGRAPHIC(256)                 ,
--	LVG     LONG VARGRAPHIC(256)            ,
	
--	CLO     CLOB(1M)                        ,
--	DBC     DBCLOB(2M)                      ,
	
--	BLO     BLOB(4M)                        ,
	
	DAT     DATE                            ,
	TME     TIME                            ,
	TMP     TIMESTAMP                       ,
	
	
	
	
	DCM_DATETIME     DECIMAL(26, 12)        ,
	CHA_DATETIME     CHAR(63)               ,
	VCH_DATETIME     VARCHAR(128)           ,
	GPH_DATETIME     GRAPHIC(63)            ,
	VGP_DATETIME     VARGRAPHIC(256)        ,
	
	CHA_NUMBER       CHAR(63)               ,
	VCH_NUMBER       VARCHAR(128)           ,
	GPH_NUMBER       GRAPHIC(63)            ,
	
	SMI_SMALL        SMALLINT               ,
	ITG_SMALL        INTEGER                ,
	BGI_SMALL        BIGINT                 ,
	DCM_SMALL        DECIMAL(16, 10)        ,
	REL_SMALL        REAL                   ,
	
	ITG_DATE         INTEGER                ,
	BGI_DATE         BIGINT                 ,
	DOB_DATE         DOUBLE                 ,
	DCF_DATE         DECFLOAT               ,
	
	CHA_ONECHAR      CHAR(1)                ,
	VCH_ONECHAR      VARCHAR(128)           ,
	GPH_ONECHAR      GRAPHIC(1)             ,
	VGP_ONECHAR      VARGRAPHIC(256)
);

INSERT INTO T1 VALUES (
--	0,
	1,
	60221367,
	299792458000,
	
	3.141592654,
	
	2.71828,
	6.67259E-11,
	1.60217733E-19,
	
	'CAHR FOR TEST',
	'VARCHAR FOR TEST',
--	'LONG VARCHAR FOR TEST',
	
	'GRAPHIC FOR TEST',
	'VARGRAPHIC FOR TEST',
--	'LONG VARGRAPHIC FOR TEST',
	
--	CLOB('CLOB FOR TEST'),
--	DBCLOB('DBCLOB FOR TEST'),
	
--	BLOB('BLOB FOR TEST'),
	
	'1989-10-09',
	'18:45:00',
	'1989-10-09 07:00:00',
	
	
	
	
	19891009070530.000000,
	'1989-10-09 07:05:30',
	'1989-10-09 07:05:30',
	'1989-10-09 07:05:30',
	'1989-10-09 07:05:30',
	
	'2',
	'4',
	'8',
	
	1,
	1,
	1,
	1,
	1,
	
	726384,
	726384,
	726384,
	726384,
	
	'r',
	'u',
	'x',
	'7'
);

SET PASSTHRU RESET;

DROP NICKNAME N1;
CREATE NICKNAME N1 FOR PDSERVER.iifvt66.T1;

TERMINATE;
