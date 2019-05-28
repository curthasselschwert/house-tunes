defmodule HouseTunes.MZC do
  use Retry
  use GenServer

  require Logger

  defmodule ServerState do
    defstruct content: [],
              current_view: :starting,
              loading: false,
              muted: false,
              playing: false,
              power_on: false,
              source: nil,
              status: [],
              version: nil,
              zone: nil
  end

  # Client interface
  def status() do
    GenServer.call(__MODULE__, :status)
  end

  def go_back(version) do
    GenServer.call(__MODULE__, {:command, "SelMenuBk", version}, 10_000)
  end

  def select_option(option, version) when option < 7 do
    GenServer.call(__MODULE__, {:command, "SelLine#{option}", version, 3000}, 10_000)
  end

  def page_up(version) do
    GenServer.call(__MODULE__, {:command, "SelPageUp", version}, 10_000)
  end

  def page_down(version) do
    GenServer.call(__MODULE__, {:command, "SelPageDn", version}, 10_000)
  end

  def power_on(version) do
    GenServer.call(__MODULE__, {:command, "SelPower1", version}, 10_000)
  end

  def power_off(version) do
    GenServer.call(__MODULE__, {:command, "SelPower0", version}, 10_000)
  end

  def mute_on(version) do
    GenServer.call(__MODULE__, {:command, "SelMute1", version}, 10_000)
  end

  def mute_off(version) do
    GenServer.call(__MODULE__, {:command, "SelMute0", version}, 10_000)
  end

  def volume_down(version) do
    GenServer.call(__MODULE__, {:command, "SelVolDn", version}, 10_000)
  end

  def volume_up(version) do
    GenServer.call(__MODULE__, {:command, "SelVolUp", version}, 10_000)
  end

  def update_status() do
    Process.send_after(__MODULE__, :update_status, 5000)
  end

  # Server interface

  def init(_) do
    status = get_status()
    update_status()
    {:ok, status}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, %ServerState{}, name: __MODULE__)
  end

  def handle_info(:update_status, state) do
    status = get_status()
    update_status()
    case Map.merge(state, %{ version: nil }) == Map.merge(status, %{ version: nil }) do
      true ->
        {:noreply, state}
      false ->
        {:noreply, status}
    end
  end

  def handle_call(:status, _, state) do
    {:reply, state, state}
  end

  def handle_call({:command, command, version}, _, state) do
    case version == state.version do
      true ->
        send_command_and_update(command, 2500)
      false ->
        {:reply, state, state}
    end
  end

  def handle_call({:command, command, version, delay}, _, state) do
    case version == state.version do
      true ->
        send_command_and_update(command, delay)
      false ->
        {:reply, state, state}
    end
  end

  defp get_controller_html() do
    with {:ok, %{body: status}} <- get_html("frame0.html"),
         {:ok, %{body: content}} <- get_html("frame1.html") do
           {:ok, status, content}
    else
      _ -> {:error, :server_down}
    end
  end

  defp get_status() do
    with {:ok, status, content} <- get_controller_html() do
      %ServerState{}
      |> set_status(status)
      |> set_content(content)
      |> set_view()
      |> Map.put(:version, DateTime.to_unix(DateTime.utc_now()))
    else
      _ -> %ServerState{current_view: :controller_down}
    end
  end

  defp send_command_and_update(command, delay) do
    send_command(command)
    :timer.sleep(delay)
    status = get_status()
    {:reply, status, status}
  end

  defp send_command(command) do
    get(command)
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
      {_, response} -> response.body
    else
      _ -> ""
    end
  end

  defp get_html(path) when is_binary(path) do
    retry with: exp_backoff() |> randomize() |> expiry(5_000) do
      HTTPoison.get("http://192.168.1.254/#{path}")
    after
      {:ok, response} -> {:ok, response}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
