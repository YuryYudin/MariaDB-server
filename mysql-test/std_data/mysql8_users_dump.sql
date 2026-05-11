/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19-11.4.11-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: 
-- ------------------------------------------------------
-- Server version	8.4.8

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;
CREATE USER ``@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$X]\Z7R?9CLn8JEQOCjlgmktLwODVWHPalbDzfD2EJWC3Pw0UuglRtGRkEpt7B' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `O'Brien`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$@o@(^\\UaKn*j(Dh>>?UEk96KsKIOlQNw3DaQIFxkpox7HIW7ALdlVjFNJLbWj6' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_admin_chain_root`@`%` IDENTIFIED WITH 'caching_sha2_password' REQUIRE NONE PASSWORD EXPIRE ACCOUNT LOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_all_privs`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$a>kRT#\r8>0=SUU9IcBr7P8DpNoLFr5.KUDYh9JRj.hEtnuyvNAqn02kMgV8A3' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_auth_caching_sha2`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$IDohN8PE*~\\[M-T}ju0z9omDoT1II0lzQAbh2lDpQw5Jm.ISpddSIvol5P5' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_auth_no_pwd`@`%` IDENTIFIED WITH 'caching_sha2_password' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_auth_sha256`@`%` /*!80001 IDENTIFIED WITH 'sha256_password' AS '$5$ \r.yhMP;\"uR|]n0$sZIKUYpJ10/tzbge5yhy66ONfy8QL63a.cagaoI0dWC' */ REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# WARNING: auth plugin 'sha256_password' not shipped with MariaDB; user created with no password - set a new password before login
CREATE USER `m8_col_priv`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$1Y:+!S|;&\'%9lPFnU+7\'ES7TDLwSqxrBd7ebWjbRcmCjP68dNEQCMDgk9eV0l8.' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_combined`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$rj}X40vh~:\'_,vXMMtd7M/rIETxjcfNgjq9OLsM9CxRzKsxesH3ODQmsD' /*!80001 DEFAULT ROLE `m8_default_a`@`%` */ REQUIRE SSL WITH MAX_USER_CONNECTIONS 5 PASSWORD EXPIRE DEFAULT ACCOUNT LOCK /*!80001 PASSWORD HISTORY 3 */ /*!80001 PASSWORD REUSE INTERVAL 90 DAY */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_db_underscore`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$Z\Z;=/\Z\'0Jfy.\'okBrZy7AxvU.epNXK82Nc1x.NtQl1qPsgZXnw3qaSjBKC' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_default_role_many`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$5-35<J\"]]F\nFd<yoQ.yMRAjXr9NxQzcZ.3AqdH4WYOlXa39KVclr8KRS7' /*!80001 DEFAULT ROLE `m8_default_a`@`%`,`m8_default_b`@`%` */ REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_default_role_one`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$Uu^gg10,WM]7%]KBdahc4PSj6uiotocaRG2eyeCyZ8pxoZMgCC8kWuPB.' /*!80001 DEFAULT ROLE `m8_default_a`@`%` */ REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_dumper`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$~T]]7E\"m0l6(Q]Co8jN6c9SsI8ZSwVG/SSupBFKebipNS0Sky4QTh4iJy/' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_dyn_all_dropped`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$\n7*d{heu~y=R\"|DGgO1tBM/MA6MAVIIAP4a2ojz/L4L.3d1j2.MPVlrYYQ08' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_dyn_flush_collapse`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$%4EaW0{Y9Sf\Z\"W\'&CquE32/v5AFdWgZ3PyRdbUzEBfTyfFkPCG3s72h.o2B' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_dyn_grant_opt`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$u;;I;.b5tkPJl]w\n0LM7oLDQc6OmpXsJdDR.nlt4dfHJgBvl5fd0rybADp2' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_dyn_mapped`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$<]Wz}[n^X s^i[?2nAM7VTwOTX4QGqBH7TsKeuyFkKPAjl7fXiDJpgZNYkmB' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_dyn_mixed`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$Choa_qi\\/%itYfGw3u57jawxTXHNnbixLlZCuGUO2kr0BsLKjg.3zCL4g1' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_dyn_unmapped`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$W%#Lxy1D,wsQItXth1Q.UUVbHjzsija7tF13p.oIEGysIfn89.7I.Np1T7' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_edge_at_in_name`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$Qd9`2\"OH#^oo#\\/(0V2BZ7DGLcJNEfck9WR3V6im8WXqZlSqb5dSZBglPK.DC' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_edge_space`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$	L*/h^Qe^5:Kj~dL.qobZnxObiufhhp5O3iXpkK7aBVd1YyDNHjU1ps8D' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_failed_login`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$FJ\nF\'Mn?tM\njgZ9NJe.DUrL1BM6Et2oP47ntHiyw9F52yaU16ysghsw5jc6' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1 */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_func_exec`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$%<Fn\\p0Y(?wNP4(ELCLStamsyOYBUgl1nhTkOGjzrj6WbRs83Hw6efEDj0' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_host_dual`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$\\R-.qg11#<{x\\k7UCK5XBj5eqPTC6Au8HITPs9c8G/p4kX9XQri4Q8Q9' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_lock`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$S)t#WXn]k\ZQ_Q%u TrACpg0I1F/kZiCPv3M4UH9NJYEKShj7qGcXKWTZzI6' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT LOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_max_conn`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$0+DRj5MujzMQD=n0Th0VauLBJEwksYwCz8yMdI4iyK.A.h/g8dG7Cz5c5' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 1000 MAX_USER_CONNECTIONS 10 PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_multiscope`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$n4M\\Ym	#\r9G=2YRUsMoBsWq/b.j3jXgSSRmlCxYE08jNzR49AeibXY2' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_partial_revoke`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$V|x?x.5_G_(\\dxRfGAnaiiBEYXYAtWp4Cmvxrz/v6AQMVZiL7O33kLR/' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_proc_exec`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$\\\"8R{+jm~_S\"q}*A8yXayaBjU6zLUZK6ocksO2wgaYDqMrJ/HdWOg1YhaYq1' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_proxy_target`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$F8<HeR~T`M#d>lH)3kWoX14TD3uo3HcPjKCcKDGH3i2scssZMpkTKUWrw.RTD' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_proxy_user`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$W(b5G,Z36g|deWh&*T9Ns7ySFCjJaWDGqcILLtZCK4i132LiVbz51r3ogp8L1' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_pwd_expire_default`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$Df?dxBfx*5=5jJY3uSGTXdubTDcqHujTvEtxZEeYh0TbzU62DvwNsYec/' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_pwd_expire_interval`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$2%%>Q!J2S[)@<Di\n2rQrxHquH/aRWCvaR8/6EB99Af1/6eL2aFl.fEvJ9ND' REQUIRE NONE PASSWORD EXPIRE INTERVAL 90 DAY ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_pwd_expire_never`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$/|RKj7S`As8[[7=2f0o7.Ib3gAjuw0ZcJbeyIv7owbrDo2yfWbMbeUC7lJ1' REQUIRE NONE PASSWORD EXPIRE NEVER ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_pwd_expire_now`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$R2h8rZN8v_@Lq\n61RLhvVSJstzIoYtlsAVCLCdLGuA0pgJDYcq.oMlYZ48' REQUIRE NONE PASSWORD EXPIRE ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_pwd_history`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$fmlN%|R?Zmm[LvIU\"B2RGw.tAbypdBBwSXz2FqZSY39poSaRwgkvrlV6.QX4' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY 5 */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_pwd_require_current`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$\\q&\"zec%`NOBMw^m0L r9r/nYbJLhMslWvRf0KWOPWN6oGxqO8ZmY3JpsSzoQ0' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT PASSWORD */ REQUIRE CURRENT;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_pwd_reuse`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$z9N91\Z]?^w4;*%(:MCoYtRu6mUiWtLrFWzgspvzcgf41tQgSiKvMrrPPqwEhDD' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL 365 DAY */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_require_cipher`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$7!`C>.,7@y.KzUKZd8zxARe4rKf6uWm.I1TUpWrbTLfQctcX22sWfvrqURA' REQUIRE CIPHER 'ECDHE-RSA-AES128-GCM-SHA256' PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_require_ssl`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$?~eK<i|\rIwV9wtS6spmzejFGBaCq4Ogjl/TOWYd2yKCdRvQD7l9kf281' REQUIRE SSL PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_require_x509`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$c.F!rcu\'	}EF>VVgujw4nKVbNRau./xcAmtKiECeWmBwrYKp3YfIaRmy/SVD' REQUIRE X509 PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_resource_full`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005${H4eF7w]5=yu }Z xAXJCaoEFZXoJmyYxXyvJCgSaxtATrLYOiipYd1GHv/' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 5000 MAX_UPDATES_PER_HOUR 500 MAX_CONNECTIONS_PER_HOUR 100 MAX_USER_CONNECTIONS 25 PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_role*/starslash`@`%` IDENTIFIED WITH 'caching_sha2_password' REQUIRE NONE PASSWORD EXPIRE ACCOUNT LOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_role_static`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$Z(wY+-2&u\nL-GD\r7lLxIeJHHmBYovWDyc10oWq4iATAx7jHYmTH2KnHbwz7' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_routine_admin`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$Q\'&(_c,Gk6!(GMGtk1ZYwTuk2he0lLVv23VnwJORkltRU5pcrCLi4Pf9' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_shared_user_1`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$?/%=	8scEK@CSTfYv6qrwyyUI5IrVUl9LGDORRJce6RFGYZzg3Q311A' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_shared_user_2`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$Z77\Z9P`%F3tSsJGrdBfNvdMLfpHlWYEs4Ssg/6O34cI1KQ1UEua50uQQeD' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_shared_user_3`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$(0~1Anj\n/.o2*UPUGUkeNJ2mbW/6dNY8bxSMoMoq5rmQ0yPlP0PbHwz/6L4' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_shared_user_4`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$~nK\Zq3tt/%Y|\'QddO\ZBw4XvCGw4uJQxRNWhO5mJ.BSXdjaMyfMlANYMN5Gah9' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_shared_user_5`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$\"%;Y=.9+	VD^n>w\'z9tQQxeKjXc1OKfr3jP11/4..m6dxyS7yqxSkPDRQiA' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_simple`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$wG*hah],Ed|g+hIx1ucDOeI2q/9fItlBgIr/6b2G8az4u3unkvgNg.8hca6bC' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_starslash_comment`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$WX;|(3hH6=857h1xH0i7WPLaU7xAMFVT421in/NC/uVEBbwEp6iTSc1' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT ATTRIBUTE '{"comment": "has *' '/ in body"}' */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_starslash_escaped`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$33E/WDs)EfhFhQNiF12XY5L2WH7JtGl6pHhOiaooLWhgSGKkLOmdtan7' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT ATTRIBUTE '{"comment": "has \\\\*' '/ escaped"}' */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_static_dyn_mix`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$1o@X.Qp#oz=tVygwpHqpkdqaPpd0IM4NQgWqZp.MdrCCRn8xhuKvKC2Rf7' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_static_priv`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$Ah1gq!(oIj>[%Q\rB9tMcK7w6WrOrV6RZurfVvhwWI7EyG3u0GW/NvO7gw1' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_static_role_mix`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$~\"Cl,iGgf5m:Ozh0]\\QIMTMTa1FW/llWJ.xm.uqTag8ZJ55r4ZwKFaxAJIcl1' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_system_grants`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$smJVXG#6S^%|P`nlozciZoQUUiFGlug1qgMpld5AQJjClph/2VkoH1G09' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_unlock`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$jevI4\r+J\ro/emUI=kPMxf2JI0i8AySFjNAq834KEi9KNP1isRvIXHr/6Kfy1' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_usage_only`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$y	Cbtvs1x|9{7gUYv7YktVbioYHFiC3MxwXBcsOgElq4Xs9Z6.Wc6zYEMA' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_with_attribute`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$,)`6=OC)lNzy%J/2t0Ga47BBy0ANrxas2DFGOZMxf7U75WlKaX6lgVyof/' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT ATTRIBUTE '{"team": "db_migration", "contact": "alice@example.com"}' */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_with_comment`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$;	&=\".&.F\np+16hE3oulyliNeUEkkg0XPC7upp1R9zH/FjXCxc7WDTHu1' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT ATTRIBUTE '{"comment": "Migration test user with embedded \'quote\' character"}' */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_用户`@`%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$|sVC\r/! 5;>&zpdv9isqUYMUmAWvlX4tQNlU9YO3vRbrnUPnwTJ/sO5dmA' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_edge_wildcard_host`@`192.168.%.%` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$\"/X3]d%C9h6`1H0:\r3kWyr1JWLJ09/eUNLpHNrn.a9LyD5.rnU5J2QO1De.A' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER ``@`localhost` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$K&TPc-)\'\\(aq=T+vPCdCRsa/aMDq4Mp9wNdHMAZpCZteBkHZd4PyYtlIdc/t1' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_host_dual`@`localhost` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$\rRJu)T[,]%\\Ex]u C!RKCXq4Ld7AVaFCjIjSp2o3/lQFtJ6AOmMDPqYkqpyA4' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `m8_host_localhost`@`localhost` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$.GuUr~C..2Q5Awqb2MCVmKDJMMqV.stPXQjTHfSSeDaYZ08f97xN9HmqSW6A' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `mysql.infoschema`@`localhost` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$THISISACOMBINATIONOFINVALIDSALTANDPASSWORDTHATMUSTNEVERBRBEUSED' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT LOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `mysql.session`@`localhost` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$THISISACOMBINATIONOFINVALIDSALTANDPASSWORDTHATMUSTNEVERBRBEUSED' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT LOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `mysql.sys`@`localhost` IDENTIFIED WITH 'caching_sha2_password' AS '$A$005$THISISACOMBINATIONOFINVALIDSALTANDPASSWORDTHATMUSTNEVERBRBEUSED' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT LOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
CREATE USER `root`@`localhost` IDENTIFIED WITH 'caching_sha2_password' REQUIRE NONE PASSWORD EXPIRE DEFAULT ACCOUNT UNLOCK /*!80001 PASSWORD HISTORY DEFAULT */ /*!80001 PASSWORD REUSE INTERVAL DEFAULT */ /*!80001 PASSWORD REQUIRE CURRENT DEFAULT */;
# NOTE: auth plugin 'caching_sha2_password' needs to be loaded on the target MariaDB before login: INSTALL SONAME 'auth_mysql_sha2'
SELECT COALESCE(CURRENT_ROLE(),'NONE') into @current_role;
CREATE ROLE IF NOT EXISTS mariadb_dump_import_role;
GRANT mariadb_dump_import_role TO CURRENT_USER();
SET ROLE mariadb_dump_import_role;
/*M!100005 CREATE ROLE 'm8_default_a' */;
/*M!100005 GRANT 'm8_default_a' TO mariadb_dump_import_role WITH ADMIN OPTION */;
/*!80001 CREATE ROLE 'm8_default_a'@'%' */;
/*!80001 GRANT 'm8_default_a'@'%' TO `mariadb_dump_import_role`@`%` WITH ADMIN OPTION */;
/*M!100005 GRANT 'm8_default_a' TO 'm8_combined'@'%' */;
/*!80001 GRANT 'm8_default_a'@'%' TO 'm8_combined'@'%' */;
/*M!100005 GRANT 'm8_default_a' TO 'm8_default_role_many'@'%' */;
/*!80001 GRANT 'm8_default_a'@'%' TO 'm8_default_role_many'@'%' */;
/*M!100005 GRANT 'm8_default_a' TO 'm8_default_role_one'@'%' */;
/*!80001 GRANT 'm8_default_a'@'%' TO 'm8_default_role_one'@'%' */;
/*M!100005 GRANT 'm8_default_a' TO 'm8_shared_user_1'@'%' */;
/*!80001 GRANT 'm8_default_a'@'%' TO 'm8_shared_user_1'@'%' */;
/*M!100005 GRANT 'm8_default_a' TO 'm8_shared_user_2'@'%' */;
/*!80001 GRANT 'm8_default_a'@'%' TO 'm8_shared_user_2'@'%' */;
/*M!100005 CREATE ROLE 'm8_default_b' */;
/*M!100005 GRANT 'm8_default_b' TO mariadb_dump_import_role WITH ADMIN OPTION */;
/*!80001 CREATE ROLE 'm8_default_b'@'%' */;
/*!80001 GRANT 'm8_default_b'@'%' TO `mariadb_dump_import_role`@`%` WITH ADMIN OPTION */;
/*M!100005 GRANT 'm8_default_b' TO 'm8_default_role_many'@'%' */;
/*!80001 GRANT 'm8_default_b'@'%' TO 'm8_default_role_many'@'%' */;
/*M!100005 CREATE ROLE 'm8_role_a' */;
/*M!100005 GRANT 'm8_role_a' TO mariadb_dump_import_role WITH ADMIN OPTION */;
/*!80001 CREATE ROLE 'm8_role_a'@'%' */;
/*!80001 GRANT 'm8_role_a'@'%' TO `mariadb_dump_import_role`@`%` WITH ADMIN OPTION */;
/*M!100005 GRANT 'm8_role_a' TO 'm8_admin_chain_root'@'%' WITH ADMIN OPTION */;
/*!80001 GRANT 'm8_role_a'@'%' TO 'm8_admin_chain_root'@'%' WITH ADMIN OPTION */;
/*M!100005 GRANT 'm8_role_a' TO 'm8_simple'@'%' WITH ADMIN OPTION */;
/*!80001 GRANT 'm8_role_a'@'%' TO 'm8_simple'@'%' WITH ADMIN OPTION */;
/*M!100005 CREATE ROLE 'm8_role_d' */;
/*M!100005 GRANT 'm8_role_d' TO mariadb_dump_import_role WITH ADMIN OPTION */;
/*!80001 CREATE ROLE 'm8_role_d'@'%' */;
/*!80001 GRANT 'm8_role_d'@'%' TO `mariadb_dump_import_role`@`%` WITH ADMIN OPTION */;
/*M!100005 GRANT 'm8_role_d' TO 'm8_simple'@'%' */;
/*!80001 GRANT 'm8_role_d'@'%' TO 'm8_simple'@'%' */;
/*M!100005 CREATE ROLE 'm8_shared_role' */;
/*M!100005 GRANT 'm8_shared_role' TO mariadb_dump_import_role WITH ADMIN OPTION */;
/*!80001 CREATE ROLE 'm8_shared_role'@'%' */;
/*!80001 GRANT 'm8_shared_role'@'%' TO `mariadb_dump_import_role`@`%` WITH ADMIN OPTION */;
/*M!100005 GRANT 'm8_shared_role' TO 'm8_shared_user_1'@'%' */;
/*!80001 GRANT 'm8_shared_role'@'%' TO 'm8_shared_user_1'@'%' */;
/*M!100005 GRANT 'm8_shared_role' TO 'm8_shared_user_2'@'%' WITH ADMIN OPTION */;
/*!80001 GRANT 'm8_shared_role'@'%' TO 'm8_shared_user_2'@'%' WITH ADMIN OPTION */;
/*M!100005 GRANT 'm8_shared_role' TO 'm8_shared_user_3'@'%' */;
/*!80001 GRANT 'm8_shared_role'@'%' TO 'm8_shared_user_3'@'%' */;
/*M!100005 GRANT 'm8_shared_role' TO 'm8_shared_user_4'@'%' */;
/*!80001 GRANT 'm8_shared_role'@'%' TO 'm8_shared_user_4'@'%' */;
/*M!100005 GRANT 'm8_shared_role' TO 'm8_shared_user_5'@'%' WITH ADMIN OPTION */;
/*!80001 GRANT 'm8_shared_role'@'%' TO 'm8_shared_user_5'@'%' WITH ADMIN OPTION */;
/*M!100005 CREATE ROLE 'm8_role_b' */;
/*M!100005 GRANT 'm8_role_b' TO mariadb_dump_import_role WITH ADMIN OPTION */;
/*!80001 CREATE ROLE 'm8_role_b'@'%' */;
/*!80001 GRANT 'm8_role_b'@'%' TO `mariadb_dump_import_role`@`%` WITH ADMIN OPTION */;
/*M!100005 GRANT 'm8_role_b' TO 'm8_role_a' WITH ADMIN OPTION */;
/*!80001 GRANT 'm8_role_b'@'%' TO 'm8_role_a'@'%' WITH ADMIN OPTION */;
/*M!100005 CREATE ROLE 'm8_role_c' */;
/*M!100005 GRANT 'm8_role_c' TO mariadb_dump_import_role WITH ADMIN OPTION */;
/*!80001 CREATE ROLE 'm8_role_c'@'%' */;
/*!80001 GRANT 'm8_role_c'@'%' TO `mariadb_dump_import_role`@`%` WITH ADMIN OPTION */;
/*M!100005 GRANT 'm8_role_c' TO 'm8_role_b' WITH ADMIN OPTION */;
/*!80001 GRANT 'm8_role_c'@'%' TO 'm8_role_b'@'%' WITH ADMIN OPTION */;
GRANT USAGE ON *.* TO ``@`%`;
GRANT USAGE ON *.* TO `O'Brien`@`%`;
GRANT SELECT ON `m8_db`.* TO `O'Brien`@`%`;
GRANT USAGE ON *.* TO `m8_admin_chain_root`@`%`;
/*!80001 GRANT `m8_role_a`@`%` TO `m8_admin_chain_root`@`%` WITH ADMIN OPTION */;
/*!80001 GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, SUPER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER, CREATE TABLESPACE, CREATE ROLE, DROP ROLE ON *.* TO `m8_all_privs`@`%` WITH GRANT OPTION */;
# WARNING: dropped MySQL privilege CREATE ROLE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege DROP ROLE (no MariaDB equivalent)
/*M!100005 GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, SUPER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER, CREATE TABLESPACE ON *.* TO `m8_all_privs`@`%` WITH GRANT OPTION */;
/*!80001 GRANT ALLOW_NONEXISTENT_DEFINER,APPLICATION_PASSWORD_ADMIN,AUDIT_ABORT_EXEMPT,AUDIT_ADMIN,AUTHENTICATION_POLICY_ADMIN,BACKUP_ADMIN,BINLOG_ADMIN,BINLOG_ENCRYPTION_ADMIN,CLONE_ADMIN,CONNECTION_ADMIN,ENCRYPTION_KEY_ADMIN,FIREWALL_EXEMPT,FLUSH_OPTIMIZER_COSTS,FLUSH_PRIVILEGES,FLUSH_STATUS,FLUSH_TABLES,FLUSH_USER_RESOURCES,GROUP_REPLICATION_ADMIN,GROUP_REPLICATION_STREAM,INNODB_REDO_LOG_ARCHIVE,INNODB_REDO_LOG_ENABLE,OPTIMIZE_LOCAL_TABLE,PASSWORDLESS_USER_ADMIN,PERSIST_RO_VARIABLES_ADMIN,REPLICATION_APPLIER,REPLICATION_SLAVE_ADMIN,RESOURCE_GROUP_ADMIN,RESOURCE_GROUP_USER,ROLE_ADMIN,SENSITIVE_VARIABLES_OBSERVER,SERVICE_CONNECTION_ADMIN,SESSION_VARIABLES_ADMIN,SET_ANY_DEFINER,SHOW_ROUTINE,SYSTEM_USER,SYSTEM_VARIABLES_ADMIN,TABLE_ENCRYPTION_ADMIN,TELEMETRY_LOG_ADMIN,TRANSACTION_GTID_TAG,XA_RECOVER_ADMIN ON *.* TO `m8_all_privs`@`%` WITH GRANT OPTION */;
# WARNING: dropped MySQL privilege APPLICATION_PASSWORD_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege AUDIT_ABORT_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege AUDIT_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege AUTHENTICATION_POLICY_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege BACKUP_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege BINLOG_ENCRYPTION_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege CLONE_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege ENCRYPTION_KEY_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FIREWALL_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_OPTIMIZER_COSTS (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_PRIVILEGES (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_STATUS (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_TABLES (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_USER_RESOURCES (no MariaDB equivalent)
# WARNING: dropped MySQL privilege GROUP_REPLICATION_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege GROUP_REPLICATION_STREAM (no MariaDB equivalent)
# WARNING: dropped MySQL privilege INNODB_REDO_LOG_ARCHIVE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege INNODB_REDO_LOG_ENABLE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege OPTIMIZE_LOCAL_TABLE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege PASSWORDLESS_USER_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege PERSIST_RO_VARIABLES_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege RESOURCE_GROUP_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege RESOURCE_GROUP_USER (no MariaDB equivalent)
# WARNING: dropped MySQL privilege ROLE_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SENSITIVE_VARIABLES_OBSERVER (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SESSION_VARIABLES_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SYSTEM_USER (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SYSTEM_VARIABLES_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege TABLE_ENCRYPTION_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege TELEMETRY_LOG_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege TRANSACTION_GTID_TAG (no MariaDB equivalent)
# WARNING: dropped MySQL privilege XA_RECOVER_ADMIN (no MariaDB equivalent)
/*M!100005 GRANT SET USER, BINLOG REPLAY, BINLOG ADMIN, CONNECTION ADMIN, BINLOG REPLAY, REPLICATION SLAVE ADMIN, CONNECTION ADMIN, SET USER, SHOW CREATE ROUTINE ON *.* TO `m8_all_privs`@`%` WITH GRANT OPTION */;
GRANT USAGE ON *.* TO `m8_auth_caching_sha2`@`%`;
GRANT USAGE ON *.* TO `m8_auth_no_pwd`@`%`;
GRANT SELECT ON `m8_db`.* TO `m8_auth_no_pwd`@`%`;
GRANT USAGE ON *.* TO `m8_auth_sha256`@`%`;
GRANT USAGE ON *.* TO `m8_col_priv`@`%`;
GRANT SELECT (`col_a`, `col_underscore_b`), UPDATE (`col_a`) ON `m8_db`.`tab` TO `m8_col_priv`@`%`;
GRANT USAGE ON *.* TO `m8_combined`@`%`;
GRANT SELECT ON `m8_db`.* TO `m8_combined`@`%`;
/*!80001 GRANT `m8_default_a`@`%` TO `m8_combined`@`%` */;
/*M!100005 SET DEFAULT ROLE 'm8_default_a' FOR 'm8_combined'@'%' */;
/*!80001 ALTER USER 'm8_combined'@'%' DEFAULT ROLE 'm8_default_a'@'%' */;
GRANT USAGE ON *.* TO `m8_db_underscore`@`%`;
GRANT SELECT ON `m8_under_score_db`.* TO `m8_db_underscore`@`%`;
GRANT USAGE ON *.* TO `m8_default_a`@`%`;
GRANT USAGE ON *.* TO `m8_default_b`@`%`;
GRANT USAGE ON *.* TO `m8_default_role_many`@`%`;
/*!80001 GRANT `m8_default_a`@`%`,`m8_default_b`@`%` TO `m8_default_role_many`@`%` */;
/*M!100005 SET DEFAULT ROLE 'm8_default_a' FOR 'm8_default_role_many'@'%' */;
/*!80001 ALTER USER 'm8_default_role_many'@'%' DEFAULT ROLE 'm8_default_a'@'%' */;
/*M!100005 SET DEFAULT ROLE 'm8_default_b' FOR 'm8_default_role_many'@'%' */;
/*!80001 ALTER USER 'm8_default_role_many'@'%' DEFAULT ROLE 'm8_default_b'@'%' */;
GRANT USAGE ON *.* TO `m8_default_role_one`@`%`;
/*!80001 GRANT `m8_default_a`@`%` TO `m8_default_role_one`@`%` */;
/*M!100005 SET DEFAULT ROLE 'm8_default_a' FOR 'm8_default_role_one'@'%' */;
/*!80001 ALTER USER 'm8_default_role_one'@'%' DEFAULT ROLE 'm8_default_a'@'%' */;
GRANT SELECT, RELOAD, PROCESS, SHOW DATABASES, LOCK TABLES, REPLICATION CLIENT, SHOW VIEW, CREATE USER, EVENT, TRIGGER ON *.* TO `m8_dumper`@`%`;
GRANT SELECT ON `mysql`.* TO `m8_dumper`@`%`;
GRANT USAGE ON *.* TO `m8_dyn_all_dropped`@`%`;
/*!80001 GRANT AUDIT_ADMIN,BACKUP_ADMIN,CLONE_ADMIN ON *.* TO `m8_dyn_all_dropped`@`%` */;
# WARNING: dropped MySQL privilege AUDIT_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege BACKUP_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege CLONE_ADMIN (no MariaDB equivalent)
GRANT USAGE ON *.* TO `m8_dyn_flush_collapse`@`%`;
/*!80001 GRANT FLUSH_OPTIMIZER_COSTS,FLUSH_STATUS,FLUSH_TABLES,FLUSH_USER_RESOURCES ON *.* TO `m8_dyn_flush_collapse`@`%` */;
# WARNING: dropped MySQL privilege FLUSH_OPTIMIZER_COSTS (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_STATUS (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_TABLES (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_USER_RESOURCES (no MariaDB equivalent)
GRANT USAGE ON *.* TO `m8_dyn_grant_opt`@`%`;
/*!80001 GRANT BINLOG_ADMIN,CONNECTION_ADMIN ON *.* TO `m8_dyn_grant_opt`@`%` WITH GRANT OPTION */;
/*M!100005 GRANT BINLOG REPLAY, BINLOG ADMIN, CONNECTION ADMIN ON *.* TO `m8_dyn_grant_opt`@`%` WITH GRANT OPTION */;
GRANT USAGE ON *.* TO `m8_dyn_mapped`@`%`;
/*!80001 GRANT BINLOG_ADMIN ON *.* TO `m8_dyn_mapped`@`%` */;
/*M!100005 GRANT BINLOG REPLAY, BINLOG ADMIN ON *.* TO `m8_dyn_mapped`@`%` */;
GRANT USAGE ON *.* TO `m8_dyn_mixed`@`%`;
/*!80001 GRANT AUDIT_ADMIN,BACKUP_ADMIN,BINLOG_ADMIN,CONNECTION_ADMIN,REPLICATION_APPLIER,SHOW_ROUTINE ON *.* TO `m8_dyn_mixed`@`%` */;
# WARNING: dropped MySQL privilege AUDIT_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege BACKUP_ADMIN (no MariaDB equivalent)
/*M!100005 GRANT BINLOG REPLAY, BINLOG ADMIN, CONNECTION ADMIN, BINLOG REPLAY, SHOW CREATE ROUTINE ON *.* TO `m8_dyn_mixed`@`%` */;
GRANT USAGE ON *.* TO `m8_dyn_unmapped`@`%`;
/*!80001 GRANT BACKUP_ADMIN ON *.* TO `m8_dyn_unmapped`@`%` */;
# WARNING: dropped MySQL privilege BACKUP_ADMIN (no MariaDB equivalent)
GRANT USAGE ON *.* TO `m8_edge_at_in_name`@`%`;
GRANT SELECT ON `m8_db`.* TO `m8_edge_at_in_name`@`%`;
GRANT USAGE ON *.* TO `m8_edge_space`@`%`;
GRANT SELECT ON `m8_db`.* TO `m8_edge_space`@`%`;
GRANT USAGE ON *.* TO `m8_failed_login`@`%`;
GRANT USAGE ON *.* TO `m8_func_exec`@`%`;
GRANT EXECUTE ON FUNCTION `m8_db`.`func_one` TO `m8_func_exec`@`%`;
GRANT USAGE ON *.* TO `m8_host_dual`@`%`;
GRANT SELECT ON `m8_db`.`tab2` TO `m8_host_dual`@`%`;
GRANT USAGE ON *.* TO `m8_lock`@`%`;
GRANT USAGE ON *.* TO `m8_max_conn`@`%`;
GRANT PROCESS ON *.* TO `m8_multiscope`@`%`;
GRANT SELECT ON `m8_db`.* TO `m8_multiscope`@`%`;
GRANT INSERT, UPDATE ON `m8_db`.`tab` TO `m8_multiscope`@`%`;
GRANT SELECT, INSERT ON *.* TO `m8_partial_revoke`@`%`;
/*!80001 REVOKE INSERT ON `m8_db`.* FROM `m8_partial_revoke`@`%` */;
# WARNING: partial REVOKE has no MariaDB equivalent; the wider GRANT remains in effect on import. Operator action: review and re-grant at the narrower scope if needed.
GRANT USAGE ON *.* TO `m8_proc_exec`@`%`;
GRANT EXECUTE ON PROCEDURE `m8_db`.`proc_one` TO `m8_proc_exec`@`%`;
GRANT USAGE ON *.* TO `m8_proxy_target`@`%`;
GRANT USAGE ON *.* TO `m8_proxy_user`@`%`;
GRANT PROXY ON `m8_proxy_target`@`%` TO `m8_proxy_user`@`%`;
GRANT USAGE ON *.* TO `m8_pwd_expire_default`@`%`;
GRANT USAGE ON *.* TO `m8_pwd_expire_interval`@`%`;
GRANT USAGE ON *.* TO `m8_pwd_expire_never`@`%`;
GRANT USAGE ON *.* TO `m8_pwd_expire_now`@`%`;
GRANT USAGE ON *.* TO `m8_pwd_history`@`%`;
GRANT USAGE ON *.* TO `m8_pwd_require_current`@`%`;
GRANT USAGE ON *.* TO `m8_pwd_reuse`@`%`;
GRANT USAGE ON *.* TO `m8_require_cipher`@`%`;
GRANT USAGE ON *.* TO `m8_require_ssl`@`%`;
GRANT USAGE ON *.* TO `m8_require_x509`@`%`;
GRANT USAGE ON *.* TO `m8_resource_full`@`%`;
GRANT USAGE ON *.* TO `m8_role*/starslash`@`%`;
# WARNING: GRANT contains literal '*/' in an unsplittable context; emitted unwrapped, MariaDB import will reject it.
GRANT BACKUP_ADMIN ON *.* TO `m8_role*/starslash`@`%`;
# WARNING: dropped MySQL privilege BACKUP_ADMIN (no MariaDB equivalent)
GRANT USAGE ON *.* TO `m8_role_a`@`%`;
GRANT SELECT ON `m8_db`.* TO `m8_role_a`@`%`;
/*!80001 GRANT `m8_role_b`@`%` TO `m8_role_a`@`%` WITH ADMIN OPTION */;
GRANT USAGE ON *.* TO `m8_role_b`@`%`;
GRANT INSERT ON `m8_db`.* TO `m8_role_b`@`%`;
/*!80001 GRANT `m8_role_c`@`%` TO `m8_role_b`@`%` WITH ADMIN OPTION */;
GRANT USAGE ON *.* TO `m8_role_c`@`%`;
GRANT UPDATE ON `m8_db`.* TO `m8_role_c`@`%`;
GRANT SHOW DATABASES ON *.* TO `m8_role_d`@`%`;
/*!80001 GRANT CREATE ROLE, DROP ROLE ON *.* TO `m8_role_static`@`%` */;
# WARNING: dropped MySQL privilege CREATE ROLE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege DROP ROLE (no MariaDB equivalent)
GRANT USAGE ON *.* TO `m8_routine_admin`@`%`;
GRANT EXECUTE, CREATE ROUTINE, ALTER ROUTINE ON `m8_db`.* TO `m8_routine_admin`@`%`;
GRANT USAGE ON *.* TO `m8_shared_role`@`%`;
GRANT SELECT ON `m8_db`.`tab` TO `m8_shared_role`@`%`;
GRANT EXECUTE ON PROCEDURE `m8_db`.`proc_one` TO `m8_shared_role`@`%`;
GRANT USAGE ON *.* TO `m8_shared_user_1`@`%`;
/*!80001 GRANT `m8_default_a`@`%`,`m8_shared_role`@`%` TO `m8_shared_user_1`@`%` */;
GRANT USAGE ON *.* TO `m8_shared_user_2`@`%`;
/*!80001 GRANT `m8_default_a`@`%` TO `m8_shared_user_2`@`%` */;
/*!80001 GRANT `m8_shared_role`@`%` TO `m8_shared_user_2`@`%` WITH ADMIN OPTION */;
GRANT USAGE ON *.* TO `m8_shared_user_3`@`%`;
/*!80001 GRANT `m8_shared_role`@`%` TO `m8_shared_user_3`@`%` */;
GRANT USAGE ON *.* TO `m8_shared_user_4`@`%`;
/*!80001 GRANT `m8_shared_role`@`%` TO `m8_shared_user_4`@`%` */;
GRANT USAGE ON *.* TO `m8_shared_user_5`@`%`;
/*!80001 GRANT `m8_shared_role`@`%` TO `m8_shared_user_5`@`%` WITH ADMIN OPTION */;
GRANT USAGE ON *.* TO `m8_simple`@`%`;
GRANT SELECT ON `m8_db`.* TO `m8_simple`@`%`;
/*!80001 GRANT `m8_role_d`@`%` TO `m8_simple`@`%` */;
/*!80001 GRANT `m8_role_a`@`%` TO `m8_simple`@`%` WITH ADMIN OPTION */;
GRANT USAGE ON *.* TO `m8_starslash_comment`@`%`;
GRANT USAGE ON *.* TO `m8_starslash_escaped`@`%`;
GRANT SELECT ON *.* TO `m8_static_dyn_mix`@`%`;
/*!80001 GRANT BACKUP_ADMIN,BINLOG_ADMIN ON *.* TO `m8_static_dyn_mix`@`%` */;
# WARNING: dropped MySQL privilege BACKUP_ADMIN (no MariaDB equivalent)
/*M!100005 GRANT BINLOG REPLAY, BINLOG ADMIN ON *.* TO `m8_static_dyn_mix`@`%` */;
GRANT RELOAD, PROCESS ON *.* TO `m8_static_priv`@`%`;
GRANT SELECT, INSERT, UPDATE, DELETE ON `m8_db`.* TO `m8_static_priv`@`%`;
/*!80001 GRANT SELECT, INSERT, CREATE ROLE, DROP ROLE ON *.* TO `m8_static_role_mix`@`%` */;
# WARNING: dropped MySQL privilege CREATE ROLE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege DROP ROLE (no MariaDB equivalent)
/*M!100005 GRANT SELECT, INSERT ON *.* TO `m8_static_role_mix`@`%` */;
GRANT USAGE ON *.* TO `m8_system_grants`@`%`;
GRANT SELECT ON `performance_schema`.* TO `m8_system_grants`@`%`;
GRANT SELECT ON `mysql`.`user` TO `m8_system_grants`@`%`;
GRANT USAGE ON *.* TO `m8_unlock`@`%`;
GRANT USAGE ON *.* TO `m8_usage_only`@`%`;
GRANT USAGE ON *.* TO `m8_with_attribute`@`%`;
GRANT USAGE ON *.* TO `m8_with_comment`@`%`;
GRANT USAGE ON *.* TO `m8_用户`@`%`;
GRANT SELECT ON `m8_db`.* TO `m8_用户`@`%`;
GRANT USAGE ON *.* TO `m8_edge_wildcard_host`@`192.168.%.%`;
GRANT SELECT ON `m8_db`.* TO `m8_edge_wildcard_host`@`192.168.%.%`;
GRANT USAGE ON *.* TO ``@`localhost`;
GRANT USAGE ON *.* TO `m8_host_dual`@`localhost`;
GRANT SELECT ON `m8_db`.* TO `m8_host_dual`@`localhost`;
GRANT USAGE ON *.* TO `m8_host_localhost`@`localhost`;
GRANT SELECT ON `m8_db`.* TO `m8_host_localhost`@`localhost`;
GRANT SELECT ON *.* TO `mysql.infoschema`@`localhost`;
/*!80001 GRANT AUDIT_ABORT_EXEMPT,FIREWALL_EXEMPT,SYSTEM_USER ON *.* TO `mysql.infoschema`@`localhost` */;
# WARNING: dropped MySQL privilege AUDIT_ABORT_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FIREWALL_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SYSTEM_USER (no MariaDB equivalent)
GRANT SHUTDOWN, SUPER ON *.* TO `mysql.session`@`localhost`;
/*!80001 GRANT AUDIT_ABORT_EXEMPT,AUTHENTICATION_POLICY_ADMIN,BACKUP_ADMIN,CLONE_ADMIN,CONNECTION_ADMIN,FIREWALL_EXEMPT,PERSIST_RO_VARIABLES_ADMIN,SESSION_VARIABLES_ADMIN,SYSTEM_USER,SYSTEM_VARIABLES_ADMIN ON *.* TO `mysql.session`@`localhost` */;
# WARNING: dropped MySQL privilege AUDIT_ABORT_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege AUTHENTICATION_POLICY_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege BACKUP_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege CLONE_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FIREWALL_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege PERSIST_RO_VARIABLES_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SESSION_VARIABLES_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SYSTEM_USER (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SYSTEM_VARIABLES_ADMIN (no MariaDB equivalent)
/*M!100005 GRANT CONNECTION ADMIN ON *.* TO `mysql.session`@`localhost` */;
GRANT SELECT ON `performance_schema`.* TO `mysql.session`@`localhost`;
GRANT SELECT ON `mysql`.`user` TO `mysql.session`@`localhost`;
GRANT USAGE ON *.* TO `mysql.sys`@`localhost`;
/*!80001 GRANT AUDIT_ABORT_EXEMPT,FIREWALL_EXEMPT,SYSTEM_USER ON *.* TO `mysql.sys`@`localhost` */;
# WARNING: dropped MySQL privilege AUDIT_ABORT_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FIREWALL_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SYSTEM_USER (no MariaDB equivalent)
GRANT TRIGGER ON `sys`.* TO `mysql.sys`@`localhost`;
GRANT SELECT ON `sys`.`sys_config` TO `mysql.sys`@`localhost`;
/*!80001 GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, SUPER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER, CREATE TABLESPACE, CREATE ROLE, DROP ROLE ON *.* TO `root`@`localhost` WITH GRANT OPTION */;
# WARNING: dropped MySQL privilege CREATE ROLE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege DROP ROLE (no MariaDB equivalent)
/*M!100005 GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, SHUTDOWN, PROCESS, FILE, REFERENCES, INDEX, ALTER, SHOW DATABASES, SUPER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER, EVENT, TRIGGER, CREATE TABLESPACE ON *.* TO `root`@`localhost` WITH GRANT OPTION */;
/*!80001 GRANT ALLOW_NONEXISTENT_DEFINER,APPLICATION_PASSWORD_ADMIN,AUDIT_ABORT_EXEMPT,AUDIT_ADMIN,AUTHENTICATION_POLICY_ADMIN,BACKUP_ADMIN,BINLOG_ADMIN,BINLOG_ENCRYPTION_ADMIN,CLONE_ADMIN,CONNECTION_ADMIN,ENCRYPTION_KEY_ADMIN,FIREWALL_EXEMPT,FLUSH_OPTIMIZER_COSTS,FLUSH_PRIVILEGES,FLUSH_STATUS,FLUSH_TABLES,FLUSH_USER_RESOURCES,GROUP_REPLICATION_ADMIN,GROUP_REPLICATION_STREAM,INNODB_REDO_LOG_ARCHIVE,INNODB_REDO_LOG_ENABLE,OPTIMIZE_LOCAL_TABLE,PASSWORDLESS_USER_ADMIN,PERSIST_RO_VARIABLES_ADMIN,REPLICATION_APPLIER,REPLICATION_SLAVE_ADMIN,RESOURCE_GROUP_ADMIN,RESOURCE_GROUP_USER,ROLE_ADMIN,SENSITIVE_VARIABLES_OBSERVER,SERVICE_CONNECTION_ADMIN,SESSION_VARIABLES_ADMIN,SET_ANY_DEFINER,SHOW_ROUTINE,SYSTEM_USER,SYSTEM_VARIABLES_ADMIN,TABLE_ENCRYPTION_ADMIN,TELEMETRY_LOG_ADMIN,TRANSACTION_GTID_TAG,XA_RECOVER_ADMIN ON *.* TO `root`@`localhost` WITH GRANT OPTION */;
# WARNING: dropped MySQL privilege APPLICATION_PASSWORD_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege AUDIT_ABORT_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege AUDIT_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege AUTHENTICATION_POLICY_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege BACKUP_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege BINLOG_ENCRYPTION_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege CLONE_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege ENCRYPTION_KEY_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FIREWALL_EXEMPT (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_OPTIMIZER_COSTS (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_PRIVILEGES (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_STATUS (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_TABLES (no MariaDB equivalent)
# WARNING: dropped MySQL privilege FLUSH_USER_RESOURCES (no MariaDB equivalent)
# WARNING: dropped MySQL privilege GROUP_REPLICATION_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege GROUP_REPLICATION_STREAM (no MariaDB equivalent)
# WARNING: dropped MySQL privilege INNODB_REDO_LOG_ARCHIVE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege INNODB_REDO_LOG_ENABLE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege OPTIMIZE_LOCAL_TABLE (no MariaDB equivalent)
# WARNING: dropped MySQL privilege PASSWORDLESS_USER_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege PERSIST_RO_VARIABLES_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege RESOURCE_GROUP_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege RESOURCE_GROUP_USER (no MariaDB equivalent)
# WARNING: dropped MySQL privilege ROLE_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SENSITIVE_VARIABLES_OBSERVER (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SESSION_VARIABLES_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SYSTEM_USER (no MariaDB equivalent)
# WARNING: dropped MySQL privilege SYSTEM_VARIABLES_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege TABLE_ENCRYPTION_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege TELEMETRY_LOG_ADMIN (no MariaDB equivalent)
# WARNING: dropped MySQL privilege TRANSACTION_GTID_TAG (no MariaDB equivalent)
# WARNING: dropped MySQL privilege XA_RECOVER_ADMIN (no MariaDB equivalent)
/*M!100005 GRANT SET USER, BINLOG REPLAY, BINLOG ADMIN, CONNECTION ADMIN, BINLOG REPLAY, REPLICATION SLAVE ADMIN, CONNECTION ADMIN, SET USER, SHOW CREATE ROUTINE ON *.* TO `root`@`localhost` WITH GRANT OPTION */;
GRANT PROXY ON ``@`` TO `root`@`localhost` WITH GRANT OPTION;
GRANT USAGE ON *.* TO `m8_default_a`@`%`;
GRANT USAGE ON *.* TO `m8_default_b`@`%`;
GRANT USAGE ON *.* TO `m8_role_a`@`%`;
GRANT SELECT ON `m8_db`.* TO `m8_role_a`@`%`;
/*!80001 GRANT `m8_role_b`@`%` TO `m8_role_a`@`%` WITH ADMIN OPTION */;
GRANT USAGE ON *.* TO `m8_role_b`@`%`;
GRANT INSERT ON `m8_db`.* TO `m8_role_b`@`%`;
/*!80001 GRANT `m8_role_c`@`%` TO `m8_role_b`@`%` WITH ADMIN OPTION */;
GRANT USAGE ON *.* TO `m8_role_c`@`%`;
GRANT UPDATE ON `m8_db`.* TO `m8_role_c`@`%`;
GRANT SHOW DATABASES ON *.* TO `m8_role_d`@`%`;
GRANT USAGE ON *.* TO `m8_shared_role`@`%`;
GRANT SELECT ON `m8_db`.`tab` TO `m8_shared_role`@`%`;
GRANT EXECUTE ON PROCEDURE `m8_db`.`proc_one` TO `m8_shared_role`@`%`;
SET ROLE NONE;
DROP ROLE mariadb_dump_import_role;
/*M!100203 EXECUTE IMMEDIATE CONCAT('SET ROLE ', @current_role) */;

