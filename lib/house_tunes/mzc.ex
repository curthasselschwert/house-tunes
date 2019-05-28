defmodule HouseTunes.MZC do
  use Retry
  use GenServer

  require Logger

  @refresh 3000
  @topic "status"

  defmodule ServerState do
    defstruct content: [],
              current_view: :starting,
              loading: false,
              muted: false,
              playing: false,
              power_on: false,
              source: nil,
              status: [],
              zone: nil
  end

  # Client interface
  def status() do
    GenServer.call(__MODULE__, :status)
  end

  def go_back() do
    GenServer.cast(__MODULE__, {:command, "SelMenuBk"})
  end

  def select_option(option) when option < 7 do
    GenServer.cast(__MODULE__, {:command, "SelLine#{option}"})
  end

  def page_up() do
    GenServer.cast(__MODULE__, {:command, "SelPageUp"})
  end

  def page_down() do
    GenServer.cast(__MODULE__, {:command, "SelPageDn"})
  end

  def power_on() do
    GenServer.cast(__MODULE__, {:command, "SelPower1"})
  end

  def power_off() do
    GenServer.cast(__MODULE__, {:command, "SelPower0"})
  end

  def mute_on() do
    GenServer.cast(__MODULE__, {:command, "SelMute1"})
  end

  def mute_off() do
    GenServer.cast(__MODULE__, {:command, "SelMute0"})
  end

  def volume_down() do
    GenServer.cast(__MODULE__, {:command, "SelVolDn"})
  end

  def volume_up() do
    GenServer.cast(__MODULE__, {:command, "SelVolUp"})
  end

  # Server interface

  def init(args) do
    {:ok, args, 0}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, %ServerState{}, name: __MODULE__)
  end

  def handle_info(:timeout, state) do
    Task.start(fn -> get_status() end)
    HouseTunesWeb.Endpoint.broadcast(@topic, "status", state)
    {:noreply, state, @refresh}
  end

  def handle_call(:status, _, state) do
    {:reply, state, state, @refresh}
  end

  def handle_cast({:status_updated, new_state}, _state) do
    HouseTunesWeb.Endpoint.broadcast(@topic, "status", new_state)
    {:noreply, new_state, @refresh}
  end

  def handle_cast({:command, _command}, %{loading: true} = state) do
    {:noreply, state, @refresh}
  end

  def handle_cast({:command, command}, state) do
    new_state = %ServerState{state | loading: true}
    Task.start(fn -> get(command) end)
    HouseTunesWeb.Endpoint.broadcast(@topic, "status", new_state)
    {:noreply, new_state, @refresh}
  end

  defp get_controller_html() do
    with {:ok, %{body: status}} <- get("frame0.html"),
         {:ok, %{body: content}} <- get("frame1.html") do
           {:ok, status, content}
    else
      _ -> {:error, :server_down}
    end
  end

  defp get_status() do
    with {:ok, status, content} <- get_controller_html() do
      status =
        %ServerState{}
        |> set_status(status)
        |> set_content(content)
        |> set_view()
        |> Map.put(:loading, false)
      GenServer.cast(__MODULE__, {:status_updated, status})
    else
      _ ->
        status =
          %ServerState{
            current_view: :controller_down,
            loading: false
          }
        GenServer.cast(__MODULE__, {:status_updated, status})
    end
  end

  defp set_status(state, status_html) do
    status = parse_status_info(status_html)
    power = parse_power_info(status_html)

    Map.merge(state, %{
      muted: power.mute,
      power_on: power.power,
      playing: power.play,
      status: status
    })
  end

  defp set_content(state, content_html) do
    content =
      content_html
      |> Floki.find("table tr td")
      |> Enum.map(&Floki.text/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(fn line -> String.length(line) == 0 end)
      |> Enum.map(&String.replace(&1, ~r/AppleTV/, "Sonos"))
      |> Enum.map(&String.replace(&1, ~r/^CH$/, ""))

    Map.put(state, :content, content)
  end

  defp set_view(%{status: [zone, _, "NOW LISTENING"]} = state) do
    state
    |> Map.put(:current_view, :now_playing)
    |> Map.put(:zone, zone)
  end

  defp set_view(%{status: [_, _, "CHOOSE A ZONE"]} = state) do
    Map.put(state, :current_view, :choose_zone)
  end

  defp set_view(%{status: [zone, _, "SOURCE NOT SELECTED"]} = state) do
    state
    |> Map.put(:current_view, :choose_source)
    |> Map.put(:zone, zone)
  end

  defp set_view(%{status: [zone, _, source], content: content} = state) do
    cond do
      not(is_source_list?(content)) and source == "Sonos" ->
        Map.put(state, :current_view, :now_playing)
        |> Map.put(:zone, zone)
        |> Map.put(:source, source)
        |> Map.merge(%{
          content: [
            "",
            "",
            "Use the Sonos App to",
            "control the music",
            ""
          ]
        })
      is_source_list?(content) ->
        Map.put(state, :current_view, :choose_source)
        |> Map.put(:zone, zone)
        |> Map.put(:source, source)
      true ->
        Map.put(state, :current_view, :source_options)
        |> Map.put(:zone, zone)
        |> Map.put(:source, source)
      end
  end

  defp set_view(state), do: state

  defp parse_status_info(body) when is_binary(body) do
    body
    |> Floki.find("table tr td")
    |> Enum.map(&Floki.text/1)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.replace(&1, ~r/AppleTV/, "Sonos"))
  end

  defp parse_power_info(body) when is_binary(body) do
    body
    |> get_power_content()
    |> String.split(";")
    |> Enum.map(&String.replace(&1, "var ", ""))
    |> Enum.map(&String.split(&1, ~r/1=/))
    |> Enum.map(fn [k, v] -> {String.to_atom(k), String.to_integer(v) == 1} end)
    |> Map.new()
  end

  defp get_power_content(body) when is_binary(body) do
    with [{"script", _, [content]}] <- Floki.find(body, "script") do
      content
    else
      _ ->
        Logger.warn "Power content not found"
        ""
    end
  end
  defp get_power_content(_), do: ""

  defp is_source_list?(content) do
    content = MapSet.new(content)
    indicators = MapSet.new(["Bed Sat", "Living Rm"])

    length =
      MapSet.intersection(content, indicators)
      |> Enum.count()

    length > 0
  end

  defp get(path) when is_binary(path) do
    retry with: exp_backoff() |> randomize() |> expiry(5_000) do
      HTTPoison.get("http://192.168.1.254/#{path}")
    after
      {:ok, response} -> {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
