.. Using Redis as an LRU cache

=========================================
Redis を LRU キャッシュとして使う
=========================================

.. note:: 
   このドキュメントは `Using Redis as an LRU cache <http://redis.io/topics/lru-cache>`_ の翻訳です。
   誤訳を見つけたら `翻訳リポジトリ <https://github.com/mocobeta/redis-doc-ja>`_ に Issue 登録をお願いします。

.. When Redis is used as a cache, sometimes it is handy to let it automatically
.. evict old data as you add new one. This behavior is very well known in the
.. community of developers, since it is the default behavior of the popular
.. *memcached* system.

Redis をキャッシュとして使う際、新しいデータを追加するときに自動的に古いデータを追い出すようにできると便利です。この振る舞いは、人気の高い *memcached* システムのデフォルトの振る舞いであるため、開発者の間では非常によく知られています。

.. LRU is actually only one of the supported eviction methods. This page covers
.. the more general topic of the Redis `maxmemory` directive that is used in
.. order to limit the memory usage to a fixed amount, and it also covers in
.. depth the LRU algorithm used by Redis, that is actually an approximation of
.. the exact LRU.

LRU は、実際にはエビクション・メソッドのひとつにすぎません。このページでは Redis のメモリ使用量を制限するための 'maxmemory' ディレクティブについて、より一般的なトピックを扱います。また、Redis で使用されている LRU アルゴリズムについても扱います。Redis の LRU アルゴリズムは、実際には正確な LRU ではなく、その近似です。

.. Maxmemory configuration directive

メモリ設定のためのディレクティブ
====================================

.. The `maxmemory` configuration directive is used in order to configure Redis
.. to use a specified amount of memory for the data set. It is possible to
.. set the configuration directive using the `redis.conf` file, or later using
.. the `CONFIG SET` command at runtime.

'maxmemory' ディレクティブは、データセットに対して指定された量のメモリを使用するように、 Redis を設定するために使います。この値を設定するには、'redis.conf' ファイルに書くか、または実行時に `CONFIG SET <http://redis.io/commands/config-set>`_ コマンドを使っても指定できます。

.. For example in order to configure a memory limit of 100 megabytes, the
.. following directive can be used inside the `redis.conf` file.

たとえばメモリの制限を 100 MB に設定するためには、以下のディレクティブを 'redis.conf' ファイルに書きます。

.. code-block:: none

    maxmemory 100mb

.. Setting `maxmemory` to zero results into no memory limits. This is the
.. default behavior for 64 bit systems, while 32 bit systems use an implicit
.. memory limit of 3GB.

'maxmemory' に 0 を指定すると、使用メモリに制限をかけない、という意味になります。これは 64 bit システムではデフォルトの振る舞いですが、32 bit システムでは暗黙的に 3GB の制限がかかります。

.. When the specified amount of memory is reached, it is possible to select
.. among different behaviors, called **policies**.
.. Redis can just return errors for commands that could result in more memory
.. being used, or it can evict some old data in order to return back to the
.. specified limit every time new data is added.

指定されたメモリ使用量に達した場合、 **ポリシー** と呼ばれるいくつかの異なる振る舞いのなかから、ひとつを選択することができます。Redis は、追加のメモリを必要とするコマンドに対して単純にエラーを返すことも、新しいデータが追加される度に古いデータを消去し、指定された制限を超えないようにすることも可能です。

.. Eviction policies

エビクション・ポリシー
=========================

.. The exact behavior Redis follows when the `maxmemory` limit is reached is
.. configured using the `maxmemory-policy` configuration directive.

'maxmemory' に達したときの Redis の正確な振る舞いは、'maxmemory-policy' 設定ディレティブに従います。

.. The following policies are available:

以下のポリシーが選択できます:

