===================
Memory optimization
===================

.. note:: 
   このドキュメントは `Memory optimization <http://redis.io/topics/memory-optimization>`_ の翻訳です。
   誤訳を見つけたら `翻訳リポジトリ <https://github.com/mocobeta/redis-doc-ja>`_ に Issue を登録してください。

.. This page is a work in progress. Currently it is just a list of things you should check if you have problems with memory.

このページは作業中です。現在のところ、メモリに関する問題が発生したときにチェックするべき項目のリストにすぎません。

.. Special encoding of small aggregate data types

小さな集約データ型のための特別なエンコーディング
========================================================

.. Since Redis 2.2 many data types are optimized to use less space up to a certain size. Hashes, Lists, Sets composed of just integers, and Sorted Sets, when smaller than a given number of elements, and up to a maximum element size, are encoded in a very memory efficient way that uses *up to 10 times less memory* (with 5 time less memory used being the average saving).

Redis 2.2 以降、多くのデータ型は、ある一定のサイズ以下であれば、使用する空間が小さくなるように最適化がされています。Hash, List, 整数型からなる Set, および Sorted Set は、既定の上限より要素数が小さく、かつ個々の要素のサイズが上限を超えない場合は、非常にメモリ効率の良い方法でエンコードされます。このエンコーディングにより、メモリ使用量は *最大で 10 分の 1* 、平均で 5 分の 1 程度に削減されます。

.. This is completely transparent from the point of view of the user and API.
.. Since this is a CPU / memory trade off it is possible to tune the maximum number of elements and maximum element size for special encoded types using the following redis.conf directives.

これは、ユーザーやAPIからは完全に隠蔽されます。また、CPU とメモリのトレードオフとなるため、エンコードを適用する最大要素数や各要素の最大サイズは redis.conf の以下の設定によりチューニングが可能です。

.. code-block:: none

    hash-max-zipmap-entries 64 (hash-max-ziplist-entries for Redis >= 2.6)
    hash-max-zipmap-value 512  (hash-max-ziplist-value for Redis >= 2.6)
    list-max-ziplist-entries 512
    list-max-ziplist-value 64
    zset-max-ziplist-entries 128
    zset-max-ziplist-value 64
    set-max-intset-entries 512

.. If a specially encoded value will overflow the configured max size, Redis will automatically convert it into normal encoding. This operation is very fast for small values, but if you change the setting in order to use specially encoded values for much larger aggregate types the suggestion is to run some benchmark and test to check the conversion time.

特別にエンコードされた値が、設定された最大値をオーバーすると、Redis は自動的にそれらを通常のエンコーディングに変換します。この操作は小さな値に対しては非常に高速ですが、より大きな値に対して特別エンコーディングを適用するために、設定値をデフォルトから変更する場合は、ベンチマークをとり変換にかかる時間を確認しておくと良いでしょう。

.. Using 32 bit instances

32 bit インスタンスを使用する
==================================

.. Redis compiled with 32 bit target uses a lot less memory per key, since pointers are small, but such an instance will be limited to 4 GB of maximum memory usage. To compile Redis as 32 bit binary use *make 32bit*. RDB and AOF files are compatible between 32 bit and 64 bit instances (and between little and big endian of course) so you can switch from 32 to 64 bit, or the contrary, without problems.

32 bit アーキテクチャ向けにコンパイルされた Redis は、ポインタサイズが小さいためメモリ消費も少ないですが、最大メモリサイズが 4 GB までに制限されます。32 bit バイナリとして Redis をコンパイルするには *make 32bit* を指定してください。RDB および AOF ファイルは 32bit, 64 bit (もちろん、リトルエンディアン・ビッグエンディアンでも) で互換なため、32 bit から 64 bit (またはその逆) への切り替えは問題なく行えます。

.. Bit and byte level operations

Bit および Byte レベルの操作
==================================

.. Redis 2.2 introduced new bit and byte level operations: `GETRANGE`, `SETRANGE`, `GETBIT` and `SETBIT`. Using this commands you can treat the Redis string type as a random access array. For instance if you have an application where users are identified by an unique progressive integer number, you can use a bitmap in order to save information about sex of users, setting the bit for females and clearing it for males, or the other way around. With 100 millions of users this data will take just 12 megabyte of RAM in a Redis instance. You can do the same using `GETRANGE` and `SETRANGE` in order to store one byte of information for user. This is just an example but it is actually possible to model a number of problems in very little space with this new primitives.

