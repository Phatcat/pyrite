use Mix.Config

# Configuration for port.
config :realm,
  port: 3724

# Database configuration
config :commons, Commons.Repo,
  adapter: Sqlite.Ecto,
  database: "data.sqlite3"