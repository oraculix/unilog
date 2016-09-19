======
UNILOG
======

UNIversal LOGging Package for Oracle PL/SQL. Straightforward, easy to install and easy to use.

There are other full-featured (but sometimes complex or even sluggish) logging tools for PL/SQL around. The main focus of UNILOG lies in its simplicity.

UNILOG was started for educational purposes, but soon became implemented in enterprise applications, running in production for years now. This is why the original author decided it might be useful to others and should be made available to a wider audience as Open Source.

UNILOG is free and Open Source and distributed under the terms of the X/MIT license (http://opensource.org/licenses/MIT); for licensing details see the file LICENSE.

# Quick Start
1. Change Line No. 19 in `unilog.sql` to put the logging table in your preferred tablespace (default is "TOOLS").
2. Run  `unilog.sql` against your application's schema (you might consider a separate logging schema but let's keep it simple here).
3. Start logging from your PL/SQL application, e.g.
```sql
unilog.put('Test message'); 
```
4. Check the contents of the logging table:
```sql
select * from UNILOG_MSGS; 
```
Voilá! You're up and logging.
