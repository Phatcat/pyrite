defmodule Commons do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the Ecto repository
      supervisor(Commons.Repo, [])
    ]

    opts = [strategy: :one_for_one, name: Commons.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
