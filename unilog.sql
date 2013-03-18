/******************************************************************************
   NAME:      unilog - Universal Logging Tool
   AUTHOR:    U. Küchler
   LICENSE:   http://opensource.org/licenses/MIT

   PURPOSE:   
   Log error info and/or custom messages to standard output and/or table.
   Messages can be filtered by severity level, get logged with a timestamp and
   additional session info can be gathered (user name, user's host, ...)
 ******************************************************************************/
CREATE TABLE UNILOG_MSGS
(
  DATETIME   TIMESTAMP(6)                       DEFAULT CURRENT_TIMESTAMP,
  MODULE     VARCHAR2(80 BYTE),
  OERR       NUMBER(5),
  MESSAGE    VARCHAR2(4000 BYTE)                NOT NULL,
  ERR_LEVEL  NUMBER(3)                          DEFAULT 0
)
TABLESPACE TOOLS
PCTFREE 0
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/
-- You may want to define a public synonym and grants on the table.

CREATE OR REPLACE PACKAGE unilog
AS
/******************************************************************************
   NAME:      unilog - Universal Logging Tool
   AUTHOR:    U. Küchler
   LICENSE:   http://opensource.org/licenses/MIT

   PURPOSE:   
   Log error info and/or custom messages to standard output and/or table.
   Messages can be filtered by severity level, get logged with a timestamp and
   additional session info can be gathered (user name, user's host, ...)
   EXAMPLE:
   unilog.put( p_msg => 'WHEN OTHERS'
             , p_options => unilog.LOG_STACK + unilog.LOG_BACKTRACE )

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        25.01.2007  U. Küchler       1. Created this package.
   1.1        09.02.2007  U. Küchler       Verbosity Filter, Interactive Mode
   1.2        10.12.2008  U. Küchler       Backtrace (req. Oracle >= 10g)
   1.3        16.10.2009  U. Küchler       Major rewrite: Log more detail
 ******************************************************************************/

  -- Messages with error_level >= VERBOSITY get logged
  VERBOSITY INTEGER := 0;

  -- Log messages to table (default yes)
  LOG_TO_TABLE BOOLEAN := TRUE;

  -- Log messages to screen (default no)
  INTERACTIVE BOOLEAN := FALSE;
  
  -- Options
  LOG_OPTIONS   PLS_INTEGER := 0; -- used as default; can be changed at session level
  LOG_LINENO    CONSTANT PLS_INTEGER := 1;  -- first line of backtrace
  LOG_STACK     CONSTANT PLS_INTEGER := 2;  -- errorstack (number and message)
  LOG_BACKTRACE CONSTANT PLS_INTEGER := 4;  -- complete stack trace w/o error message
  LOG_USER      CONSTANT PLS_INTEGER := 8;  -- oracle user 
  LOG_HOST      CONSTANT PLS_INTEGER := 16; -- machine where user connected from
  LOG_OSUSER    CONSTANT PLS_INTEGER := 32; -- OS user of the connecting app
  LOG_ALL       CONSTANT PLS_INTEGER := 2147483646; -- log all details

  -- Standard procedure, called by all other "put_*"
  PROCEDURE put(
    p_msg     IN VARCHAR2                  -- message to log
  , p_module  IN VARCHAR2 DEFAULT NULL     -- optional program identifier
  , p_oerr    IN NUMBER DEFAULT NULL       -- Oracle error code
  , p_level   IN NUMBER DEFAULT 0          -- error level (verbosity)
  , p_options IN PLS_INTEGER DEFAULT LOG_OPTIONS -- binary coded options
  );

  -- Log entry with first line of error stack
  PROCEDURE put_with_errln(
    p_msg     IN VARCHAR2              -- Message to log
  , p_module  IN VARCHAR2 DEFAULT NULL -- optional program identifier
  , p_oerr    IN NUMBER DEFAULT NULL   -- Oracle error code
  , p_level   IN NUMBER DEFAULT 0      -- error level (verbosity)
  );

  -- Log entry with full error stack
  PROCEDURE put_with_trace(
    p_msg     IN VARCHAR2              -- Message to log
  , p_module  IN VARCHAR2 DEFAULT NULL -- optional program identifier
  , p_oerr    IN NUMBER DEFAULT NULL   -- Oracle error code
  , p_level   IN NUMBER DEFAULT 0      -- error level (verbosity)
  );

  -- Returns the first line of the error stack
  FUNCTION get_errln
  RETURN VARCHAR2;

END unilog;
/