.. * **noeviction**: return errors when the memory limit was reached and the client is trying to execute commands that could result in more memory to be used (most write commands, but `DEL` and a few more exceptions).
.. * **allkeys-lru**: evict keys trying to remove the less recently used (LRU) keys first, in order to make space for the new data added.
.. * **volatile-lru**: evict keys trying to remove the less recently used (LRU) keys first, but only among keys that have an **expire set**, in order to make space for the new data added.
.. * **allkeys-random**: evict random keys in order to make space for the new data added.
.. * **volatile-random**: evict random keys in order to make space for the new data added, but only evict keys with an **expire set**.
.. * **volatile-ttl**: In order to make space for the new data, evict only keys with an **expire set**, and try to evict keys with a shorter time to live (TTL) first.

* **noeviction** : メモリ使用量が制限に達しており、クライアントが追加のメモリを要求するコマンド(`DEL <http://redis.io/commands/del>`_ やいくつかの例外を除く、ほとんどの書き込みコマンド)を実行しようとした場合はエラーを返す。
* **allkeys-lru** : 新しいデータのためにスペースを空けるため、もっとも最近使われていない(LRU)キーから削除するよう試みる。
* **volatile-lru** : 新しいデータのためにスペースを空けるため、もっとも最近使われていない(LRU)キーから削除するよう試みる。ただし、 **expire set** が指定されたキーのみを対象とする。
* **allkeys-random** : 新しいデータのためにスペースを空けるため、ランダムなキーを選んで削除する。
* **volatile-random** : 新しいデータのためにスペースを空けるため、ランダムなキーを選んで削除する。ただし、 **expire set** が指定されたキーのみを対象とする。
* **volatile-ttl** : 新しいデータのためにスペースを空けるため、 **expire set** が指定されたキーのうち、より小さな TTL をもつキーから削除するよう試みる。

.. The policies **volatile-lru**, **volatile-random** and **volatile-ttl** behave like **noeviction** if there are no keys to evict matching the prerequisites.

**volatile-lru**, **volatile-random**, **volatile-ttl** ポリシーは、前提条件にマッチするキーが存在しない場合、 **noeviction** と同じ振る舞いをします。

.. To pick the right eviction policy is important depending on the access pattern 
.. of your application, however you can reconfigure the policy at runtime while 
.. the application is running, and monitor the number of cache misses and hits 
.. using the Redis `INFO` output in order to tune your setup.

アプリケーションのアクセスパターンによって、適切なエビクション・ポリシーを選択することは重要です。アプリケーションを稼働させながら、実行時にポリシーを再設定することも可能です。また、設定のチューニングのため、 `INFO <http://redis.io/commands/info>`_ コマンドの出力からキャッシュミスやヒット数を監視することができます。

.. In general as a rule of thumb:

一般的な経験則:

.. * Use the **allkeys-lru** policy when you expect a power-law distribution in the popularity of your requests, that is, you expect that a subset of elements will be accessed far more often than the rest. **This is a good pick if you are unsure**.
.. * Use the **allkeys-random** if you have a cyclic access where all the keys are scanned continuously, or when you expect the distribution to be normal (all elements likely accessed with the same probability).
.. * Use the **volatile-ttl** if you want to be able to provide hints to Redis about what are good candidate for expiration by using different TTL values when you create your cache objects.

* リクエストの大半がべき乗分布に従う、つまり、全体のあるサブセットがその他よりもより頻繁にアクセスされる、と期待できる場合は、 **allkeys-lru** を使う。 **これは、アクセスパターンが不確かな場合にも良い選択といえる。**
* すべてのキーが継続的にスキャンされるような、周期的なアクセスがある場合、またはアクセスが平均的に分布している(すべてのキーが同じ確率でアクセスされる可能性がある)と期待される場合は、 **allkeys-random** を使う。
* Redis に、有効期限切れとするべき候補を選ぶためのヒントを与えたい場合は、 **volatile-ttl** を使う。キャッシュオブジェクトを生成するときに、異なる TTL を指定する。

