defmodule Realm.Commands do
  @moduledoc """
    These are the available commands from your Realm shell.
    This is an Elixir shell - if you are familiar with Elixir -
    you know what you are doing. If you are not, please read
    down below with *EXTREME* care.

    Please note that, you can call *any* public function
    from *any* module, but that is discouraged. Prefer this
    tool if you need to manage your Realm server.

    To manage your Game server, you should connect to it,
    instead. Realm is just responsible for the accounts and
    nothing else.
  """

  alias Commons.Repo
  alias Commons.Models.Account

  @doc """
    Creates a new account:

    `username`, `password` and `email` are both `Strings`

    ```create_account(username, password, email)```
  """
  def create_account(username, password, email) do
    %Account{}
    |> Account.create_account(%{username: username, password: password, email: email})
    |> Repo.insert!
  end

  @doc """
    Shows the memory usage of the system.
  """
  def memory_usage do
    "Total memory usage: #{:erlang.memory[:total] / 1000000} MB"
  end
  
end