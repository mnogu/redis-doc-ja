==========
Pipelining
==========

.. note:: 
   このドキュメントは `Pipelining <http://redis.io/topics/pipelining>`_ の翻訳です。
   誤訳を見つけたら `翻訳リポジトリ <https://github.com/mocobeta/redis-doc-ja>`_ に Issue を登録してください。

.. Request/Response protocols and RTT

リクエスト/レスポンス プロトコルと RTT
=========================================

.. Redis is a TCP server using the client-server model and what is called a *Request/Response* protocol.

Redis は、クライアント - サーバーモデル (リクエスト/レスポンス プロトコル とも呼ばれる ) を採用した TCP サーバーです。

.. This means that usually a request is accomplished with the following steps:

.. * The client sends a query to the server, and reads from the socket, usually in a blocking way, for the server response.
.. * The server processes the command and sends the response back to the client.

つまり、リクエストは以下のステップにより遂行されます。

* クライアントはサーバーにクエリを送り、ソケットを通じて、(通常はブロッキングな方法で)サーバからのレスポンスを読み取る。
* サーバーはコマンドを処理し、クライアントへ応答を返す。

.. So for instance a four commands sequence is something like this:

たとえば、4つのコマンドからなるシーケンスは以下のようになります:

* *Client:* INCR X
* *Server:* 1
* *Client:* INCR X
* *Server:* 2
* *Client:* INCR X
* *Server:* 3
* *Client:* INCR X
* *Server:* 4

.. Clients and Servers are connected via a networking link. Such a link can be very fast (a loopback interface) or very slow (a connection established over the Internet with many hops between the two hosts). Whatever the network latency is, there is a time for the packets to travel from the client to the server, and back from the server to the client to carry the reply.

クライアントとサーバーはネットワークリンクによって接続されています。そのようなリンクは非常に高速な場合(ループバックインタフェース)も、非常に低速な場合(2つのホスト間に多くの通信機器を挟む、インターネット上に確立された接続)もあります。ネットワークレイテンシがどうであっても、パケットがクライアントからサーバーに届くまで、またサーバーからクライアントに応答が返されるまでには、いくらかの時間がかかります。

.. This time is called RTT (Round Trip Time). It is very easy to see how this can affect the performances when a client needs to perform many requests in a row (for instance adding many elements to the same list, or populating a database with many keys). For instance if the RTT time is 250 milliseconds (in the case of a very slow link over the Internet), even if the server is able to process 100k requests per second, we'll be able to process at max four requests per second.

この時間のことを RTT (Round Trip Time) といいます。クライアントが連続して多くのリクエストを実行する必要があるとき(たとえば、同じリストに多くの要素を追加する、またはデータベースに多くのキーを追加する、など)、これがパフォーマンスにどう影響するかはすぐに理解できることです。たとえば RTT が 250 ミリ秒の場合(インターネット上の非常に遅いリンクを想定します)、たとえサーバーが 1 秒間に 10 万リクエストを捌くことができたとしても、私たちは最大で 1 秒に 4 リクエストしか実行することができないでしょう。

.. If the interface used is a loopback interface, the RTT is much shorter (for instance my host reports 0,044 milliseconds pinging 127.0.0.1), but it is still a lot if you need to perform many writes in a row.

もしインタフェースがループバックインタフェースなら、RTT は非常に短くなりますが(たとえば、私のマシンで 127.0.0.1 に ping を打つ時間は 0.044 ミリ秒です)、それでも連続して大量の書き込みを行うのは多くの時間を必要とします。

.. Fortunately there is a way to improve this use cases.

幸い、このようなケースを改善させる方法があります。

Redis Pipelining
----------------

.. A Request/Response server can be implemented so that it is able to process new requests even if the client didn't already read the old responses. This way it is possible to send *multiple commands* to the server without waiting for the replies at all, and finally read the replies in a single step.

リクエスト/レスポンス方式のサーバーは、クライアントが前の応答を読み出す前に、次のリクエストを処理するように実装することができます。この方法をとると、返答をまったく待つことなく *複数のコマンド* をサーバーに送り、最後にまとめて 1 回で返答を読む、ということが可能になります。

.. This is called pipelining, and is a technique widely in use since many decades. For instance many POP3 protocol implementations already supported this feature, dramatically speeding up the process of downloading new emails from the server.

これはパイプラインと呼ばれ、何十年も前から広く使われているテクニックです。たとえば多くの POP3 プロトコルの実装は、この機能をサポートすることでサーバーから新しいメールをダウンロードする処理スピードを劇的に向上させています。

.. Redis supports pipelining since the very early days, so whatever version you are running, you can use pipelining with Redis. This is an example using the raw netcat utility:

Redis は非常に早い段階からパイプライニングをサポートしており、あなたがどんなバージョンを使っていたとしても、パイプライニングを利用することができます。以下は生の netcat ユーティリティを使った例です:

