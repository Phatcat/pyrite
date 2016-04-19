defmodule Realm.Acceptor do
  use GenServer
  use Commons.Codes.AuthCodes
  require Logger
  alias Commons.SRP
  alias Realm.Messages.{LogonChallenge, LogonProof}

  defstruct [:socket, :identity, :public_server, :private_server,
             :salt, :verifier, :public_client, :m1, :session_key]

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
  def handle_info({:tcp, _socket, <<@cmd_auth_logon_challenge :: size(8), msg :: binary>>}, state) do
    Logger.debug "Receiving challenge"
    Logger.debug "Proof message #{Kernel.inspect(msg)} from #{Kernel.inspect(state.socket)}"
    :ok = :inet.setopts(state.socket, [active: :once])

    lc = (LogonChallenge.get_and_check_identity(msg)
          |> LogonChallenge.bootstrap_identity
          |> LogonChallenge.send_response(state.socket))

    case lc.account do
      :nil -> {:noreply, state}
      _ ->
        {:noreply, %{state | public_server: lc.server_public_key,
                             salt: lc.account.salt,
                             identity: lc.identity,
                             verifier: lc.account.verifier,
                             private_server: lc.server_private_key}}
    end

  end

  # Receive proof.
  def handle_info({:tcp, _socket, <<@cmd_auth_logon_proof :: size(8), msg :: binary>>}, state) do
    Logger.debug "Receiving proof"
    Logger.debug "Proof message #{Kernel.inspect(msg)} from #{Kernel.inspect(state.socket)}"
    :ok = :inet.setopts(state.socket, [active: :once])

    lp = (msg
          |> LogonProof.get_proof
          |> LogonProof.compute_server_key(%{server_public_key: state.public_server,
                                             server_private_key: state.private_server,
                                             account_verifier: state.verifier})
          |> LogonProof.check_password(%{account_identity: state.identity,
                                         account_salt: state.salt,
                                         server_public_key: state.public_server})
          |> LogonProof.send_response(state.socket))
          
    # # TODO: Add here a step to save the identity and the l_key, so World server can ask about it.
    {:noreply, %{state | session_key: lp.session_key, public_client: lp.client_public_key}}
  end

  def handle_info({:tcp, _socket, <<@cmd_realm_list :: size(8), msg :: binary>>}, state) do
    Logger.debug "Receiving realmlist request"
    :ok = :inet.setopts(state.socket, [active: :once])

  end

  defp msg_realmlist_response do
    realmlist = Application.get_env(:realm, :realmlist)
    realm_ammount = Enum.count realmlist
    realms = Enum.each realmlist, fn r -> [
      <<1 :: unsigned-little-integer-size(32),
        0 :: unsigned-little-integer-size(8),
        r.name,
        r.host ++ ":" ++ Integer.to_string(r.port)>>
    ] end
  end

  defp msg_proof_response(state, client_m1, public_client, key) do
    server_m1 = SRP.m1(state.identity,
                       state.salt,
                       public_client,
                       state.public_server,
                       key)
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
end
