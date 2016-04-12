defmodule Realm.Supervisor do
  @moduledoc false
  
  use Supervisor
  require Logger

  @port Application.get_env(:realm, :port)

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Logger.debug "Starting #{__MODULE__}"

    children = [
      supervisor(Realm.SocketAcceptor, [[]]),
      worker(Task, [__MODULE__, :listen, [@port]])
    ]

    supervise(children, strategy: :one_for_one)
  end

  def listen(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, active: :once, reuseaddr: true])
    IO.inspect socket
    Logger.info "Realm is listening to port: #{port}"
    new_acceptor(socket)
  end

  def new_acceptor(socket) do
    Logger.debug "Realm is awaiting for new connections"
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Realm.SocketAcceptor.start_child(client)
    :ok = :gen_tcp.controlling_process(client, pid)

    new_acceptor(socket)
  end

end