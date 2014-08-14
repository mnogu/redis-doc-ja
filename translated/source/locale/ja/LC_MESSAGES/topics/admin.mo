Þ          Ô              Q   	  c   [  ç   ¿  G  §  ¶  ï  £   ¦    J  è   c  ¸   L	  ä   
     ê
  Ð   ÿ
     Ð  Ñ   â  Ó   ´  T     Ç   Ý  ¥   ¥  9   K  0     X   ¶      H        i     ð  %  r  Ï      h  ¼     Y  <        «  ,  ½     ê  ÿ   ú  !   ú      å   5      !  "  !  Ë   Á"  ^   #  Q   ì#     >$  ~  È$                  	      
                                                                                Configure all your clients in order to use the new instance (that is, the slave). Even if you have persistence disabled, Redis will need to perform RDB saves if you use replication. However from time to time a restart is mandatory, for instance in order to upgrade the Redis process to a newer version, or when you need to modify some configuration parameter that is currently not supported by the CONFIG command. If you are deploying using a virtual machine that uses the **Xen hypervisor you may experience slow fork() times**. This may block Redis from a few milliseconds up to a few seconds depending on the dataset size. Check the `latency page </topics/latency>`__ for more information. This problem is not common to other hypervisors. If you are using Redis in a very write-heavy application, while saving an RDB file on disk or rewriting the AOF log **Redis may use up to 2 times the memory normally used**. The additional memory used is proportional to the number of memory pages modified by writes during the saving process, so it is often proportional to the number of keys (or aggregate types items) touched during this time. Make sure to size your memory accordingly. If you use a single server, make sure that the slave is started in a different port than the master instance, otherwise the slave will not be able to start at all. Make sure to **setup some swap** in your system (we suggest as much as swap as memory). If Linux does not have swap and your Redis instance accidentally consumes too much memory, either Redis will crash for out of memory or the Linux kernel OOM killer will kill the Redis process. Make sure to set the Linux kernel **overcommit memory setting to 1**. Add ``vm.overcommit_memory = 1`` to ``/etc/sysctl.conf`` and then reboot or run the command ``sysctl vm.overcommit_memory=1`` for this to take effect immediately. Make sure using INFO that there are the same number of keys in the master and in the slave. Check with redis-cli that the slave is working as you wish and is replying to your commands. Once you are sure that the master is no longer receiving any query (you can check this with the `MONITOR command </commands/monitor>`__), elect the slave to master using the **SLAVEOF NO ONE** command, and shut down your master. Redis Administration Redis is designed to be a very long running process in your server. For instance many configuration options can be modified without any kind of restart using the `CONFIG SET command </commands/config-set>`__. Redis setup hints Setup your new Redis instance as a slave for your current Redis instance. In order to do so you need a different server, or a server that has enough RAM to keep two instances of Redis running at the same time. Starting from Redis 2.2 it is even possible to switch from AOF to RDB snapshots persistence or the other way around without restarting Redis. Check the output of the 'CONFIG GET \*' command for more information. The following steps provide a very commonly used way in order to avoid any downtime. The use of Redis persistence with **EC2 EBS volumes is discouraged** since EBS performance is usually poor. Use ephemeral storage to persist and then move your persistence files to EBS when possible. This page contains topics related to the administration of Redis instances. Every topic is self contained in form of a FAQ. New topics will be created in the future. Upgrading or restarting a Redis instance without downtime Use ``daemonize no`` when run under daemontools. Wait for the replication initial synchronization to complete (check the slave log file). We suggest deploying Redis using the **Linux operating system**. Redis is also tested heavily on osx, and tested from time to time on FreeBSD and OpenBSD systems. However Linux is where we do all the major stress testing, and where most production deployments are working. Project-Id-Version: Redis Documentation (Japanese) 0.1
Report-Msgid-Bugs-To: 
POT-Creation-Date: 2014-07-31 23:30+0900
PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE
Last-Translator: FULL NAME <EMAIL@ADDRESS>
Language-Team: LANGUAGE <LL@li.org>
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
 ãã¹ã¦ã®ã¯ã©ã¤ã¢ã³ãããæ°ããã¤ã³ã¹ã¿ã³ã¹(ã¤ã¾ããã¹ã¬ã¼ã)ãåãããã«è¨­å®ãã¦ãã ããã æ°¸ç¶åãç¡å¹ã«ããå ´åã§ããã¬ããªã±ã¼ã·ã§ã³ãè¡ãå ´åã¯ Redis ã¯ RDB ã®ä¿å­ãå®è¡ãã¾ãã ããããæã«ã¯åèµ·åãå¿é ã¨ãªãå ´åãããã¾ãããã¨ãã° Redis ãã­ã»ã¹ãæ°ãããã¼ã¸ã§ã³ã«ã¢ããã°ã¬ã¼ããããCONFIG ã³ãã³ããç¾å¨ã®ã¨ãããµãã¼ããã¦ããªããã©ã¡ã¼ã¿ãå¤æ´ããå¿è¦ãããããªã©ã§ãã **Xen ãã¤ãã¼ãã¤ã¶ãä½¿ã£ãä»®æ³ç°å¢ã«ããã­ã¤ããã¨ fork() æéãé·ããªããã¨ãããã¾ã** ããã¼ã¿ã»ããã®ãµã¤ãºã«ããã¾ãããæ°ããªç§ããæ°ç§ã«ããã£ã¦ Redis ããã­ãã¯ããããã¨ãããã¾ããããè©³ããæå ±ã¯ã `latency ã® ãã¼ã¸ <./latency.html>`_ ãåç§ãã¦ãã ããããã®åé¡ã¯ä»ã®ãã¤ãã¼ãã¤ã¶ã§ä¸è¬çãªãã®ã§ã¯ããã¾ããã æ´æ°ãéå¸¸ã«å¤ãã·ã¹ãã ã§ Redis ãä½¿ãå ´åãRDB ãã¡ã¤ã«ã®ä¿å­æã AOF ã­ã°ã®ãªã©ã¤ãæã«ã **Redis ã¯éå¸¸ã® 2 åã®ã¡ã¢ãªãä½¿ç¨ãã¾ã** ãè¿½å ã§å¿è¦ãªã¡ã¢ãªéã¯ãä¿å­ãããã­ã»ã¹ãæ¸ãè¾¼ã¿ãè¡ã£ã¦ããéã«å¤æ´ãããã¡ã¢ãªãã¼ã¸æ°ã«æ¯ä¾ãã¾ããã¤ã¾ãããã®éã«å¤æ´ãããã­ã¼(ã¾ãã¯éç´ã¿ã¤ãã®è¦ç´ )ã®æ°ã«æ¯ä¾ãã¾ãããã®ãã¨ãèæ®ãã¦ã¡ã¢ãªãµã¤ãºãè¦ç©ãã£ã¦ãã ããã 1 ã¤ã®ãµã¼ãã¼ãä½¿ãå ´åãå¿ããã¹ã¿ã¼ã¤ã³ã¹ã¿ã³ã¹ã¨ã¯å¥ã®ãã¼ãã§èµ·åããã¦ãã ãããããããªãã¨ãã¹ã¬ã¼ãã¯èµ·åã§ãã¾ããã ã·ã¹ãã ã« **ããããã® swap ãè¨­å®ãã¦ãã ãã** (ã¡ã¢ãªã¨åãå¤§ãããæ¨å¥¨ãã¾ã)ããã swap ããªãã¨ãRedis ãæ¥æ¿ã«ã¡ã¢ãªãæ¶è²»ãããã¦ãã¾ã£ãããã¯ã©ãã·ã¥ããããLinux ã«ã¼ãã«ã® OOM killer ã« Redis ãã­ã»ã¹ã kill ããã¦ãã¾ããã¨ãããã¾ãã Linux ã®ã«ã¼ãã«ã **overcommit memory setting to 1** ã¨ãã¦ãã ããã ``/etc/sysctl.conf`` ã« ``vm.overcommit_memory = 1`` ãè¨­å®ãããªãã¼ããããã¯å³æåæ ã®ãã ``sysctl vm.overcommit_memory=1`` ã³ãã³ããçºè¡ãã¦ãã ããã INFO ã³ãã³ããä½¿ã£ã¦ããã¹ã¿ã¼ã¨åãæ°ã®ã­ã¼ãã¹ã¬ã¼ãä¸ã«å­å¨ãããã¨ãç¢ºèªãã¦ãã ãããredis-cli ã§ãã¹ã¬ã¼ããæå¾ã©ããã«ç¨¼åãã¦ãããã¨ãã³ãã³ãã«å¿ç­ãããã¨ãç¢ºèªãã¦ãã ããã ãã¹ã¿ã¼ãã©ã®ãããªã¯ã¨ãªãåãä»ãã¦ããªããã¨ãç¢ºèªã§ããã(`MONITOR ã³ãã³ã <http://redis.io/commands/monitor>`_ ã§ç¢ºèªã§ãã¾ã)ã **SLAVEOF NO ONE** ã³ãã³ãã§ã¹ã¬ã¼ãããã¹ã¿ã¼ã«ææ ¼ããããã¹ã¿ã¼ãåæ­¢ãã¦ãã ããã Redis ã®ç®¡ç Redis ã¯ãéå¸¸ã«é·æéç¨¼åãç¶ããããã«è¨­è¨ããã¦ãã¾ãããã¨ãã°ãå¤ãã®è¨­å®ãªãã·ã§ã³ã¯ `CONFIG SET ã³ãã³ã <http://redis.io/commands/config-set>`_ ãä½¿ã£ã¦ãåèµ·åãªãã«å¤æ´ãå¯è½ã§ãã Redis ã»ããã¢ãããã³ã æ°ãã Redis ã¤ã³ã¹ã¿ã³ã¹ãç¾å¨ã® Redis ã¤ã³ã¹ã¿ã³ã¹ã®ã¹ã¬ã¼ãã¨ãã¦èµ·åãã¾ãããã®ãããå¥ã®ãµã¼ãã¼ãã2 ã¤ã® Redis ã¤ã³ã¹ã¿ã³ã¹ãåæã«ç¨¼åãããããã ãã®ååãª RAM ããã¤ãµã¼ãã¼ãå¿è¦ã§ãã Redis 2.2 ãããåèµ·åãªãã§ AOF ãã RDB ã¹ãããã·ã§ããæ°¸ç¶åã¸åãæ¿ãããã¨ãã§ããããã«ãªãã¾ãããè©³ããã¯ 'CONFIG GET \*' ã³ãã³ãã®åºåãç¢ºèªãã¦ãã ããã ä»¥ä¸ã®ã¹ãããã¯ããã¦ã³ã¿ã¤ã ãåé¿[è¨³æ³¨: ããªããåèµ·å]ãããã£ã¨ãä¸è¬çãªæ¹æ³ã§ãã Redis ã®æ°¸ç¶åã **EC2 EBS ããªã¥ã¼ã ã§è¡ããã¨ã¯æ¨å¥¨ããã¾ãã** ã EBS ã®æ§è½ã¯ãã¾ãè¯ããªãããã§ããæ°¸ç¶åã«ã¯ ephemeral ã¹ãã¬ã¼ã¸ãä½¿ããå¯è½ãªã¿ã¤ãã³ã°ã§æ°¸ç¶åãããã¡ã¤ã«ã EBS ã«ç§»åãã¦ãã ããã ãã®ãã¼ã¸ã§ã¯ Redis ã®ç®¡çã«é¢ããè©±é¡ãè¨è¿°ãã¾ãããã¹ã¦ã®ãããã¯ã¯ãFAQ å½¢å¼ã§å®çµãã¦ãã¾ããæ°ãããããã¯ã¯éæè¿½å ãããäºå®ã§ãã ãã¦ã³ã¿ã¤ã ãªãã§ Redis ã¤ã³ã¹ã¿ã³ã¹ãã¢ããã°ã¬ã¼ããåèµ·åãã daemontools ãä½¿ãå ´åã¯ã ``daemonize no`` ãæå®ãã¦ãã ããã ã¬ããªã±ã¼ã·ã§ã³ã®åååæãå®äºããã¾ã§å¾ã¡ã¾ã(ã¹ã¬ã¼ãã®ã­ã°ãã¡ã¤ã«ãç¢ºèªãã¦ãã ãã)ã **Linux ãªãã¬ã¼ãã£ã³ã°ã·ã¹ãã ** ä¸ã« Redis ãããã­ã¤ãããã¨ãæ¨å¥¨ãã¾ããRedis ã¯ OSX ã§ãååã«ãã¾ããã°ãã° FreeBSD ã OpenBSD ã§ããã¹ãããã¦ãã¾ããããããç§ãã¡ã¯ Linux ã«ã¦ä¸»ãªè² è·ãã¹ããå®æ½ãã¦ãããã¾ãã»ã¨ãã©ã®ãã­ãã¯ã·ã§ã³ç°å¢ã¯ Linux ã§ç¨¼åãã¦ãã¾ãã 