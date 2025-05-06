defmodule Utilities.Utilities do
  # Path to the friendly names config file
  @friendly_names_path Path.join("config", "friendly_names.json")

  @doc """
  Loads friendly names from the config file and stores them in application environment.
  Returns the loaded friendly names map.
  """
  def load do
    case File.read(@friendly_names_path) do
      {:ok, content} ->
        friendly_names = Jason.decode!(content)
        Application.put_env(:hgs_discord_bot, :friendly_names, friendly_names)
        friendly_names

      {:error, reason} ->
        IO.warn("Failed to load friendly names: #{inspect(reason)}")
        # Return empty map as fallback
        %{}
    end
  end

  @doc """
  Gets the friendly name for a server. If not found, returns the original name.
  """
  def get(name) do
    friendly_names = Application.get_env(:hgs_discord_bot, :friendly_names) || load()
    Map.get(friendly_names, name, name)
  end

  @doc """
  Reloads the friendly names from disk.
  """
  def reload do
    load()
  end
end
