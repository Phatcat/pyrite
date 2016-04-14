use Mix.Config

# Configuration for Realm server.

config :realm,
  port: 3724

#     import_config "#{Mix.env}.exs"

# You can configure as many realms as you want,
# you need to. Just add another struct %{} in
# the array below.
config :realm,
  realmlist: [%{host: "127.0.0.1",
                port: 8899,
                name: "Pyrite Test Realm"}]