.. The **allkeys-lru** and **volatile-random** policies are mainly useful when you want to use a single instance for both caching and to have a set of persistent keys. However it is usually a better idea to run two Redis instances to solve such a problem.

**allkeys-lru** と **volatile-random** ポリシーは、ひとつのインスタンスを、キャッシュ用途と一部キーの永続化用途の、両方の目的で使用する際に有用です。しかし、このような問題に対しては 2 つの Redis インスタンスを使うほうが良い考えでしょう。

.. It is also worth to note that setting an expire to a key costs memory, so using a policy like **allkeys-lru** is more memory efficient since there is no need to set an expire for the key to be evicted under memory pressure.

キーの有効期限を指定するとメモリを消費する、という点に触れておくことには価値があります。 メモリが逼迫している環境では、 **allkeys-lru** のようなポリシーを使用すると、除去対象キーに有効期限を設定しなくても良いため、よりメモリ効率が良くなります。

.. How the eviction process works

エビクション処理の仕組み
==========================

.. It is important to understand that the eviction process works like this:

エビクション処理が以下のように働くことを理解しておくことは大事です:

.. * A client runs a new command, resulting in more data added.
.. * Redis checks the memory usage, and if it is greater than the `maxmemory` limit , it evicts keys according to the policy.
.. * A new command is executed, and so forth.

* クライアントが、データを追加する新規コマンドを発行する
* Redis はメモリ使用量をチェックし、もし 'maxmemory' 制限を超えていたら、ポリシーに従ってキーを除去する
* 新規コマンドが実行される

.. So we continuously cross the boundaries of the memory limit, by going over it, and then by evicting keys to return back under the limits.

このようにして、メモリ制限をチェックし、キーを削除して制限以下まで引き戻す、という操作により、引き続きメモリ制限の境界線上に留まり続けることになります。

.. If a command results in a lot of memory being used (like a big set intersection stored into a new key) for some time the memory limit can be surpassed by a noticeable amount.

もし、あるコマンドが多くのメモリを消費する場合 (たとえば、大きな共通集合操作の結果を新しいキーにセットする) は、しばしば、メモリ使用量が制限を大きく上回ることがあるでしょう。

.. Approximated LRU algorithm

近似的な LRU アルゴリズム
==============================

.. Redis LRU algorithm is not an exact implementation. This means that Redis is
.. not able to pick the *best candidate* for eviction, that is, the access that
.. was accessed the most in the past. Instead it will try to run an approximation
.. of the LRU algorithm, by sampling a small number of keys, and evicting the
.. one that is the best (with the oldest access time) among the sampled keys.

Redis の LRU アルゴリズムは正確な実装ではありません。Redis は除去されるべき *最良の候補*, すなわち最も過去にアクセスされた候補, を選択することはできない、ということです。代わりに、Redis は少数のキーのサンプリングを行い、その中でもっとも古いアクセス時刻をもつものを除去することで、 LRU アルゴリズムの近似を試みます。

.. However since Redis 3.0 (that is currently in beta) the algorithm was improved
.. to also take a pool of good candidates for eviction. This improved the
.. performance of the algorithm, making it able to approximate more closely the
.. behavior of a real LRU algorithm.

しかし、Redis 3.0 (現在 beta ステータス) では、除去に適した候補のプールをもつことで、アルゴリズムが改善されています。これはアルゴリズムの性能を向上させ、より本物の LRU アルゴリズムに近づけます。

.. What is important about the Redis LRU algorithm is that you **are able to tune** the precision of the algorithm by changing the number of samples to check for every eviction. This parameter is controlled by the following configuration directive:

Redis の LRU アルゴリズムで重要なことは、毎回の除去の際にチェックするサンプル数を変更することにより、アルゴリズムの精度を **チューニング可能** ということです。

.. code-block:: none

    maxmemory-samples 5

.. The reason why Redis does not use a true LRU implementation is because it
.. costs more memory. However the approximation is virtually equivalent for the
.. application using Redis. The following is a graphical comparison of how
.. the LRU approximation used by Redis compares with true LRU.

