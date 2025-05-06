import Config

config :nostrum,
  token: System.get_env("DISCORD_TOKEN"),
  num_shards: :auto

config :hgs_discord_bot,
  application_id: "1369028460810342591",
  guild_id: "219906264539463680",
  endpoint_url: "http://209.94.144.90:4020/status",
  restart_endpoint_url: "http://209.94.144.90:4020/restart/",
  allowed_channels: [
    # game-night
    1_135_711_821_928_603_708,
    # sassy-chats
    1_284_355_187_653_214_310
  ]
