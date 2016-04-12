defmodule Realm.Acceptor do
  use GenServer
  require Logger

  def start_link do
    IO.inspect 3
    GenServer.start_link(__MODULE__)
  end

  def start_link(socket) do
    IO.inspect 2
    GenServer.start_link(__MODULE__, socket)
  end

  def start_link(socket, opts) do
    IO.inspect 1
    GenServer.start_link(__MODULE__, socket, opts)
  end

  def init(socket) do
    Logger.debug "Starting #{__MODULE__}"
    GenServer.cast(self(), {:accept, socket})
    {:ok, socket}
  end

  def handle_cast({:accept, socket}, _state) do
    {:noreply, socket}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end
  
end