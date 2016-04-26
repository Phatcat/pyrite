use Mix.Config

# Configuration for port.
config :realm,
  port: 3724
  
# Edit here the database you want to use
config :commons, Commons.Repo,
  adapter: Sqlite.Ecto,
  database: "data.sqlite3"