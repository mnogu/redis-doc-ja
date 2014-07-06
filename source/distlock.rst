.. Distributed locks with Redis

==================================
Redis による分散ロック
==================================

.. note:: 
   このドキュメントは `Distributed locks with Redis <http://redis.io/topics/distlock>`_ の翻訳です。
   誤訳を見つけたら `翻訳リポジトリ <https://github.com/mocobeta/redis-doc-ja>`_ に Issue 登録をお願いします。

.. Distributed locks are a very useful primitive in many environments where
.. different processes require to operate with shared resources in a mutually
.. exclusive way.

異なるプロセス同士が、相互に排他的な方法で共有リソースに対して操作を実行する、という環境において、分散ロックは非常に役に立ちます。

.. There are a number of libraries and blog posts describing how to implement
.. a DLM (Distributed Lock Manager, 分散ロックマネージャー) with Redis, but every library use a different
.. approach, and many use a simple approach with lower guarantees compared to
.. what can be achieved with slightly more complex designs.

Redis を使った DLM (Distributed Lock Manager) の実装については、多くのライブラリやブログポストがあります。しかし、ライブラリごとに異なるアプローチがとられており、またその多くは、より複雑なデザインと比較するとシンプルで、そのぶん保証される内容が低いアプローチとなっています。

.. This page is an attempt to provide a more canonical algorithm to implement
.. distributed locks with Redis. We propose an algorithm, called **Redlock**,
.. which implements a DLM which we believe to be safer than the vanilla single
.. instance approach. We hope that the community will analyze it, provide
.. feedbacks, and use it as a starting point for the implementations or more
.. complex or alternative designs.

このページは、Redis 上で分散ロックを実装するにあたり、標準的なアルゴリズムを提供することを目指すものです。私たちはここで **Redlock** と呼ぶアルゴリズムを提供します。これは DLM 実装の一種で、よく見かけるような、ひとつのインスタンスを使うアプローチよりも安全である、と私たちは考えています。コミュニティがこのアプローチを分析し、フィードバックを提供してくれること、さらに、より複雑な、または代替となるデザインを実装する際のスターティング・ポイントとして使われることを希望します。

.. Implementations

実装
=============

.. Before to describe the algorithm, here there are a few links at implementations
.. already available, that can be used as a reference.

アルゴリズムを説明する前に、入手可能な参照実装へのいくつかのリンクを紹介します。

* `Redlock-rb <https://github.com/antirez/redlock-rb>`_ (Ruby implementation).
* `Redlock-php <https://github.com/ronnylt/redlock-php>`_ (PHP implementation).
* `Redsync.go <https://github.com/hjr265/redsync.go>`_ (Go implementation).

.. Safety and Liveness guarantees

安全性(Safety) と 応答性(Liveness) の保証
====================================================

.. We are going to model our design with just three properties, that are from our point of view the minimum guarantees needed to use distributed locks in an effective way.

私たちのデザインは、以下の 3 つの性質からモデル化されます。これらは、私たちの観点では、分散ロックを効率的に使うために最低限必要となる保証です。

.. 1. Safety property: Mutual exclusion. At any given moment, only one client can hold a lock.
.. 2. Liveness property A: Deadlocks free. Eventually it is always possible to acquire a lock, even if the client that locked a resource crashed or gets partitioned.
.. 3. Liveness property B: Fault tolerance. As long as the majority of Redis nodes are up, clients are able to acquire and release locks.

1. 安全性(Safety): 相互に排他的である。どの時点においても、ひとつのクライアントのみがロックを取得できる。
2. 応答性(Liveness) A: デッドロックフリー。ロックを取得したクライアントがクラッシュしたり不通になった場合でも、必ずいつかはロックを取得できる。
3. 応答性(Liveness) B: 障害耐性。Redis ノードの過半数が生きているかぎり、クライアントはロックを取得したり解放したりできる。

.. Why failover based implementations are not enough

なぜ、フェイルオーバー・ベースの実装は十分でないのか
============================================================

.. To understand what we want to improve, let’s analyze the current state of affairs with most Redis-based distributed locks libraries.

