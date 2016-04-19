defmodule Commons.Controllers.AccountController do
  @moduledoc """
  Functions that work with Account.

  The objective of this module is to provide a single point where you can interact with
  the Account module.
  """
  require Logger

  alias Commons.{Models.Account, Repo}

  @type username :: String.t
  @type password :: String.t
  @type email :: String.t
  @type ban_type :: :permanent | :temporary
  @type ban_status :: :banned | :suspended | :not_banned
  @type expire_datetime :: %Ecto.DateTime{}


  @spec create!(username, password, email) :: %Account{} | no_return
  @doc """
  Creates an account. If it succedes, it will return the model. If it fails,
  it will raise an error.
  """
  def create!(username, password, email) do
    %Account{}
    |> Account.create_account(%{username: username, password: password, email: email})
    |> Repo.insert!
  end


  @spec get_by_username(username) :: %Account{} | :nil | no_return
  @doc """
  Queries the `accounts` table for the `username`.

  Returns `:nil` if no result was found.
  """
  def get_by_username(username) do
    Repo.get_by(Account, username: Account.normalize_username_param(username))
  end


  @spec get_by_username!(username) :: %Account{} | no_return
  @doc """
  Similar to `get_by_username/1`, but raises if no result was found.
  """
  def get_by_username!(username) do
    Repo.get_by!(Account, username: Account.normalize_username_param(username))
  end
  
  @spec banned?(%Account{}) :: ban_status
  @doc """
  Checks if account is banned or suspended. Cleans up in case ban expired.

  In case a problem occurs on updating, it will flag the account as a suspended.
  """
  def banned?(account) do
    Logger.debug("Checking if #{Kernel.inspect(account)} is banned")
    if (account.banned_on != :nil) and 
       (account.banned_ex != :nil) do
      case Ecto.DateTime.compare(account.banned_on, account.banned_ex) do
        :eq -> :banned
        _ -> case Ecto.DateTime.compare(account.banned_ex, Ecto.DateTime.utc) do
          :lt ->
            Logger.info("Suspension on account #{account.username} has expired.")
            case Repo.update(Account.unban_account(account)) do
              {:ok, _up} -> :not_banned
              {:error, _not_up} -> :suspended
            end
          _ -> :suspended
        end
      end
    else :not_banned
    end
  end

  @spec ban!(username, ban_type, expire_datetime) :: %Account{} | no_return
  @doc """
  Bans an `Account` depending on the type of the ban. Returns the banned account.

  The available types of ban are: `:permanent`, `:temporary`. If `:temporary`
  was chosen, you need to provide a date for unbanning, in the following
  format: `YYYY-MM-DD HH:MM:SS`.

  It will raise an error if the operation fails.
  """
  def ban!(username, ban_type, expire_datetime \\ :nil) do
    case ban_type do
      :permanent ->
        now = Ecto.DateTime.utc()
        Repo.get_by!(Account, username: Account.normalize_username_param(username))
        |> Account.ban_account(%{banned_on: now, banned_ex: now})
        |> Repo.update!
      :temporary ->
        now = Ecto.DateTime.utc()
        exp = Ecto.DateTime.cast!(expire_datetime)
        Repo.get_by!(Account, username: Account.normalize_username_param(username))
        |> Account.ban_account(%{banned_on: now, banned_ex: exp})
        |> Repo.update!
    end
  end

  @spec unban!(username) :: %Account{} | no_return
  @doc """
  Unbans the account. It will raise an error if the operation fails.
  """
  def unban!(username) do
    Repo.get_by!(Account, username: Account.normalize_username_param(username))
    |> Account.unban_account
    |> Repo.update!
  end
  
end