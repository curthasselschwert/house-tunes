defmodule HouseTunes.MZC do
  use Retry
  use GenServer

  defmodule ServerState do
    defstruct current_view: :choose_zone,
              muted: false,
              playing: false,
              power_on: false,
              priv: %{
                content: [],
                status: []
              },
              zone: nil,
              source: nil,
              version: nil
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

  # Server interface

  def init(_) do
    status = get_status()
    {:ok, status}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, %ServerState{}, name: __MODULE__)
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

  defp get_status() do
    %ServerState{}
    |> set_status()
    |> set_content()
    |> set_view()
    |> Map.put(:version, DateTime.to_unix(DateTime.utc_now()))
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

  defp set_status(state) do
    body = get("frame0.html")
    status =
      body
      |> Floki.find("table tr td")
      |> Enum.map(&Floki.text/1)
    power = parse_power_info(body)

    status =
      case Enum.at(status, 2) == "AppleTV\n" do
        true -> List.replace_at(status, 2, "Sonos")
        false -> status
      end

    Map.merge(state, %{
      priv: %{
        status: status,
        content: state.priv.content
      },
      power_on: power.power1,
      playing: power.play1,
      muted: power.mute1
    })
  end

  defp set_content(state) do
    content =
      get("frame1.html")
      |> Floki.find("table tr td")
      |> Enum.map(&Floki.text/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(fn line -> String.length(line) == 0 end)
      |> Enum.map(fn line ->
        if line == "AppleTV", do: "Sonos", else: line
      end)

    Kernel.put_in(state.priv.content, content)
  end

  defp set_view(%{ priv: %{ status: [zone, _, status] }} = state) when status == "NOW LISTENING" do
    state
    |> Map.put(:current_view, :now_playing)
    |> Map.put(:zone, zone)
  end

  defp set_view(%{ priv: %{ status: [_, _, status] }} = state) when status == "CHOOSE A ZONE\n" do
    Map.put(state, :current_view, :choose_zone)
  end

  defp set_view(%{ priv: %{ status: [zone, _, status] }} = state) when status == "SOURCE NOT SELECTED\n" do
    state
    |> Map.put(:current_view, :choose_source)
    |> Map.put(:zone, zone)
  end

  defp set_view(%{ priv: %{ status: [zone, _, source], content: content } } = state) do
    IO.inspect [content, is_source_list?(content)]
    cond do
      not(is_source_list?(content)) and source == "Sonos" ->
        Map.put(state, :current_view, :now_playing)
        |> Map.put(:zone, zone)
        |> Map.put(:source, source)
        |> Map.merge(%{
          priv: %{
            status: state.priv.status,
            content: [
              "",
              "",
              "Use the Sonos App to",
              "control the music",
              ""
            ]
          }
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

  defp parse_power_info(body) when is_binary(body) do
    body
    |> Floki.find("script")
    |> List.first()
    |> Tuple.to_list()
    |> Enum.at(2)
    |> List.first()
    |> String.split(";")
    |> Enum.map(&String.replace(&1, "var ", ""))
    |> Enum.map(&String.split(&1, "="))
    |> Enum.map(fn [k, v] -> {String.to_atom(k), String.to_integer(v) == 1} end)
    |> Map.new()
  end

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
    end
    |> Tuple.to_list()
    |> Enum.at(1)
    |> Map.get(:body)
  end

end