CREATE OR REPLACE PACKAGE BODY unilog AS
/******************************************************************************
   NAME:       unilog
   PURPOSE:    Universal Logging Tool
   AUTHOR:     U. Küchler
   LICENSE:    http://opensource.org/licenses/MIT

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        25.01.2007  U. Küchler       1. Created this package.
   1.1        09.02.2007  U. Küchler       Verbosity Filter, Interactive Mode
   1.2        10.12.2008  U. Küchler       Backtrace (req. Oracle >= 10g)
   1.3        16.10.2009  U. Küchler       Major rewrite: Log more detail
******************************************************************************/

  -- Fill the message with optional information
  PROCEDURE msg_compose(
    p_msg      IN OUT NOCOPY VARCHAR2             -- message to log
  , p_options  IN PLS_INTEGER DEFAULT LOG_OPTIONS -- binary coded options
  )
  AS
  BEGIN
    IF BITAND( p_options, LOG_USER ) > 0 THEN
      p_msg := p_msg || CHR(10) ||'DB User: '||SYS_CONTEXT( 'USERENV', 'SESSION_USER' );
    END IF;
    IF BITAND( p_options, LOG_OSUSER ) > 0 THEN
      p_msg := p_msg || CHR(10) ||'OS User: '||SYS_CONTEXT( 'USERENV', 'OS_USER' );
    END IF;
    IF BITAND( p_options, LOG_HOST ) > 0 THEN
      p_msg := p_msg || CHR(10) ||'Machine: '||SYS_CONTEXT( 'USERENV', 'HOST' );
    END IF;
    IF BITAND( p_options, LOG_LINENO ) > 0 THEN
      p_msg := p_msg || CHR(10) || get_errln;
    END IF;
    IF BITAND( p_options, LOG_STACK ) > 0 THEN
      p_msg := p_msg || CHR(10) || RTRIM( DBMS_UTILITY.format_error_stack, CHR(10));
    END IF;
    IF BITAND( p_options, LOG_BACKTRACE ) > 0 THEN
      p_msg := p_msg || CHR(10) || DBMS_UTILITY.format_error_backtrace;
    END IF;
  END msg_compose;

  -- Standard procedure, called by all other "put_*"
  PROCEDURE put(
    p_msg      IN   VARCHAR2                    -- message to log
  , p_module   IN   VARCHAR2 DEFAULT NULL       -- optional program identifier
  , p_oerr     IN   NUMBER DEFAULT NULL         -- Oracle error code
  , p_level    IN   NUMBER DEFAULT 0            -- error level (verbosity)
  , p_options  IN   PLS_INTEGER DEFAULT LOG_OPTIONS -- binary coded options
  )
  AS
    PRAGMA autonomous_transaction;
    l_msg VARCHAR2(32767) := p_msg;
  BEGIN
    IF p_level >= VERBOSITY THEN
      msg_compose( l_msg, p_options );
      IF LOG_TO_TABLE THEN
        INSERT INTO unilog_msgs ( datetime, module, oerr, message, err_level )
             VALUES ( current_timestamp, p_module, p_oerr
                    , SUBSTR( l_msg, 1, 4000 ), p_level );
        COMMIT;
      END IF;
      IF INTERACTIVE THEN
        dbms_output.put_line( current_timestamp ||', '|| p_module ||': '|| l_msg );
      END IF;
    END IF;
  END put;

  -- Returns the first line of the error stack
  FUNCTION get_errln
  RETURN VARCHAR2
  AS
    v_trace VARCHAR2(4000) := DBMS_UTILITY.format_error_backtrace;
  BEGIN
    RETURN SUBSTR( v_trace, 1, INSTR( v_trace, CHR(10))-1 );
  END get_errln;

  -- Log entry with first line of error stack
  PROCEDURE put_with_errln(
    p_msg      IN   VARCHAR2
  , p_module   IN   VARCHAR2 DEFAULT NULL
  , p_oerr     IN   NUMBER DEFAULT NULL
  , p_level    IN   NUMBER DEFAULT 0
  )
  AS
  BEGIN
    put( p_msg, p_module, p_oerr, p_level, LOG_LINENO );
  END put_with_errln;

  -- Log entry with full error stack
  PROCEDURE put_with_trace(
    p_msg      IN   VARCHAR2
  , p_module   IN   VARCHAR2 DEFAULT NULL
  , p_oerr     IN   NUMBER DEFAULT NULL
  , p_level    IN   NUMBER DEFAULT 0
  )
  AS
  BEGIN
    put( p_msg, p_module, p_oerr, p_level, LOG_STACK + LOG_BACKTRACE );
  END put_with_trace;

END unilog;
/
