defmodule HGSDiscordBot.Application do
  @moduledoc false
  use Application
  alias Nostrum.Api
  alias Utilities.Utilities

  # the command(s) you want to register
  @commands [
    %{
      name: "status",
      description: "Fetch current status of hosted game servers for game-night",
      type: 1
    },
    %{
      name: "restart",
      description: "Restart a game server by game id",
      type: 1,
      options: [
        %{
          name: "game_id",
          description: "The id of the game server to restart",
          type: 3,
          required: true
        }
      ]
    }
  ]

  @impl true
  def start(_type, _args) do
    # 1) register your slash command in the guild
    Api.ApplicationCommand.bulk_overwrite_guild_commands(
      config(:application_id),
      config(:guild_id),
      @commands
    )

    # 2) define your supervision tree
    children = [
      # this will call the child_spec injected by `use Nostrum.Consumer`
      {HGSDiscordBot.Consumer, []}
    ]

    Utilities.load()

    # 3) start the supervisor
    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  # shortcut to pull from config/config.exs
  defp config(key),
    do: Application.fetch_env!(:hgs_discord_bot, key)
end
