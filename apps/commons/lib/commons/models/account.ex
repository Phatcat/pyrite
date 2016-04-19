defmodule Commons.Models.Account do
  use Ecto.Schema
  require Logger
  import Ecto.Changeset
  alias Commons.SRP

  schema "accounts" do
    field :username,  :string
    field :salt,      :binary
    field :verifier,  :binary
    field :email,     :string
    field :banned_on, Ecto.DateTime
    field :banned_ex, Ecto.DateTime

    field :password, :string, virtual: true

    timestamps
  end
  
  def create_account(account, params \\ :empty) do
    account
    |> cast(params, ~w(username email password), ~w())
    |> resolve_srp()
    |> unique_constraint(:username)
  end

  def ban_account(account, params \\ :empty) do
    account
    |> cast(params, ~w(banned_on banned_ex), ~w())
    |> normalize_username()
  end

  def unban_account(account, _params \\ :empty) do
    account |> change(%{banned_on: :nil, banned_ex: :nil})
  end

  def normalize_username_param(username), do: SRP.normalize_string(username)

  defp normalize_username(changeset) do
    caps_username = (get_field(changeset, :username) |> SRP.normalize_string())
    changeset
    |> put_change(:username, caps_username)
    |> apply_changes()
  end

  defp resolve_srp(changeset) do
    Logger.debug "Resolving SRP"
    username = get_change(changeset, :username)
    password = get_change(changeset, :password)
    IO.inspect "#{username}, #{password}"
    caps_username = SRP.normalize_string(username)
    salt = SRP.gen_salt
    gen = SRP.get_generator
    prime = SRP.get_prime
    d_key = SRP.get_derived_key(username, password, salt)
    ver = SRP.get_verifier(gen, prime, d_key)

    changeset
    |> put_change(:salt, salt)
    |> put_change(:verifier, ver)
    |> put_change(:username, caps_username)
  end
  
end