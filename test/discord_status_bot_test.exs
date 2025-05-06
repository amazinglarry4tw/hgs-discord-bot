defmodule HGSDiscordBotTest do
  use ExUnit.Case
  doctest HGSDiscordBot

  test "greets the world" do
    assert HGSDiscordBot.hello() == :world
  end
end
