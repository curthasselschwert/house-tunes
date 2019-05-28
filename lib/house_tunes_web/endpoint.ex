defmodule HouseTunesWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :house_tunes

  socket "/socket", HouseTunesWeb.UserSocket, 
    websocket: true

  socket "/live", Phoenix.LiveView.Socket

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/", from: :house_tunes, gzip: false,
    only: ~w(
      css
      fonts
      images
      js
      favicon.ico
      robots.txt
      apple-touch-icon.png
      apple-touch-icon-57x57.png
      apple-touch-icon-72x72.png
      apple-touch-icon-76x76.png
      apple-touch-icon-114x114.png
      apple-touch-icon-120x120.png
      apple-touch-icon-144x144.png
      apple-touch-icon-152x152.png
      apple-touch-icon-180x180.png
      launch-screen.png
    )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session,
    store: :cookie,
    key: "_house_tunes_key",
    signing_salt: "yRlY7Zb9"

  plug HouseTunesWeb.Router

  @doc """
  Callback invoked for dynamically configuring the endpoint.

  It receives the endpoint configuration and checks if
  configuration should be loaded from the system environment.
  """
  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end
end