Redis が正確な LRU の実装を使わない理由は、それが多くのメモリを消費するためです。しかし、Redis を使うアプリケーションから見れば、この近似は実際上、本物と同等のものです。下図は、Redis で使用される LRU の近似と、本物の LRU とを視覚的に比較したものです。

.. ![LRU comparison](http://redis.io/images/redisdoc/lru_comparison.png)

.. image:: ./_static/lru_comparison.png
   :alt: LRU comparison 

.. The test to generate the above graphs filled a Redis server with a given number of keys. The keys were accessed from the first to the last, so that the first keys are the best candidates for eviction using an LRU algorithm. Later more 50% of keys are added, in order to force half of the old keys to be evicted.

上記のグラフを生成するため、Redis サーバーをある特定の数のキーでいっぱいにしました。キーは最初から最後まで順にアクセスされており、LRU アルゴリズムによると最初のキーが最良の除去候補になります。その後、半数の古いキーを除去するため、さらに 50% のキーを追加しています。

.. You can see three kind of dots in the graphs, forming three distinct bands.

グラフ中の 3 種類の点は、 3 つの異なる部分を表します。

.. * The light gray band are objects that were evicted.
.. * The gray band are objects that were not evicted.
.. * The green band are objects that were added.

* ライトグレーの部分は、除去されたオブジェクトを表します。
* グレーの部分は、除去されなかったオブジェクトを表します。
* 緑の部分は、追加されたオブジェクトを表します。

.. In a theoretical LRU implementation we expect that, among the old keys, the first half will be expired. The Redis LRU algorithm will instead only *probabilistically* expire the older keys.

理論的な LRU の実装においては、古いキーのうちの最初の半分が除去されることが期待されます。Redis の LRU アルゴリズムはその代わりに、 *確率的に* 古いキーを除去します。

.. As you can see Redis 3.0 does a better job with 5 samples compared to Redis 2.8, however most objects that are among the latest accessed are still retained by Redis 2.8. Using a sample size of 10 in Redis 3.0 the approximation is very close to the theoretical performance of Redis 3.0.

Redis 3.0 は、5 サンプルを使う場合に 2.8 よりも良い結果を出していますが、2.8 においても、最近アクセスされたキーのうちのほとんどは除去されずに残っています。Redis 3.0 でサンプルサイズを 10 個にすると、近似は理論上の性能に非常に近くなります。

.. Note that LRU is just a model to predict how likely a given key will be accessed in the future. Moreover, if your data access pattern closely
.. resembles the power law, most of the accesses will be in the set of keys that
.. the LRU approximated algorithm will be able to handle well.

LRU は、あるキーが将来アクセスされる可能性を予測する、ひとつのモデルにすぎないことに注意してください。加えて、もしあなたのデータアクセスパターンがべき乗則に近いなら、近似 LRU アルゴリズムは大半のアクセスに対してうまく働くでしょう。

.. In simulations we found that using a power law access pattern, the difference between true LRU and Redis approximation were minimal or non-existent.

べき乗則に従うアクセスパターンにおけるシミュレーションにおいては、本物の LRU アルゴリズムと Redis の近似的なアルゴリズムの差異は小さいか、まったく存在しないことが観察されています。

.. However you can raise the sample size to 10 at the cost of some additional CPU
.. usage in order to closely approximate true LRU, and check if this makes a
.. difference in your cache misses rate.

しかし、より正確に LRU を近似するために、いくらか追加の CPU コストと引き換えにサンプルサイズを 10 に引き上げることも可能です。それがキャッシュミス率に影響を及ぼすか、確認してみてください。

.. To experiment in production with different values for the sample size by using
.. the `CONFIG SET maxmemory-samples <count>` command, is very simple.

プロダクション環境で 'CONFIG SET maxmemory-samples <count>' コマンドを使い、異なるサンプルサイズを試してみるのがシンプルな方法です。