私たちが何を改善しようとしているのか理解するため、多くの Redis ベースの分散ロックライブラリの現在の状況を分析しましょう。

.. The simple way to use Redis to lock a resource is to create a key into an instance. The key is usually created with a limited time to live, using Redis expires feature, so that eventually it gets released one way or the other (property 2 in our list). When the client needs to release the resource, it deletes the key.

リソースをロックするために Redis を使うにあたり、シンプルな方法はインスタンスにキーを作ることです。キーには通常、Redisの expire 機能を使って time to live が指定されるため、遅かれ早かれいつかは解放されます(リストの性質 2)。クライアントがリソースを解放するときは、キーを削除します。

.. Superficially this works well, but there is a problem: this is a single point of failure in our architecture. What happens if the Redis master goes down?
.. Well, let’s add a slave! And use it if the master is unavailable. This is unfortunately not viable. By doing so we can’t implement our safety property of the mutual exclusion, because Redis replication is asynchronous.

表面上これはうまく働きますが、問題もあります: アーキテクチャ上、ここが単一障害点になります。Redis マスターがダウンしたときには、何が起こるでしょうか？よろしい、スレーブを追加しよう！そして、マスターが使用不能になったらそちらを使えば良い。不運なことに、これは実行不可能です。Redis のレプリケーションは非同期であるため、相互に排他的である、という安全性が実現できなくなるのです。

.. This is an obvious race condition with this model:

以下が、このモデルを使う場合に発生する明らかな競合状態です:

.. 1. Client A acquires the lock into the master.
.. 2. The master crashes before the write to the key is transmitted to the slave.
.. 3. The slave gets promoted to master.
.. 4. Client B acquires the lock to the same resource A already holds a lock for. **SAFETY VIOLATION!**

1. クライアント A がマスターに対してロックを取得する
2. マスターが、キーの書き込みをスレーブに送信する前にクラッシュする
3. スレーブがマスターに昇格する
4. A がすでにロックを取得しているリソースに対し、クライアント B がロックを取得する。 **安全性違反!**

.. Sometimes it is perfectly fine that under special circumstances, like during a failure, multiple clients can hold the lock at the same time.
.. If this is the case, you can use your replication based solution. Otherwise we suggest to implement the solution described in this document.

障害発生時のような特殊な状況では、複数のクライアントが同時にロックを取得できる、という点が問題にならないこともしばしばあります。もしそうなら、レプリケーション・ベースの解法を使うことができます。そうでなければ、このドキュメントで説明する解決方法を実装することを勧めます。

.. Correct implementation with a single instance

ひとつのインスタンスを使う場合の正しい実装
=============================================

.. Before to try to overcome the limitation of the single instance setup described above, let’s check how to do it correctly in this simple case, since this is actually a viable solution in applications where a race condition from time to time is acceptable, and because locking into a single instance is the foundation we’ll use for the distributed algorithm described here.

上述の、ひとつのインスタンスのみを使う場合の制限を乗り越えようとする前に、このシンプルなケースについての正しいやり方を確認しておきましょう。これは、ときどき発生する競合状態が許容されるアプリケーションにおいては、実際上、可能なソリューションです。また、ひとつのインスタンスに対するロックは、ここで記述するアルゴリズムの基礎をなすものでもあります。

.. To acquire the lock, the way to go is the following:

ロックを取得するための方法は以下です:

.. code-block:: none

        SET resource_name my_random_value NX PX 30000

.. The command will set the key only if it does not already exist (NX option), with an expire of 30000 milliseconds (PX option).
.. The key is set to a value “my_random_value”. This value requires to be unique across all the clients and all the locks requests.

このコマンドは、そのキーがすでに存在しない場合に限り(NX オプション)、30000 ミリ秒の有効期限つきで(PX オプション)キーをセットします。キーには "my_random_value" という値がセットされます。この値は、すべてのクライアント、またすべてのロックリクエストにまたがってユニークであることが求められます。

