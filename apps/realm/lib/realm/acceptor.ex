defmodule Realm.Acceptor do
  use GenServer
  use Commons.Codes.AuthCodes
  require Logger
  alias Realm.Messages.{LogonChallenge, LogonProof, RealmList}

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
    {:stop, :normal, state}
  end

  # Receive challenge.
  def handle_info({:tcp, _socket, <<@cmd_auth_logon_challenge :: size(8), msg :: binary>>}, state) do
    Logger.debug "Receiving challenge"
    Logger.debug "Challenge message #{Kernel.inspect(msg)} from #{Kernel.inspect(state.socket)}"
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

  # Realmlist.
  def handle_info({:tcp, _socket, <<@cmd_realm_list :: size(8), msg :: binary>>}, state) do
    Logger.debug "Receiving realmlist request"
    :ok = :inet.setopts(state.socket, [active: :once])

  end

  # THIS ABSOLUTELY NEEDS TO BE THE LAST ONE. IT'S A CATCH ALL.
  def handle_info({:tcp, _socket, msg}, state) do
    Logger.debug "Unknown message: #{Kernel.inspect(msg)}"
    {:stop, :normal, state}
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
end
