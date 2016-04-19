defmodule Commons.Codes.RealmFlags do

  defmacro __using__(_opts) do
    quote do
      import Commons.Codes.RealmFlags

      @realm_flag_none 0x00
      @realm_flag_invalid 0x01
      @realm_flag_offline 0x02
      @realm_flag_specifybuild 0x04
      @realm_flag_unk1 0x08
      @realm_flag_unk2 0x10
      @realm_flag_new_players 0x20
      @realm_flag_recommended 0x40
      @realm_flag_full 0x80

    end

  end
  
end