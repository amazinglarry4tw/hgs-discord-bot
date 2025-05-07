defmodule HGSDiscordBot.Consumer do
  use Nostrum.Consumer
  alias Nostrum.Api
  alias Nostrum.Struct.Interaction
  alias Nostrum.Struct.Guild.Member
  alias Nostrum.Struct.Interaction
  alias Utilities.Utilities

  @endpoint Application.compile_env!(:hgs_discord_bot, :endpoint_url)
  @restart_endpoint_url Application.compile_env!(:hgs_discord_bot, :restart_endpoint_url)
  @allowed_channels Application.compile_env!(:hgs_discord_bot, :allowed_channels)
  @allowed_role_ids Application.compile_env(:hgs_discord_bot, :allowed_roles)

  @impl true
  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{type: 2, data: %{name: "status"}, channel_id: chan, id: id, token: token},
         _ws}
      )
      when chan in @allowed_channels do
    response_text =
      @endpoint
      |> HTTPoison.get()
      |> parse_response()
      |> format_servers()

    Api.Interaction.create_response(id, token, %{
      type: 4,
      data: %{content: response_text}
    })
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{type: 2, data: %{name: "status"}, id: id, token: token}, _ws}
      ) do
    Api.Interaction.create_response(id, token, %{
      type: 4,
      data: %{content: "You cannot use `/status` in this channel.", flags: Bitwise.bsl(1, 6)}
    })
  end

  @impl true
  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           type: 2,
           data: %{name: "restart"}
         } = interaction, _ws}
      ) do
    # Delegate to a specialized handler based on channel and roles
    handle_restart(
      interaction,
      has_role?(fetch_member_roles(interaction.guild_id, interaction.user.id), @allowed_role_ids)
    )
  end

  #   Api.Interaction.create_response(id, token, %{
  #     type: 4,
  #     data: %{content: "♻ Attempting to restart **#{Utilities.get(game_id)}** ♻"}
  #   })

  #   # send POST
  #   result =
  #     case HTTPoison.post(
  #            endpoint,
  #            "",
  #            [
  #              {"Content-Type", "application/json"},
  #              {"Accept", "application/json"}
  #            ],
  #            recv_timeout: 60_000
  #          ) do
  #       {:ok, %HTTPoison.Response{status_code: 200}} ->
  #         "🚀 **#{Utilities.get(game_id)}** restarted successfully. 🚀"

  #       {:ok, %HTTPoison.Response{status_code: _}} ->
  #         "⚠️ Failed to restart.  Did you use the correct `game_id`?"

  #       {:error, %HTTPoison.Error{reason: reason}} ->
  #         "❌ HTTP error: #{inspect(reason)}"
  #     end

  #   Api.Message.create(chan, %{content: result})
  # end

  def handle_event(_), do: :noop

  defp handle_restart(interaction, true) do
    endpoint = "#{@restart_endpoint_url}#{interaction.game_id}"

    Api.Interaction.create_response(interaction.id, interaction.token, %{
      type: 4,
      data: %{content: "♻ Attempting to restart **#{Utilities.get(interaction.game_id)}** ♻"}
    })

    result =
      case HTTPoison.post(
             endpoint,
             "",
             [
               {"Content-Type", "application/json"},
               {"Accept", "application/json"}
             ],
             recv_timeout: 60_000
           ) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          "🚀 **#{Utilities.get(interaction.game_id)}** restarted successfully. 🚀"

        {:ok, %HTTPoison.Response{status_code: _}} ->
          "⚠️ Failed to restart.  Did you use the correct `game_id`?"

        {:error, %HTTPoison.Error{reason: reason}} ->
          "❌ HTTP error: #{inspect(reason)}"
      end

    Api.Message.create(interaction.channel, %{content: result})
  end

  # --- helpers below ---

  defp fetch_member_roles(guild_id, user_id) do
    case Api.Guild.member(guild_id, user_id) do
      {:ok, %Member{roles: roles}} -> {:ok, roles}
      _error -> {:error, []}
    end
  end

  # Check if a member has a specific role (by role ID)
  def has_role?(guild_id, user_id, allowed_role_ids) do
    case Api.Guild.member(guild_id, user_id) do
      {:ok, %Member{roles: roles}} ->
        Enum.any?(roles, fn role -> role in allowed_role_ids end)

      _error ->
        false
    end
  end

  def has_role?(user_roles, allowed_role_ids) do
    Enum.any?(user_roles, fn role -> role in allowed_role_ids end)
  end

  defp parse_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}),
    do: Jason.decode!(body)

  defp parse_response({:ok, %HTTPoison.Response{status_code: code}}),
    do: %{"error" => "HTTP #{code}"}

  defp parse_response({:error, %HTTPoison.Error{reason: r}}), do: %{"error" => inspect(r)}

  defp format_servers(%{"servers" => servers}) when is_list(servers) do
    # Ensure latest changes are loaded without restart.
    Utilities.load()

    servers
    |> Enum.map(fn
      %{"name" => name, "status" => status} -> format_message(name, status)
      other -> "• unexpected: #{inspect(other)}"
    end)
    |> Enum.sort_by(fn string ->
      string |> String.slice(7..-1//1)
    end)
    |> Enum.join("\n")
  end

  defp format_servers(%{"error" => msg}), do: "❌ #{msg}"
  defp format_servers(_), do: "⚠️ no servers key found"

  defp format_message(name, "Up") do
    "- ✅ - **#{Utilities.get(name)}**"
  end

  defp format_message(name, "Down") do
    "- ❌ - **#{Utilities.get(name)}**"
  end
end