Redis 2.2 から、bit および byte レベルを扱う新しい操作が導入されました: `GETRANGE <http://redis.io/commands/getrange>`_, `SETRANGE <http://redis.io/commands/setrange>`_, `GETBIT <http://redis.io/commands/getbit>`_, `SETBIT <http://redis.io/commands/setbit>`_ これらのコマンドを利用することで、String 型をランダムアクセス可能な配列として扱うことができます。たとえばあなたが、ユーザーをユニークな整数値で識別するアプリケーションを扱う場合、ユーザーの性別情報を保持する bitmap を使うことができます。女性なら bit をセット、男性ならクリアする、というように。こうすることで、1 億ユーザーの情報は、たかだか 1 Redis インスタンス中の 12 MB に収まります。同様に、ユーザあたり 1 byte で表現される情報を `GETRANGE <http://redis.io/commands/getrange>`_ と `SETRANGE <http://redis.io/commands/setrange>`_ を使って保存することができます。これは単なる例ですが、この非常に省スペースで新しいプリミティブ値を使って、多くの問題を設計することが可能です。

.. Use hashes when possible

なるべく Hash を使う
===========================

.. Small hashes are encoded in a very small space, so you should try representing your data using hashes every time it is possible. For instance if you have objects representing users in a web application, instead of using different keys for name, surname, email, password, use a single hash with all the required fields.

小さな Hash は非常に省スペースなやり方でエンコードされるため、可能なら Hash を使ってデータを表現すべきです。たとえばあなたが Web アプリケーションのユーザーを表現するオブジェクトを扱うとき、名前、姓、Eメール、パスワード、に別々のキーを割り当てる代わりに、必要なすべてのフィールドを定義したひとつの Hash を使ってください。

.. If you want to know more about this, read the next section.

もし上記についてより詳しく知りたいなら、次の節を読んでください。

.. Using hashes to abstract a very memory efficient plain key-value store on top of Redis

Hash を使って、メモリ効率の高い、抽象化されたキー・バリューストアを Redis 上に構築する
==============================================================================================

.. I understand the title of this section is a bit scaring, but I'm going to explain in details what this is about.

この節のタイトルはぞっとしないものですが、詳しく説明していきます。

.. Basically it is possible to model a plain key-value store using Redis
.. where values can just be just strings, that is not just more memory efficient
.. than Redis plain keys but also much more memory efficient than memcached.

簡単にいえば、バリューがただの String であるとき、普通の Redis キーのみならず memcached よりもメモリ効率の良いキー・バリューストアを Redis 上に構築できる、というものです。

.. Let's start with some fact: a few keys use a lot more memory than a single key
.. containing a hash with a few fields. How is this possible? We use a trick.
.. In theory in order to guarantee that we perform lookups in constant time
.. (also known as O(1) in big O notation) there is the need to use a data structure
.. with a constant time complexity in the average case, like a hash table.

ある事実から始めましょう: いくつかのキーは、いくつかのフィールドをもつ Hash を保持するひとつのキーよりも、多くのメモリを必要とします。どうしてそうようなことが起こるのでしょうか？私たちはあるトリックを使っています。理論上、定数時間でのルックアップを保証するためには(ビッグ・オー記法でいう O(1) として知られる)、ハッシュテーブルのように、平均的に定数時間の計算量をもつデータ構造が必要です。

.. But many times hashes contain just a few fields. When hashes are small we can
.. instead just encode them in an O(N) data structure, like a linear
.. array with length-prefixed key value pairs. Since we do this only when N
.. is small, the amortized time for HGET and HSET commands is still O(1): the
.. hash will be converted into a real hash table as soon as the number of elements
.. it contains will grow too much (you can configure the limit in redis.conf).

しかし、しばしば Hash は少数のフィールドしか含みません。Hash が小さいときは、線形配列のように、長さが固定されたキー・バリューのペアからなる O(N) データ構造にエンコードすることができます。これは、HGET と HSET コマンドのならし計算時間が O(1) に収まる程度に N が小さい場合に限り行われます: Hash に含まれる要素数が大きくなりすぎたら(上限は redis.conf で設定できます)、Hash は即座に本物のハッシュテーブルに変換されます。

.. This does not work well just from the point of view of time complexity, but
.. also from the point of view of constant times, since a linear array of key
.. value pairs happens to play very well with the CPU cache (it has a better
.. cache locality than a hash table).

これは、時間計算量の観点からだけでなく、定数時間という観点からも有効です。バリューペアの線形配列は、CPU キャッシュとの相性が非常に良いためです(ハッシュテーブルよりもキャッシュの局所性が良い)。