.. Basically the random value is used in order to release the lock in a safe way, with a script that tells Redis: remove the key only if exists and the value stored at the key is exactly the one I expect to be. This is accomplished by the following Lua script:

基本的に、このランダムな値は、次のようなスクリプトを使いロックを安全に解放するために使われます: 「キーが存在し、かつキーに格納されている値が、自分が期待しているものと正確に一致する場合にかぎり、キーを削除しなさい」。これは以下の Lua スクリプトで実現されます:

.. code-block:: none

    if redis.call("get",KEYS[1]) == ARGV[1] then
        return redis.call("del",KEYS[1])
    else
        return 0
    end

.. This is important in order to avoid removing a lock that was created by another client. For example a client may acquire the lock, get blocked into some operation for longer than the lock validity time (the time at which the key will expire), and later remove the lock, that was already acquired by some other client.
.. Using just DEL is not safe as a client may remove the lock of another client. With the above script instead every lock is “signed” with a random string, so the lock will be removed only if it is still the one that was set by the client trying to remove it.

これは、他のクライアントが作成したロックを削除してしまうことを避けるために重要です。たとえば、あるクライアントがロックを取得し、何らかの操作がロックの有効期間(キーが expire されるまでの期間)よりも長い間ブロックされた後、他のクライアントによるロックを削除するような状況です。単に DEL コマンドを使うのは、他のクライアントが取得したロックを削除してしまう可能性があるため、安全ではありません。上記のスクリプトでは、すべてのロックはランダムな文字列で "サイン済み" であるため、ロックを削除しようとするクライアントによりセットされたものである場合に限り、削除されます。

.. What this random string should be? I assume it’s 20 bytes from /dev/urandom, but you can find cheaper ways to make it unique enough for your tasks.
.. For example a safe pick is to seed RC4 with /dev/urandom, and generate a pseudo random stream from that.
.. A simpler solution is to use a combination of unix time with microseconds resolution, concatenating it with a client ID, it is not as safe, but probably up to the task in most environments.

ランダムな文字列はどのようなものであれば良いでしょうか？私は /dev/urandom の 20 byte を想定していますが、あなたのタスクのために必要十分な、よりコストの低いやり方を見つけられるかもしれません。たとえば、安全なやり方として、RC4の安全なシードを /dev/random から選び、擬似乱数列を生成する方法があります。よりシンプルな解決法としては、ミリ秒精度の Unix 時刻をクライアントIDと結合する、というやり方もあります。これは安全ではありませんが、おそらく多くの環境では十分でしょう。

.. The time we use as the key time to live, is called the “lock validity time”. It is both the auto release time, and the time the client has in order to perform the operation required before another client may be able to acquire the lock again, without technically violating the mutual exclusion guarantee, which is only limited to a given window of time from the moment the lock is acquired.

キーに設定する time to live は、"ロックの有効期間" と呼ばれます。これは、自動的なロック解放までの時間でもあり、他のクライアントがロックを再び取得できるようになるまでの、そのクライアントが操作に使える持ち時間でもあります。ロックが取得されてから、既定のウィンドウ時間内に限り、相互排他の保証が破られることはありません。

.. So now we have a good way to acquire and release the lock. The system, reasoning about a non-distrubited system which is composed of a single instance, always available, is safe. Let’s extend the concept to a distributed system where we don’t have such guarantees.

私たちは、ロックを取得し解放するための、望ましい方法を得ました。常に利用可能なひとつのインスタンスから構成される、非分散システムなら、これで安全です。こうした保証がない分散システムへ、コンセプトを拡張していきましょう。

.. The Redlock algorithm

Redlock アルゴリズム
===============================

.. In the distributed version of the algorithm we assume to have N Redis masters. Those nodes are totally independent, so we don’t use replication or any other implicit coordination system. We already described how to acquire and release the lock safely in a single instance. We give for granted that the algorithm will use this method to acquire and release the lock in a single instance. In our examples we set N=5, which is a reasonable value, so we need to run 5 Redis masters in different computers or virtual machines in order to ensure that they’ll fail in a mostly independent way.

