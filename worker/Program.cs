using System;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Newtonsoft.Json;
using Npgsql;
using StackExchange.Redis;

namespace Worker
{
    public class Program
    {
        private const int MaxStrikes = 3;

        public static int Main(string[] args)
        {
            try
            {
                // Fetch configuration from environment variables
                var dbHost = Environment.GetEnvironmentVariable("DB_HOST") ?? "db";
                var dbUsername = Environment.GetEnvironmentVariable("DB_USERNAME") ?? "postgres";
                var dbPassword = Environment.GetEnvironmentVariable("DB_PASSWORD") ?? "postgres";
                var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "postgres";
                
                var redisHost = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis";

                // Construct the connection strings
                var pgConnectionString = $"Server={dbHost};Username={dbUsername};Password={dbPassword};Database={dbName}";
                Console.WriteLine($"Connecting to db: host={dbHost} user={dbUsername} database={dbName}");
                var redisConnectionString = redisHost;

                NpgsqlConnection? pgsql = null;
                ConnectionMultiplexer? redisConn = null;
                IDatabase? redis = null;
                var dbStale = true;
                var redisStale = true;
                string? pendingPushBack = null;
                string? lastFailedVote = null;
                var strikes = 0;

                var definition = new { vote = "", voter_id = "" };
                while (true)
                {
                    // Slow down to prevent CPU spike, only query each 100ms
                    Thread.Sleep(100);

                    // Open or reopen what the last failure marked stale, put a vote that
                    // could not be stored back in the queue, then take the next vote.
                    // A failure here is a failure of the service the stage talks to.
                    var stage = "redis";
                    string? json;
                    try
                    {
                        if (redisStale)
                        {
                            DisposeQuietly(redisConn);
                            redisConn = OpenRedisConnection(redisConnectionString);
                            redis = redisConn.GetDatabase();
                            redisStale = false;
                        }
                        if (pendingPushBack != null)
                        {
                            redis!.ListLeftPush("votes", pendingPushBack);
                            pendingPushBack = null;
                        }

                        stage = "db";
                        if (dbStale || pgsql == null || pgsql.State != ConnectionState.Open)
                        {
                            DisposeQuietly(pgsql);
                            pgsql = OpenDbConnection(pgConnectionString);
                            dbStale = false;
                        }

                        stage = "redis";
                        json = redis!.ListLeftPop("votes");
                    }
                    catch (Exception ex)
                    {
                        if (stage == "db")
                        {
                            dbStale = true;
                            Console.WriteLine("Reconnecting DB");
                        }
                        else
                        {
                            redisStale = true;
                            Console.WriteLine("Reconnecting Redis");
                        }
                        Console.Error.WriteLine($"{stage} failed: {ex.GetType().Name}: {ex.Message}");
                        Thread.Sleep(1000);
                        continue;
                    }

                    if (json == null)
                    {
                        try
                        {
                            using var keepAlive = pgsql!.CreateCommand();
                            keepAlive.CommandText = "SELECT 1";
                            keepAlive.ExecuteNonQuery();
                        }
                        catch (Exception ex)
                        {
                            dbStale = true;
                            Console.WriteLine("Reconnecting DB");
                            Console.Error.WriteLine($"Keep-alive failed: {ex.GetType().Name}: {ex.Message}");
                            Thread.Sleep(1000);
                        }
                        continue;
                    }

                    var vote = JsonConvert.DeserializeAnonymousType(json, definition);
                    Console.WriteLine($"Processing vote for '{vote.vote}' by '{vote.voter_id}'");

                    try
                    {
                        UpdateVote(pgsql!, vote.voter_id, vote.vote);
                        lastFailedVote = null;
                        strikes = 0;
                    }
                    catch (PostgresException ex) when (IsBadData(ex))
                    {
                        // Postgres refused the vote itself, so retrying cannot help
                        Console.Error.WriteLine($"Dropping vote by '{vote.voter_id}': {ex.SqlState} {ex.Message}");
                        lastFailedVote = null;
                        strikes = 0;
                    }
                    catch (Exception ex)
                    {
                        // The connection is the likely cause. Put the vote back and reconnect,
                        // but give up on a vote that fails MaxStrikes times in a row.
                        strikes = json == lastFailedVote ? strikes + 1 : 1;
                        lastFailedVote = json;
                        dbStale = true;
                        Console.WriteLine("Reconnecting DB");
                        Console.Error.WriteLine($"Storing vote failed ({strikes} of {MaxStrikes}): {ex.GetType().Name}: {ex.Message}");
                        if (strikes >= MaxStrikes)
                        {
                            Console.Error.WriteLine($"Dropping vote by '{vote.voter_id}' after {MaxStrikes} failures");
                            lastFailedVote = null;
                            strikes = 0;
                        }
                        else
                        {
                            pendingPushBack = json;
                        }
                        Thread.Sleep(1000);
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.ToString());
                return 1;
            }
        }

        private static NpgsqlConnection OpenDbConnection(string connectionString)
        {
            NpgsqlConnection connection;

            while (true)
            {
                try
                {
                    connection = new NpgsqlConnection(connectionString);
                    connection.Open();
                    break;
                }
                catch (SocketException)
                {
                    Console.Error.WriteLine("Waiting for db");
                    Thread.Sleep(1000);
                }
                catch (DbException)
                {
                    Console.Error.WriteLine("Waiting for db");
                    Thread.Sleep(1000);
                }
            }

            Console.Error.WriteLine("Connected to db");

            try
            {
                var command = connection.CreateCommand();
                command.CommandText = @"CREATE TABLE IF NOT EXISTS votes (
                                            id VARCHAR(255) NOT NULL,
                                            vote VARCHAR(255) NOT NULL
                                        )";
                command.ExecuteNonQuery();
            }
            catch
            {
                connection.Dispose();
                throw;
            }

            return connection;
        }