.. code-block:: none

    $ (echo -en "PING\r\nPING\r\nPING\r\n"; sleep 1) | nc localhost 6379
    +PONG
    +PONG
    +PONG

.. This time we are not paying the cost of RTT for every call, but just one time for the three commands.

こうすると、毎回の呼び出しごとに RTT コストを払うことなく、1 度のラウンドトリップで 3 つのコマンドを実行することができます。

.. To be very explicit, with pipelining the order of operations of our very first example will be the following:

より明確にするために、一番最初の例のオペレーションの順番は、パイプライニングを利用すると以下のようになります:

* *Client:* INCR X
* *Client:* INCR X
* *Client:* INCR X
* *Client:* INCR X
* *Server:* 1
* *Server:* 2
* *Server:* 3
* *Server:* 4

.. **IMPORTANT NOTE**: while the client sends commands using pipelining, the server will be forced to queue the replies, using memory. So if you need to send many many commands with pipelining it's better to send this commands up to a given reasonable number, for instance 10k commands, read the replies, and send again other 10k commands and so forth. The speed will be nearly the same, but the additional memory used will be at max the amount needed to queue the replies for this 10k commands.

.. important:: 重要な注意
   クライアントがパイプライニングを使ってコマンドを送る場合、サーバーはメモリを消費して応答をキューに溜めておきます。もし非常に大量のコマンドをパイプライニングを使って送信する必要がある場合、妥当な上限を定めることが望ましいでしょう。たとえば 10000 コマンドを送信し、その応答を受けとったあとでさらに次の 10000 コマンドを送信する、というようなやり方です。スピードは一定に保たれますが、10000 コマンドのレスポンスをキューイングするための追加のメモリを必要とします。

.. Some benchmark

ベンチマーク
------------

.. In the following benchmark we'll use the Redis Ruby client, supporting pipelining, to test the speed improvement due to pipelining:

以下のベンチマークでは、パイプライニングをサポートする Redis の Ruby クライアントを使い、パイプライニングによる性能向上についてテストしています。

.. code-block:: ruby

    require 'rubygems'
    require 'redis'

    def bench(descr)
        start = Time.now
        yield
        puts "#{descr} #{Time.now-start} seconds"
    end

    def without_pipelining
        r = Redis.new
        10000.times {
            r.ping
        }
    end

    def with_pipelining
        r = Redis.new
        r.pipelined {
            10000.times {
                r.ping
            }
        }
    end

    bench("without pipelining") {
        without_pipelining
    }
    bench("with pipelining") {
        with_pipelining
    }

.. Running the above simple script will provide this figures in my Mac OS X system, running over the loopback interface, where pipelining will provide the smallest improvement as the RTT is already pretty low:

このシンプルなスクリプトを、もっとも性能向上の余地が小さい、 Mac OS X のループバックインタフェース上で動かした場合で以下の数値が得られました。

.. code-block:: none

    without pipelining 1.185238 seconds
    with pipelining 0.250783 seconds

.. As you can see using pipelining we improved the transfer by a factor of five.

この結果が示すように、パイプライニングを使用することで、性能が 5 倍向上されています。

.. Pipelining VS Scripting

パイプライニング VS スクリプティング
--------------------------------------

.. Using [Redis scripting](/commands/eval) (available in Redis version 2.6 or greater) a number of use cases for pipelining can be addressed more efficiently using scripts that perform a lot of the work needed server side. A big advantage of scripting is that it is able to both read and write data with minimal latency, making operations like *read, compute, write* very fast (pipelining can't help in this scenario since the client needs the reply of the read command before it can call the write command).

`Redis scripting <http://redis.io/commands/eval>`_ (Redis 2.6 以上で利用可能) を使うと、サーバーサイドで多くの仕事が必要なユースケースにおいて、パイプライニングよりも効率良く処理ができる場合があります。スクリプティングの大きな利点は、データの read と write の両方を最小のレイテンシで得られるため、 *読み取り, 計算, 書き込み* という操作を非常に高速に実行できる点です(パイプライニングでは、クライアントは write コマンドの前に read コマンドの応答を待つ必要があるため、このようなケースに対応できません)。

.. Sometimes the application may also want to send `EVAL` or `EVALSHA` commands in a pipeline. This is entirely possible and Redis explicitly supports it with the [SCRIPT LOAD](http://redis.io/commands/script-load) command (it guarantees that `EVALSHA` can be called without the risk of failing).

しばしば、アプリケーションは、パイプライン中で `EVAL <http://redis.io/commands/eval>`_ または `EVALSHA <http://redis.io/commands/evalsha>`_ を実行したくなることがあるでしょう。これらはすべて可能で、 `SCRIPT LOAD <http://redis.io/commands/script-load>`_ コマンドによりサポートされています(これは、 `EVALSHA <http://redis.io/commands/evalsha>`_ が失敗する危険なく呼び出されることを保証するものです)。

