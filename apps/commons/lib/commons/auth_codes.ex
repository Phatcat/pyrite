defmodule Commons.AuthCodes do

  @doc """
    This function imports all authentication codes to be sent
    to the client.

    Usage: `use Commons.AuthCodes, :wow_connect`
  """
  def wow_connect do
    quote do
      @wow_success 0x00
      @wow_fail_unknown0 0x01
      @wow_fail_unknown1 0x02
      @wow_fail_banned 0x03
      @wow_fail_unknown_account 0x04
      @wow_fail_incorrect_password 0x05
      @wow_fail_already_online 0x06
      @wow_fail_no_time 0x07
      @wow_fail_db_busy 0x08
      @wow_fail_version_invalid 0x09
      @wow_fail_version_update 0x0A
      @wow_fail_invalid_server 0x0B
      @wow_fail_suspended 0x0C
      @wow_fail_fail_noaccess 0x0D
      @wow_success_survey 0x0E
      @wow_fail_parentcontrol 0x0F
      @wow_fail_locked_enforced 0x10
      @wow_fail_trial_ended 0x11
      @wow_fail_use_battlenet 0x12
    end
  end

  @doc """
    This function imports all commands to be send to the client
    depending on her request.

    Usage: `use Commons.AuthCodes, :cmd_auth`
  """
  def cmd_auth do
    quote do
      @cmd_auth_logon_challenge 0x00
      @cmd_auth_logon_proof 0x01
      @cmd_auth_reconnect_challenge 0x02
      @cmd_auth_reconnect_proof 0x03
      @cmd_realm_list 0x10
      @cmd_xfer_initiate  0x30
      @cmd_xfer_data 0x31
    end
  end
  
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end