.. However since hash fields and values are not (always) represented as full
.. featured Redis objects, hash fields can't have an associated time to live
.. (expire) like a real key, and can only contain a string. But we are okay with
.. this, this was anyway the intention when the hash data type API was
.. designed (we trust simplicity more than features, so nested data structures
.. are not allowed, as expires of single fields are not allowed).

しかしながら、Hash のフィールドと値はフル機能を備えた Redis オブジェクトではないため、Hash のフィールドは本物のキーのような time to live (expire) をもたず、また値として String しか持つことができません。これは Hash 型の API 設計において意図されたものであり、私たちはこれで良しとしています(私たちは、機能よりシンプルさを信頼しており、個々のフィールドの expire を考慮しないと同様に、ネストしたデータ構造を考慮していません)。

.. So hashes are memory efficient. This is very useful when using hashes
.. to represent objects or to model other problems when there are group of
.. related fields. But what about if we have a plain key value business?

なるほど、Hash のメモリ効率は良い。関連のあるフィールドのまとまりがある場合には、オブジェクトを表現したり、モデリングするのには非常に便利でしょう。しかし、シンプルなキー・バリューを扱う場合はどうでしょう？

.. Imagine we want to use Redis as a cache for many small objects, that can be
.. JSON encoded objects, small HTML fragments, simple key -> boolean values
.. and so forth. Basically anything is a string -> string map with small keys
.. and values.

JSON エンコードされたオブジェクトや HTML フラグメント、単純なキーとブール値のペア、その他、沢山の小さなオブジェクトをキャッシュするのに Redis を使うことを考えてください。なんであれ基本的には小さなキーと小さな値からなる、String から String へのマップに集約されます。

.. Now let's assume the objects we want to cache are numbered, like:

私たちがキャッシュしたいオブジェクトが、以下のように番号づけされているとしましょう:

* object:102393
* object:1234
* object:5

.. This is what we can do. Every time there is to perform a
.. SET operation to set a new value, we actually split the key into two parts,
.. one used as a key, and used as field name for the hash. For instance the
.. object named "object:1234" is actually split into:

私たちができるのは次のようなことです。新しい値をセットするための SET 操作が実行される都度、キーを 2 つに分解します。片方はキーとして使い、もう片方は Hash のフィールド名として使います。たとえば、"object:1234" という名前のオブジェクトは、以下のように分解されます:

* object:12 という名前のキー
* 34 という名前のフィールド

.. So we use all the characters but the latest two for the key, and the final
.. two characters for the hash field name. To set our key we use the following
.. command:

すべての文字を使いますが、最後のパートの 2 文字はキー、末尾の 2 文字は Hash フィールド名になります。キーをセットするため、以下のコマンドを発行します:

.. code-block:: none

    HSET object:12 34 somevalue

.. As you can see every hash will end containing 100 fields, that
.. is an optimal compromise between CPU and memory saved.

すぐにわかるように、すべての Hash は、最終的には 100 個のフィールドを含むようになり、これは CPU とメモリ節減の最適な折衷ラインです。

.. There is another very important thing to note, with this schema
.. every hash will have more or
.. less 100 fields regardless of the number of objects we cached. This is since
.. our objects will always end with a number, and not a random string. In some
.. way the final number can be considered as a form of implicit pre-sharding.

このスキーマに則ると、キャッシュされるオブジェクトが全部でいくつあるかに関わらず、各 Hash はおおよそ 100 個のフィールドを含む、というのはもうひとつの注目すべき点です。これは、オブジェクト名が常に、ランダムな文字列ではなく数字で終わるためです。ある意味、最後の数字は暗黙的な pre-sharding の一種とみなすことができます。

.. What about small numbers? Like object:2? We handle this case using just
.. "object:" as a key name, and the whole number as the hash field name.
.. So object:2 and object:10 will both end inside the key "object:", but one
.. as field name "2" and one as "10".

小さな数字についてはどうでしょう？ object:2 のような？ このケースは、"object:" をキーとして使い、数字部分をすべて Hash のフィールド名として使うことで対応できます。つまり、 object:2 と object:10 は両方とも "object:" というキーに含まれ、一方は "2", もう一方は "10" というフィールド名で参照されます。

.. How much memory we save this way?

この方針で、どれくらいのメモリを節約できるでしょう？

.. I used the following Ruby program to test how this works:

以下の Ruby プログラムを使ってテストを行いました:

.. code-block:: ruby

    require 'rubygems'
    require 'redis'

    UseOptimization = true

    def hash_get_key_field(key)
        s = key.split(":")
        if s[1].length > 2
            {:key => s[0]+":"+s[1][0..-3], :field => s[1][-2..-1]}
        else
            {:key => s[0]+":", :field => s[1]}
        end
    end

    def hash_set(r,key,value)
        kf = hash_get_key_field(key)
        r.hset(kf[:key],kf[:field],value)
    end

    def hash_get(r,key,value)
        kf = hash_get_key_field(key)
        r.hget(kf[:key],kf[:field],value)
    end

    r = Redis.new
    (0..100000).each{|id|
        key = "object:#{id}"
        if UseOptimization
            hash_set(r,key,"val")
        else
            r.set(key,"val")
        end
    }

.. This is the result against a 64 bit instance of Redis 2.2:

これは Redis 2.2 64 bit インスタンスで実行した際の結果です。

 * UseOptimization set to true: 1.7 MB of used memory
 * UseOptimization set to false; 11 MB of used memory

.. This is an order of magnitude, I think this makes Redis more or less the most
.. memory efficient plain key value store out there.

1 桁分の違いがあります。これにより、Redis は事実上もっともメモリ効率の良いキー・バリューストアであるといえます。

.. *WARNING*: for this to work, make sure that in your redis.conf you have
.. something like this:

*注意* : これが機能するためには、redis.conf が、たとえば次のように設定されていることを確認しておいてください。

.. code-block:: none

    hash-max-zipmap-entries 256

.. Also remember to set the following field accordingly to the maximum size
.. of your keys and values:

また同様に、キーと値の最大長に応じて、以下のフィールドも忘れずに設定してください。

.. code-block:: none

    hash-max-zipmap-value 1024

.. Every time a hash will exceed the number of elements or element size specified
.. it will be converted into a real hash table, and the memory saving will be lost.

Hash は指定された最大要素数、または最大要素サイズを超えると、本物のハッシュテーブルに変換され、メモリ節減の効果は失われます。

.. You may ask, why don't you do this implicitly in the normal key space so that
.. I don't have to care? There are two reasons: one is that we tend to make
.. trade offs explicit, and this is a clear tradeoff between many things: CPU,
.. memory, max element size. The second is that the top level key space must
.. support a lot of interesting things like expires, LRU data, and so
.. forth so it is not practical to do this in a general way.

キー・スペース内で暗黙的にやってくれたら、ユーザーが考える必要がなくなるのに、なぜそうしないのか？と疑問に思うかもしれません。それには 2 つの理由があります: ひとつは、トレードオフを明確にするためです。ここには CPU, メモリ, 最大要素数, の間にはっきりとしたトレードオフがあります。ふたつめは、トップレベルのキー・スペースには Expire や LRU データ、その他諸々といった、サポートしなければならない多くの関心事項があるためです。一般にこのやり方に対応するのは現実的ではありません。

.. But the Redis Way is that the user must understand how things work so that
.. he is able to pick the best compromise, and to understand how the system will
.. behave exactly.

Redis のやり方は、ユーザーは物事の仕組みを知るべきだ、というものです。そうすることで、ユーザーは最良の妥協策を選択でき、またシステムがどのように振る舞うかについて正確に理解することができるでしょう。

.. Memory allocation

メモリ割り当て
==================

.. To store user keys, Redis allocates at most as much memory as the `maxmemory`
.. setting enables (however there are small extra allocations possible).

ユーザーのキーを保存するために、Redis は最大で 'maxmemory' 設定が許す限りのメモリを割り当てます(いくぶんかの追加割り当ても可能ですが)。

