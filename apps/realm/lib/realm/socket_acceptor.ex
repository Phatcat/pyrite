defmodule Realm.SocketAcceptor do
  @moduledoc false
  
  use Supervisor
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Logger.debug "Starting #{__MODULE__}"
    children = [
      worker(Realm.Acceptor, [], restart: :temporary)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_child(params) do
    Supervisor.start_child(__MODULE__, [params])
  end

end