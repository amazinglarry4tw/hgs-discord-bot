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
      ) do
    if chan in @allowed_channels do
      response_text =
        @endpoint
        |> HTTPoison.get()
        |> parse_response()
        |> format_servers()
        # ensures it’s a string even if something slips through
        |> to_string()

      IO.inspect(response_text, label: "🔍 response_text")

      Api.Interaction.create_response(id, token, %{
        type: 4,
        data: %{content: response_text}
      })
    else
      # send an ephemeral “you can’t do that here” message
      Api.Interaction.create_response(id, token, %{
        type: 4,
        data: %{
          content: "❌ You can only run `/status` in designated channels.",
          # 64 = ephemeral
          flags: Bitwise.bsl(1, 6)
        }
      })
    end
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           type: 2,
           data: %{name: "restart", options: [%{name: "game_id", value: game_id}]},
           channel_id: chan,
           id: id,
           guild_id: guild_id,
           user: user,
           token: token
         }, _ws}
      ) do
    if chan in @allowed_channels and has_role?(guild_id, user.id, @allowed_role_ids) do
      # body = %{game: game_id} |> Jason.encode!()
      # headers = [{"Content-Type", "application/json"}]
      endpoint = "#{@restart_endpoint_url}#{game_id}"

      Api.Interaction.create_response(id, token, %{
        type: 4,
        data: %{content: "Attempting to restart #{Utilities.get(game_id)}"}
      })

      # send POST
      result =
        case HTTPoison.post(endpoint, "", []) do
          {:ok, %HTTPoison.Response{status_code: 200}} ->
            "⚙️ Successfully queued restart for `#{game_id}`."

          {:ok, %HTTPoison.Response{status_code: code, body: resp_body}} ->
            "⚠️ Got #{code} from API: #{resp_body}"

          {:error, %HTTPoison.Error{reason: reason}} ->
            "❌ HTTP error: #{inspect(reason)}"
        end

      Api.Interaction.create_response(id, token, %{
        type: 4,
        data: %{content: result}
      })
    else
      Api.Interaction.create_response(id, token, %{
        type: 4,
        data: %{
          content: """
          ❌ You either do not have permissions to restart servers or are
          trying to do so in an ineligible channel
          """,
          # 64 = ephemeral
          flags: Bitwise.bsl(1, 6)
        }
      })
    end
  end

  def handle_event(_), do: :noop

  # --- helpers below ---

  # Check if a member has a specific role (by role ID)
  def has_role?(guild_id, user_id, allowed_role_ids) do
    case Api.Guild.member(guild_id, user_id) do
      {:ok, %Member{roles: roles}} ->
        Enum.any?(roles, fn role -> role in allowed_role_ids end)

      _error ->
        false
    end
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