        private static ConnectionMultiplexer OpenRedisConnection(string hostname)
        {
            while (true)
            {
                try
                {
                    // Use IP address to workaround https://github.com/StackExchange/StackExchange.Redis/issues/410
                    var ipAddress = GetIp(hostname);
                    Console.WriteLine($"Found redis at {ipAddress}");
                    Console.Error.WriteLine("Connecting to redis");
                    return ConnectionMultiplexer.Connect(ipAddress);
                }
                catch (Exception ex) when (ex is RedisConnectionException || ex is SocketException || ex is InvalidOperationException)
                {
                    Console.Error.WriteLine("Waiting for redis");
                    Thread.Sleep(1000);
                }
            }
        }

        private static string GetIp(string hostname)
            => Dns.GetHostEntry(hostname)
                .AddressList
                .First(a => a.AddressFamily == AddressFamily.InterNetwork)
                .ToString();

        // Class 22 (data exception) and 23 (integrity violation): the vote itself is bad
        private static bool IsBadData(PostgresException ex)
            => ex.SqlState.StartsWith("22", StringComparison.Ordinal) || ex.SqlState.StartsWith("23", StringComparison.Ordinal);

        private static void DisposeQuietly(IDisposable? resource)
        {
            try
            {
                resource?.Dispose();
            }
            catch (Exception)
            {
            }
        }

        private static void UpdateVote(NpgsqlConnection connection, string voterId, string vote)
        {
            var command = connection.CreateCommand();
            try
            {
                command.CommandText = "INSERT INTO votes (id, vote) VALUES (@id, @vote)";
                command.Parameters.AddWithValue("@id", voterId);
                command.Parameters.AddWithValue("@vote", vote);
                command.ExecuteNonQuery();
            }
            catch (DbException)
            {
                command.CommandText = "UPDATE votes SET vote = @vote WHERE id = @id";
                // No row to update means the vote was not stored: let the caller see the original error
                if (command.ExecuteNonQuery() == 0) throw;
            }
            finally
            {
                command.Dispose();
            }
        }
    }
}
