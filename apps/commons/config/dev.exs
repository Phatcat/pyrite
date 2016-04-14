use Mix.Config

config :commons, Commons.Repo,
  adapter: Sqlite.Ecto,
  database: "data.sqlite3"