分散環境バージョンのアルゴリズムにおいて、N 個の Redis マスターがあると仮定します。これらのノードは完全に独立しており、レプリケーションやその他の暗黙的な協調システムは想定しません。ひとつのインスタンスに対して、安全にロックを取得、解放する方法についてはすでに説明しました。ここでは、ひとつのインスタンスに対するロックの取得、解放の方式を所与のものとして使用します。ここではひとつの妥当な例として、N=5 を設定します。互いに無関係に障害が発生する状態を確保するため、異なるコンピュータ、または仮想マシン上で稼働する 5 つの Redis マスターが必要になります。

.. In order to acquire the lock, the client performs the following operations:

ロックを取得するため、クライアントは以下の操作を実行します:

.. 1. It gets the current time in milliseconds.
.. 2. It tries to acquire the lock in all the N instances sequentially, using the same key name and random value in all the instances. During the step 2, when setting the lock in each instance, the client uses a timeout which is small compared to the total lock auto-release time in order to acquire it. For example if the auto-release time is 10 seconds, the timeout could be in the ~ 5-50 milliseconds range. This prevents the client to remain blocked for a long time trying to talk with a Redis node which is down: if an instance is not available, we should try to talk with the next instance ASAP.
.. 3. The client computes how much time elapsed in order to acquire the lock, by subtracting to the current time the timestamp obtained in step 1. If and only if the client was able to acquire the lock in the majority of the instances (at least 3), and the total time elapsed to acquire the lock is less than lock validity time, the lock is considered to be acquired.
.. 4. If the lock was acquired, its validity time is considered to be the initial validity time minus the time elapsed, as computed in step 3.
.. 5. If the client failed to acquire the lock for some reason (either it was not able to lock N/2+1 instances or the validity time is negative), it will try to unlock all the instances (even the instances it believe it was not able to lock).

1. 現在時刻を取得します。
2. 同一のキー名とランダム値を使い、全 N インスタンスに対し順番にロックの取得を試みます。ステップ 2 で各インスタンスにロックをセットする際、クライアントは、ロックの自動解放までの時間と比較して十分に小さなタイムアウト値を使います。たとえば自動解放までの時間が 10 秒の場合、タイムアウトは 5 ~ 50 ミリ秒程度の幅になるでしょう。これは、クライアントがダウン中の Redis ノードにアクセスしようとして長い間待たされることを避けるためです: もしあるインスタンスが使用できない場合、なるべく早く、次のインスタンスへのアクセスを試みるようにします。
3. クライアントは、現在時刻からステップ 1 で取得した時刻を引き、ロックを取得するまでにどれだけの時間が経過したかを計算します。インスタンスの過半数(最低 3 以上)に対してロックが得られ、かつロック取得までの総経過時間がロックの有効時間よりも短い場合にかぎり、ロックが取得できたとみなします。
4. ロックが取得できたら、その有効時間は、初期の有効時間からステップ 3 で計算された経過時間を引いた値となります。
5. もしなんらかの理由でロックの取得に失敗したら(N/2+1 個のインスタンスのロックが取得できなかった、もしくは有効時間が負の値となったか、のいずれか)、すべてのインスタンスについてアンロックを行います(ロックが取得できなかったと考えられるインスタンスについても)。

.. Is the algorithm asynchronous?

このアルゴリズムは非同期ですか？
========================================

.. The algorithm relies on the assumption that while there is no synchronized clock across the processes, still the local time in every process flows approximately at the same rate, with an error which is small compared to the auto-release time of the lock. This assumption closely resembles a real-world computer: every computer has a local clock and we can usually rely on different computers to have a clock drift which is small.

このアルゴリズムは、プロセス間で時刻の同期はされないけれども、全プロセスのローカル時間が近似的に同じレートで動いている(ロックの自動解放時間と比較すると十分に小さなエラーを含みつつ)、という仮定をおいています。この仮定は、実世界のコンピューター環境とよく似ています: すべてのコンピューターはローカルなクロックを持ち、通常においては、異なるコンピューター間のクロック・ドリフトは小さいとみなして良い。

