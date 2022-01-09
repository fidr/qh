import Config

if Mix.env() == :test do
  config :logger, level: :info

  config :qh, ecto_repos: [QTest.Repo]

  config :qh, app: :q_test

  config :qh, QTest.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "q_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
end
