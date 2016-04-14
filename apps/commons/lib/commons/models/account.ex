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

    field :password, :string, virtual: true

    timestamps
  end
  
  def create_account(account, params \\ :empty) do
    account
    |> cast(params, ~w(username email password), ~w())
    |> resolve_srp
    |> unique_constraint(:username)
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