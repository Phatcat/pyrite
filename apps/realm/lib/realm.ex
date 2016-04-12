defmodule Realm do
  use Application
  
  def start(_type, _args) do

    IO.puts """

    Copyright (C) 2016 - Pyrite Project.
    This program comes with absolute no warranty.

    Realm App: v#{Application.spec(:realm, :vsn)}
    Logging level: #{Logger.level}

    """

    Realm.Supervisor.start_link ""
  end
end
