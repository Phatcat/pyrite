defmodule Realm do
  use Application
  
  def start(_type, _args) do

    IO.puts """

    Copyright (C) 2016 - Pyrite Project.
    This program comes with absolute no warranty.

    Realm App: v#{Application.spec(:realm, :vsn)}
    Commons libraries: v#{Application.spec(:commons, :vsn)}
    Logging level: #{Logger.level}


    Configured World Servers
    """
    realmlist = Application.get_env(:realm, :realmlist)
    Enum.each realmlist, fn e -> IO.puts """
    * #{e.name} - #{e.host}:#{e.port}
    """ end

    IO.puts """

    ---------------------------------------------------

    To see the list of available commands, while inside
    the shell, do: h Realm.Commands

    ---------------------------------------------------

    """

    Realm.Supervisor.start_link ""
  end
end
