defmodule Realm.Acceptor do
  use GenServer
  use Commons.Codes.AuthCodes
  require Logger
  alias Realm.Errors.UsernameSizeError
  alias Commons.SRP
  alias Commons.Repo
  alias Commons.Models.Account

  defstruct [:socket, :identity, :public_server, :private_server,
             :salt, :verifier, :public_client, :m1]

  def start_link(socket) do
    GenServer.start_link(__MODULE__, %Realm.Acceptor{socket: socket})
  end

  def init(state) do
    Logger.debug "Starting #{__MODULE__} with: #{Kernel.inspect(state)}"
    {:ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  # Always cleans up
  def terminate(reason, state) do
    Logger.debug "Finishing #{__MODULE__}: #{Kernel.inspect(reason)}"
    :gen_tcp.close(state.socket)
    {:noreply, state}
  end

  # Receive disconnect message
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.debug "TCP connection disconnected."
    {:stop, :normal, state};
  end

  # Receive challenge.
  def handle_info({:tcp, _socket, <<0 :: size(8), msg :: binary>>}, state) do
    Logger.debug "Receiving challenge"
    Logger.debug "Proof message #{Kernel.inspect(msg)} from #{Kernel.inspect(state.socket)}"
    :ok = :inet.setopts(state.socket, [active: :once])
    state |> get_identity_from_message(msg) |> check_identity_and_send_response
  end

  # Receive proof.
  def handle_info({:tcp, _socket, <<1 :: size(8), msg :: binary>>}, state) do
    Logger.debug "Receiving proof"
    Logger.debug "Proof message #{Kernel.inspect(msg)} from #{Kernel.inspect(state.socket)}"
    :ok = :inet.setopts(state.socket, [active: :once])
    {public_client, m1} = get_proof(msg)
    prime = SRP.get_prime
    server_key = SRP.compute_server_key(state.private_server,
                                        public_client,
                                        state.public_server,
                                        prime,
                                        state.verifier)
    key = SRP.interleave_hash(server_key)
    l_key = SRP.from_b_to_l_endian(key, 320)
    # TODO: Add here a step to save the identity and the l_key
    :gen_tcp.send(state.socket, msg_proof_response(state, m1, public_client, key))
    {:noreply, %{state | m1: m1, public_client: public_client}}
  end
  
  def handle_info({:tcp, _socket, <<16 :: size(8), msg :: binary>>}, state) do
    Logger.debug "Receiving realmlist request"
    :ok = :inet.setopts(state.socket, [active: :once])
    realms = Enum.each realmlist, fn r -> [
      <<1 :: unsigned-long-integer-size(32),
        0 :: unsigned-long-integer-size(8),
        r.name,
        r.host ++ ":" ++ Integer.to_string(r.port)>>
    ] end
  end

  defp get_proof(msg) do
    <<l_public_client :: unsigned-little-integer-size(256),
      l_m1            :: unsigned-little-integer-size(160),
      _crc_hash       :: unsigned-little-integer-size(160),
      _num_keys       :: size(8),
      _unk            :: size(8)>> = msg
    b_m1 = <<l_m1 :: unsigned-big-integer-size(160)>>
    b_public_client = <<l_public_client :: unsigned-big-integer-size(256)>>
    {b_public_client, b_m1}
  end

  defp check_identity_and_send_response(state) do
    Logger.debug "Checking database"
    case Repo.get_by(Account, username: state.identity) do
      :nil ->
        Logger.info "No account found for username: #{state.identity}"
        :gen_tcp.send(state.socket, msg_no_account_found_on_database)
        {:noreply, state}
      account ->
        Logger.info "Account found for username: #{state.identity}"
        gen = SRP.get_generator
        prime = SRP.get_prime
        ver = account.verifier
        salt = account.salt
        {public_server, private_server} = SRP.server_public_private_key(gen, prime, ver)
        :gen_tcp.send(state.socket, msg_login_challenge(public_server, gen, prime, salt))
        {:noreply, %{state | public_server: public_server,
                             salt: salt,
                             verifier: ver,
                             private_server: private_server}}
    end
  end

  defp msg_proof_response(state, client_m1, public_client, key) do
    server_m1 = SRP.m1(state.identity,
                       state.salt,
                       public_client,
                       state.public_server,
                       key)
    IO.inspect client_m1
    IO.inspect server_m1
    case server_m1 == client_m1 do
      false ->
        Logger.debug "Client has sent incorrect password."
        [<<@cmd_auth_logon_proof        :: size(8)>>,
         <<@wow_fail_incorrect_password :: size(8)>>]
      true ->
        Logger.debug "Password match!"
        b_m2 = SRP.m2(public_client, server_m1, key)
        l_m2 = SRP.from_b_to_l_endian(b_m2, 160)
        [<<@cmd_auth_logon_proof :: size(8)>>,
         <<@wow_success          :: size(8)>>,
         l_m2,
         <<0                     :: size(8)>>, # Flags
         <<0                     :: size(8)>>,
         <<0                     :: size(8)>>]
    end
  end

  defp msg_login_challenge(public_server, gen, prime, salt) do
    gen_length = byte_size(gen)
    prime_length = byte_size(prime)
    unk3 = <<0x0123456789ABCDEF :: unsigned-little-integer-size(128)>>
    l_public_server = SRP.from_b_to_l_endian(public_server, 256)
    l_prime = SRP.from_b_to_l_endian(prime, 256)
    l_salt = salt # Already little endian
    l_gen = gen   # Same value in both endians (big and little)

    [<<@cmd_auth_logon_challenge :: size(8)>>,
     <<0                         :: size(8)>>,
     <<@wow_success              :: size(8)>>,
     l_public_server,
     <<gen_length                :: size(8)>>,
     l_gen,
     <<prime_length              :: size(8)>>,
     l_prime,
     l_salt,
     unk3,
     <<0                         :: size(8)>>]

  end

  defp msg_no_account_found_on_database do
    [<<@cmd_auth_logon_challenge :: size(8)>>,
     <<0                         :: size(8)>>,
     <<@wow_fail_unknown_account :: size(8)>>]
  end

  defp get_identity_from_message(state, msg) do
    <<_err       :: size(8),
      _size      :: unsigned-little-integer-size(16),
    	_game_name :: unsigned-little-integer-size(32),
    	_v1        :: size(8),
    	_v2        :: size(8),
    	_v3        :: size(8),
    	build      :: unsigned-little-integer-size(16),
    	_platform  :: unsigned-little-integer-size(32),
    	_os        :: unsigned-little-integer-size(32),
    	_country   :: unsigned-little-integer-size(32),
    	_tz_bias   :: unsigned-little-integer-size(32),
    	_ip        :: unsigned-little-integer-size(32),
    	id_len     :: size(8),
    	identity   :: binary>> = msg

    if id_len == 0 do
      raise UsernameSizeError
    end

    if String.length(identity) != id_len do
      raise UsernameSizeError, "The size of the username(#{String.length(identity)}) is different
                                from the one received(#{id_len})."
    end

    Logger.debug "Username: #{Kernel.inspect(identity)}, build version: #{Kernel.inspect(build)}"

    %{state | identity: identity}
  end
  
end