.. At this point we need to better specifiy our mutual exclusion rule: it is guaranteed only as long as the client holding the lock will terminate its work within the lock validity time (as obtained in step 3), minus some time (just a few milliseconds in order to compensate for clock drift between processes).

この観点から、私たちの相互排他のルールについてより詳細にしておく必要があります: 相互排他のルールは、ロックを保持しているクライアントが、ロックの有効時間(ステップ 3 で得られたもの)からさらに若干の時間(プロセス間のクロック・ドリフトを補正するための数ミリ秒)を差し引いた時間の間で、処理を完了させるかぎりにおいて保証される。

.. For more information about similar systems requiring a bound *clock drift*, this paper is an interesting reference: [Leases: an efficient fault-tolerant mechanism for distributed file cache consistency](http://dl.acm.org/citation.cfm?id=74870).

*クロック・ドリフト* がある範囲内に抑えられていることを要求する、同様のシステムについてより詳しい情報としては、次の興味深い論文があります: `Leases: an efficient fault-tolerant mechanism for distributed file cache consistency <http://dl.acm.org/citation.cfm?id=74870>`_

.. Retry on failure

失敗時のリトライ
==========================

.. When a client is not able to acquire the lock, it should try again after a random delay in order to try to desynchronize multiple clients trying to acquire the lock, for the same resource, at the same time (this may result in a split brain condition where nobody wins). Also the faster a client will try to acquire the lock in the majority of Redis instances, the less window for a split brain condition (and the need for a retry), so ideally the client should try to send the SET commands to the N instances at the same time using multiplexing.

クライアントがロックを取得できなかった場合、同じリソースに対して同時にロックの取得を試みるクライアント同士でタイミングをずらすため(誰もロックを取得できないスプリット・ブレーン状態につながる)、あるランダムな待ち時間を入れた後に再度ロックの取得を試みなければなりません。クライアントが Redis インスタンスの過半数のロックを取得するのが速くなるほど、スプリット・ブレーン状態(これが発生するとリトライが必要となる)を避けるためのウィンドウは小さくて済みます。理想としては、クライアントは N インスタンスに対して、多重化を使って SET コマンドを送信すべきです。

.. It is worth to stress how important is for the clients that failed to acquire the majority of locks, to release the (partially) acquired locks ASAP, so that there is no need to wait for keys expiry in order for the lock to be acquired again (however if a network partition happens and the client is no longer able to communicate with the Redis instances, there is to pay an availability penalty and wait for the expires).

クライアントが過半数のロックを取得するのに失敗した場合、(部分的に)取得したロックをできるだけ速やかに解放することは、非常に重要です。そうすることで、次にロックが取得されるまでにキーの expire を待たなくても良くなります(ただし、ネットワーク分断が発生した場合は、クライアントは Redis インスタンスと通信ができなくなるため、可用性の面でペナルティが発生し、expire を待つことになります)。

.. Releasing the lock

ロックの解放
====================

.. Releasing the lock is simple and involves just to release the lock in all the instances, regardless of the fact the client believe it was able to successfully lock a given instance.

ロックの解放は、シンプルに、すべてのインスタンスに対して、(クライアントがそのインスタンスに対してロックを取得できたかどうかに関わらず)ロックを解放することで行います。

.. Safety arguments

安全性についての議論
=========================

.. Is the algorithm safe? We can try to understand what happens in different scenarios.

このアルゴリズムは安全でしょうか？いくつかの異なるシナリオにおいて、どのような状況が発生するか、推測することができます。

.. To start let’s assume that a client is able to acquire the lock in the majority of instances. All the instances will contain a key with the same time to live. However the key was set at different times, so the keys will also expire at different times. However if the first key was set at worst at time T1 (the time we sample before contacting the first server) and the last key was set at worst at time T2 (the time we obtained the reply from the last server), we are sure that the first key to expire in the set will exist for at least `MIN_VALIDITY=TTL-(T2-T1)-CLOCK_DRIFT`. All the other keys will expire later, so we are sure that the keys will be simultaneously set for at least this time.

クライアントが、過半数のインスタンスに対してロックを取得できたと仮定しましょう。すべてのインスタンスは、同じ time to live が設定されたキーを保持します。しかしキーは異なる時刻にセットされるため、異なる時刻に expire されます。もし最初のキーが最悪でも時刻 T1 にセットされ(最初のサーバーにアクセスする前に取得しておく)、最後のキーが最悪でも時刻 T2 にセットされる(最後のサーバーからの応答時刻から得られる)なら、最初のキーは最小で 'MIN_VALIDITY=TTL-(T2-T1)-CLOCK_DRIFT' の期間存在した後に expire される、と確信できます。その他のすべてのキーはその後に expire されるため、最低でもこの期間はキーが同時にセットされた状態である、といえます。

.. During the time the majority of keys are set, another client will not be able to acquire the lock, since N/2+1 SET NX operations can’t succeed if N/2+1 keys already exist. So if a lock was acquired, it is not possible to re-acquire it at the same time (violating the mutual exclusion property).

過半数のキーがセットされている間、他のクライアントはロックを取得することができません。N/2+1 個の SET NX 操作は、N/2+1 個のキーがすでに存在していると成功しないためです。したがって、あるロックが取得されたら、同時に再取得(相互排他性に違反)することは不可能です。

.. However we want to also make sure that multiple clients trying to acquire the lock at the same time can’t simultaneously succeed.

さらに私たちは、複数のクライアントが同じタイミングでロックの取得を試みた場合に、同時に成功することがない、ということを確信できなければなりません。

.. If a client locked the majority of instances using a time near, or greater, than the lock maximum validity time (the TTL we use for SET basically), it will consider the lock invalid and will unlock the instances, so we only need to consider the case where a client was able to lock the majority of instances in a time which is less than the validity time. In this case for the argument already expressed above, for `MIN_VALIDITY` no client should be able to re-acquire the lock. So multiple clients will be albe to lock N/2+1 instances at the same time (with “time" being the end of Step 2) only when the time to lock the majority was greater than the TTL time, making the lock invalid.

クライアントが過半数のインスタンスのロックを取得するまでに、ロックの最大有効時間(SET 時の TTL)と同じかそれよりも長い時間がかかった場合、ロックは無効とみなされ、アンロックされます。したがって考慮する必要があるのは、クライアントが、過半数のインスタンスのロックを、有効時間内で取得できた場合のみです。この場合、前述の議論のとおり、'MIN_VALIDITY' の期間内はどのクライアントもロックを再取得できません。ロックを取得するまでにかかった時間が TTL よりも長い場合にかぎり、複数のクライアントが N/2+1 個のインスタンスを同時に(ステップ 2 の最後の時刻)ロックできますが、このときロックは無効になっています。

.. Are you able to provide a formal proof of safety, point out to existing algorithms that are similar enough, or to find a bug? That would be very appreciated.

類似する既存のアルゴリズムの観点から、安全性について形式的な証明が与えられるでしょうか。または、バグを見つけられるでしょうか？そうした指摘をとても歓迎します。

.. Liveness arguments

応答性についての議論
================================

.. The system liveness is based on three main features:

システムの応答性は、3 つの主要な特徴に基づきます:

.. 1. The auto release of the lock (since keys expire): eventually keys are available again to be locked.
.. 2. The fact that clients, usually, will cooperate removing the locks when the lock was not acquired, or when the lock was acquired and the work terminated, making it likely that we don’t have to wait for keys to expire to re-acquire the lock.
.. 3. The fact that when a client needs to retry a lock, it waits a time which is comparable greater to the time needed to acquire the majority of locks, in order to probabilistically make split brain conditions during resource contention unlikely.

1. (キーの expire による)ロックの自動解放: いずれは、キーは再ロック可能になる。
2. クライアントは通常において、ロックが取得できなかった場合、および仕事が完了した場合はロックを削除するよう、協調して動作する。それにより、ロックの再取得にあたりキーの expire を待つ必要がなくなる。
3. クライアントはロックに際してリトライが必要な場合、過半数のロック取得にかかるよりも長く、待ち時間を入れる。リソースの競合によるスプリット・ブレーン状態を確率的に抑えるため。

.. However we pay an availability penalty equal to “TTL” time on network partitions, so if there are continuous partitions, we can pay this penalty indefinitely.
.. This happens every time a client acquires a lock and gets partitioned away before being able to remove the lock.

しかし、ネットワーク分断時には "TTL" に相当する時間だけ、可用性に対してペナルティが発生します。ネットワーク分断が継続する場合、永久にこのペナルティを受け続けることになります。

.. Basically if there are infinite continuous network partitions, the system may become not available for an infinite amount of time.

基本的に、永続的なネットワーク分断が発生する場合、システムは永久に利用不可能となります。

.. Performance, crash-recovery and fsync

性能、クラッシュリカバリ、fsync
======================================

.. Many users using Redis as a lock server need high performance in terms of both latency to acquire and release a lock, and number of acquire / release operations that it is possible to perform per second. In order to meet this requirement, the strategy to talk with the N Redis servers to reduce latency is definitely multiplexing (or poor’s man multiplexing, which is, putting the socket in non-blocking mode, send all the commands, and read all the commands later, assuming that the RTT between the client and each instance is similar).

Redis をロックサーバーとして使う多くのユーザーは、ロックの取得解放にかかるレイテンシと、秒間に実行可能な取得/解放オペレーション数の両面において、高い性能を必要とします。要求に応えるため、N 個の Redis サーバーとの通信に要するレイテンシを削減する戦略は、明らかに通信の多重化(貧者の多重化、すなわち、ソケットをノンブロッキング・モードで使い、すべてのコマンドを一度に送り、すべての返信を一度に読む。ここでクライアントと、それぞれのインスタンスとの RTT は同等と仮定)です。

.. However there is another consideration to do about persistence if we want to target a crash-recovery system model.

クラッシュリカバリを考慮する場合、永続化の面で別の考慮が必要になります。

.. Basically to see the problem here, let’s assume we configure Redis without persistence at all. A client acquires the lock in 3 of 5 instances. One of the instances where the client was able to acquire the lock is restarted, at this point there are again 3 instances that we can lock for the same resource, and another client can lock it again, violating the safety property of exclusivity of lock.

問題を検討するため、Redis を一切永続化しない設定で稼働させると仮定してみましょう。あるクライアントが、5 インスタンスのうち 3 つのロックを取得したとします。クライアントがロックを取得したインスタンスのうち、ひとつが再起動した場合、同じリソースに対して、再び 3 つのインスタンスがロック可能となります。結果として、他のクライアントがロックを取得することが可能になり、ロックの排他制御による安全性が侵害されます。

.. If we enable AOF persistence, things will improve quite a bit. For example we can upgrade a server by sending SHUTDOWN and restarting it. Because Redis expires are semantically implemented so that virtually the time still elapses when the server is off, all our requirements are fine.
.. However everything is fine as long as it is a clean shutdown. What about a power outage? If Redis is configured, as by default, to fsync on disk every second, it is possible that after a restart our key is missing. In theory, if we want to guarantee the lock safety in the face of any kind of instance restart, we need to enable fsync=always in the persistence setting. This in turn will totally ruin performances to the same level of CP systems that are traditionally used to implement distributed locks in a safe way.

もし AOF による永続化を有効にしている場合、状況は少し改善されます。たとえば、サーバーをアップグレードするために SHUTDOWN コマンドを送り、再起動する場合です。Redis の expire は意味的に正しく実装されており、サーバーが停止している間も実際上の時間が経過しているため、要件はすべて満たされます。しかし、問題が発生しないのはクリーンシャットダウンが行われた場合に限ります。電源が落ちたらどうなるでしょう？もし Redis がディスクに毎秒 fsync するよう設定されている(デフォルト)場合、再起動後にキーが失われている可能性があります。理屈上、どのようなインスタンスの再起動が発生してもロックの安全性を担保したい場合、永続化の設定において fsync=always を有効にしておく必要があります。これは、安全な分散ロックを実装するために、昔から CP システムで使われてきたのと同じレベルであり、全体的に性能を損ないます。

.. However things are better than what they look like at a first glance. Basically
.. the algorithm safety is retained as long as when an instance restarts after a
.. crash, it no longer participates to any **currently active** lock, so that the
.. set of currently active locks when the instance restarts, were all obtained
.. by locking instances other than the one which is rejoining the system.

しかしながら、状況は一見したよりはいくぶんか良いものです。基本的に、アルゴリズムの安全性は、インスタンスがクラッシュから再起動したときに、 **その時点でアクティブな** ロックを保持していないかぎり保たれます。アクティブなロックは、システムに再ジョインしたインスタンス以外のインスタンスをロックすることで確保されています。

.. To guarantee this we just need to make an instance, after a crash, unavailable
.. for at least a bit more than the max `TTL` we use, which is, the time needed
.. for all the keys about the locks that existed when the instance crashed, to
.. become invalid and be automatically released.

このことを保証するために、インスタンスのクラッシュ後は、最低でも、使っている最大の TTL よりも長い時間だけ利用できないようにしておく必要があります。すなわち、インスタンスがクラッシュした時点で保持しているロックキーがすべて無効となり、自動的に解放されるまでに必要とする時間です。

.. Using *delayed restarts* it is basically possible to achieve safety even
.. without any kind of Redis persistence available, however note that this may
.. translate into an availability penalty. For example if a majority of instances
.. crash, the system will become gobally unavailable for `TTL` (here globally means
.. that no resource at all will be lockable during this time).

*遅延リスタート* を使うことで、いずれの Redis 永続化方式を使うかに関わらず安全性は達成されますが、これは可用性のペナルティにつながることに留意してください。たとえば、インスタンスの過半数がクラッシュしたら、システムは全体的に TTL の期間中は利用不可能になります(ここで、全体的に、とは、この期間中どんなリソースもロックできなくなることを意味します)。

.. Making the algorithm more reliable: Extending the lock

アルゴリズムの信頼性を向上させる: ロックの拡張
=======================================================

.. If the work performed by clients is composed of small steps, it is possible to
.. use smaller lock validity times by default, and extend the algorithm implementing
.. a lock extension mechanism. Basically the client, if in the middle of the
.. computation while the lock validity is approaching a low value, may extend the
.. lock by sending a Lua script to all the instances that extends the TTL of the key
.. if the key exists and its value is still the random value the client assigned
.. when the lock was acquired.

クライアントの仕事が小さなステップから構成される場合、ロック有効時間の初期値としては小さな値を使い、ロック延長のメカニズムを実装するようにアルゴリズムを拡張できます。大筋としては次のようになります。処理の途中でロックの有効時間が小さくなってきたら、クライアントはすべてのインスタンスに Lua スクリプトを送信し、キーの TTL 延長を指示します。ただし、キーが存在し、かつその値が、クライアントがロックを取得した時点のランダム値から変更されていない場合に限ります。

.. The client should only consider the lock re-acquired if it was albe to extend
.. the lock into the majority of instances, and within the validity time
.. (basically the algorithm to use is very similar to the one used when acquiring
.. the lock).

クライアントは、インスタンスの過半数に対して、有効時間内にロックの延長ができた場合のみ、ロックが再取得できたと考えるべきです(基本的なアルゴリズムは、ロックの取得時に使うものとよく似ています)。

.. However this does not technically change the algorithm, so anyway the max number
.. of locks reacquiring attempts should be limited, otherwise one of the liveness
.. properties is violated.

これは、アルゴリズムを技術的に変更するものではないですが、いずれにしても、ロックを再取得する最大回数は制限されるべきです。そうしない場合、応答性のひとつが侵害されることになります。

.. Want to help?

助けが必要ですか？
=========================

.. If you are into distributed systems, it would be great to have your opinion / analysis. Also reference implementations in other languages could be great.

分散システムに興味があるなら、あなた自身の意見や分析をもつことは素晴らしいことです。また、他の言語による参照実装も歓迎です。

Thanks in advance!