.. The exact value can be set in the configuration file or set later via
.. `CONFIG SET` (see [Using memory as an LRU cache for more info](http://redis.io/topics/lru-cache)). There are a few things that should be noted about how
.. Redis manages memory:

正確な値は、設定ファイルに記述するか、または `CONFIG SET <http://redis.io/commands/config-set>`_ で後から設定することも可能です(`Using Redis as an LRU cache <http://redis.io/topics/lru-cache>`_ も参照してください)。Redis がどのようにメモリ管理をしているか、いくつか注意すべき点があります:

.. * Redis will not always free up (return) memory to the OS when keys are removed.
.. This is not something special about Redis, but it is how most malloc() implementations work. For example if you fill an instance with 5GB worth of data, and then
.. remove the equivalent of 2GB of data, the Resident Set Size (also known as
.. the RSS, which is the number of memory pages consumed by the process)
.. will probably still be around 5GB, even if Redis will claim that the user
.. memory is around 3GB.  This happens because the underlying allocator can't easily release the memory. For example often most of the removed keys were allocated in the same pages as the other keys that still exist.
.. * The previous point means that you need to provision memory based on your
.. **peak memory usage**. If your workload from time to time requires 10GB, even if
.. most of the times 5GB could do, you need to provision for 10GB.
.. * However allocators are smart and are able to reuse free chunks of memory,
.. so after you freed 2GB of your 5GB data set, when you start adding more keys
.. again, you'll see the RSS (Resident Set Size) to stay steady and don't grow
.. more, as you add up to 2GB of additional keys. The allocator is basically
.. trying to reuse the 2GB of memory previously (logically) freed.
.. * Because of all this, the fragmentation ratio is not reliable when you
.. had a memory usage that at peak is much larger than the currently used memory.
.. The fragmentation is calculated as the amount of memory currently in use
.. (as the sum of all the allocations performed by Redis) divided by the physical
.. memory actually used (the RSS value). Because the RSS reflects the peak memory,
.. when the (virtually) used memory is low since a lot of keys / values were
.. freed, but the RSS is high, the ration `mem_used / RSS` will be very high.

* Redis は、キーが削除されたとき、常にメモリを開放して OS に返すわけではありません。これは Redis に限った話ではなく、ほとんどの malloc() の実装がそうなっているためです。たとえば、5GB のデータでインスタンスをいっぱいにし、その後 2GB に相当するデータを削除したとき、Resident Set Size (プロセスによって消費されているメモリページ数。RSS とも言われる) はまだ 5GB 程度のままでしょう。Redis がユーザーメモリは 3GB であると主張しているとしても、です。これは下層の allocator が簡単にはメモリを解放できないために起こります。たとえば、まだ存在しているキーと同じページ上にある、すでに削除されたキーの大部分は割りつけられたままです。
* 上述の点は、 **ピークメモリ使用量** に基づいてメモリを用意しておく必要がある、ということを意味します。もしあなたのワークロードが時々 10GB を要求するなら、たとえほとんどの期間では 5GB しか必要としないとしても、10GB を準備しておく必要があります。
* しかし、allocator は賢く、解放されたメモリのチャンクを再利用することができます。そのため、5GB データセットのうちの 2GB を解放した後、再びキーを追加していくと、2GB 分のキーが追加されるまでは RSS (Resident Set Size) は一定の状態を保ったままで増えないことが確認できるでしょう。
* これらにより、ピークメモリ使用量が現在のメモリ使用量よりも非常に大きい場合、フラグメンテーション率は信頼できる値とはいえません。フラグメンテーションは、現在のメモリ使用量(Redis自身による割り当ての合計)を、実際に割り当てられている物理メモリ(RSS が示す値)で割った値です。RSS はピークメモリ使用量を反映しているため、すでに多くのキー / バリューが解放済みで、実際に使用されている(仮想)メモリ量は少ないにも関わらず、RSS は高いままです。結果として mem_used に対する RSS の配分が非常に高い状態となるでしょう。

.. If `maxmemory` is not set Redis will keep allocating memory as it finds
.. fit and thus it can (gradually) eat up all your free memory.
.. Therefore it is generally advisable to configure some limit. You may also
.. want to set `maxmemory-policy` to `noeviction` (which is *not* the default
.. value in some older versions of Redis).

もし 'maxmemory' が設定されていなければ、Redis は必要とするメモリを確保し続けようとするため、フリーなメモリ領域を(徐々に)すべて食いつぶしてしまう可能性があります。そのため、何らかの制限をかけることが一般に推奨されます。併せて、'maxmemory-policy' を 'noeviction' (これは古いバージョンの Redis ではデフォルト値 *ではありません* ) に設定したいこともあるでしょう。

.. It makes Redis return an out of memory error for write commands if and when it reaches the limit - which in turn may result in errors in the application but will not render the whole machine dead because of memory starvation.

この設定を行うと、利用可能なメモリの制限に達した場合、書き込みコマンドを発行すると out of memory エラーが発生します。結果的にアプリケーションエラーとなりますが、メモリ枯渇によりマシン全体が停止してしまうことは防げます。

Work in progress
================

.. Work in progress... more tips will be added soon.

このドキュメントは作業中です...今後、より多くの tips が追加される予定です。