USE mysql;

--
-- Dumping data for table `innodb_index_stats`
--

LOCK TABLES `innodb_index_stats` WRITE;
/*!40000 ALTER TABLE `innodb_index_stats` DISABLE KEYS */;
REPLACE INTO `innodb_index_stats` VALUES
('m8_db','tab','GEN_CLUST_INDEX','2026-05-11 13:04:17','n_diff_pfx01',0,1,'DB_ROW_ID'),
('m8_db','tab','GEN_CLUST_INDEX','2026-05-11 13:04:17','n_leaf_pages',1,NULL,'Number of leaf pages in the index'),
('m8_db','tab','GEN_CLUST_INDEX','2026-05-11 13:04:17','size',1,NULL,'Number of pages in the index'),
('m8_db','tab2','PRIMARY','2026-05-11 13:04:17','n_diff_pfx01',0,1,'id'),
('m8_db','tab2','PRIMARY','2026-05-11 13:04:17','n_leaf_pages',1,NULL,'Number of leaf pages in the index'),
('m8_db','tab2','PRIMARY','2026-05-11 13:04:17','size',1,NULL,'Number of pages in the index'),
('m8_under_score_db','t','GEN_CLUST_INDEX','2026-05-11 13:04:17','n_diff_pfx01',0,1,'DB_ROW_ID'),
('m8_under_score_db','t','GEN_CLUST_INDEX','2026-05-11 13:04:17','n_leaf_pages',1,NULL,'Number of leaf pages in the index'),
('m8_under_score_db','t','GEN_CLUST_INDEX','2026-05-11 13:04:17','size',1,NULL,'Number of pages in the index'),
('mysql','component','PRIMARY','2026-05-08 14:22:55','n_diff_pfx01',1,1,'component_id'),
('mysql','component','PRIMARY','2026-05-08 14:22:55','n_leaf_pages',1,NULL,'Number of leaf pages in the index'),
('mysql','component','PRIMARY','2026-05-08 14:22:55','size',1,NULL,'Number of pages in the index'),
('sys','sys_config','PRIMARY','2026-05-04 12:28:43','n_diff_pfx01',6,1,'variable'),
('sys','sys_config','PRIMARY','2026-05-04 12:28:43','n_leaf_pages',1,NULL,'Number of leaf pages in the index'),
('sys','sys_config','PRIMARY','2026-05-04 12:28:43','size',1,NULL,'Number of pages in the index');
/*!40000 ALTER TABLE `innodb_index_stats` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `innodb_table_stats`
--

LOCK TABLES `innodb_table_stats` WRITE;
/*!40000 ALTER TABLE `innodb_table_stats` DISABLE KEYS */;
REPLACE INTO `innodb_table_stats` VALUES
('m8_db','tab','2026-05-11 13:04:17',0,1,0),
('m8_db','tab2','2026-05-11 13:04:17',0,1,0),
('m8_under_score_db','t','2026-05-11 13:04:17',0,1,0),
('mysql','component','2026-05-08 14:22:55',1,1,0),
('sys','sys_config','2026-05-04 12:28:43',6,1,0);
/*!40000 ALTER TABLE `innodb_table_stats` ENABLE KEYS */;
UNLOCK TABLES;

USE mysql;

--
-- Dumping data for table `time_zone`
--

LOCK TABLES `time_zone` WRITE;
/*!40000 ALTER TABLE `time_zone` DISABLE KEYS */;
/*!40000 ALTER TABLE `time_zone` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `time_zone_name`
--

LOCK TABLES `time_zone_name` WRITE;
/*!40000 ALTER TABLE `time_zone_name` DISABLE KEYS */;
/*!40000 ALTER TABLE `time_zone_name` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `time_zone_leap_second`
--

LOCK TABLES `time_zone_leap_second` WRITE;
/*!40000 ALTER TABLE `time_zone_leap_second` DISABLE KEYS */;
/*!40000 ALTER TABLE `time_zone_leap_second` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `time_zone_transition`
--

LOCK TABLES `time_zone_transition` WRITE;
/*!40000 ALTER TABLE `time_zone_transition` DISABLE KEYS */;
/*!40000 ALTER TABLE `time_zone_transition` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `time_zone_transition_type`
--

LOCK TABLES `time_zone_transition_type` WRITE;
/*!40000 ALTER TABLE `time_zone_transition_type` DISABLE KEYS */;
/*!40000 ALTER TABLE `time_zone_transition_type` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed on 2026-05-11 16:15:12
