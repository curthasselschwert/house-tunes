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
              source: nil
  end

  # Client interface
  def status() do
    GenServer.call(__MODULE__, :status)
  end

  def go_back() do
    GenServer.call(__MODULE__, {:command, "SelMenuBk"})
  end

  def select_option(option) when option < 7 do
    GenServer.call(__MODULE__, {:command, "SelLine#{option}", 3000})
  end

  def page_up() do
    GenServer.call(__MODULE__, {:command, "SelPageUp"})
  end

  def page_down() do
    GenServer.call(__MODULE__, {:command, "SelPageDn"})
  end

  def power_on() do
    GenServer.call(__MODULE__, {:command, "SelPower1"})
  end

  def power_off() do
    GenServer.call(__MODULE__, {:command, "SelPower0"})
  end

  def mute_on() do
    GenServer.call(__MODULE__, {:command, "SelMute1"})
  end

  def mute_off() do
    GenServer.call(__MODULE__, {:command, "SelMute0"})
  end

  def volume_down() do
    GenServer.call(__MODULE__, {:command, "SelVolDn"})
  end

  def volume_up() do
    GenServer.call(__MODULE__, {:command, "SelVolUp"})
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

  def handle_call({:command, command}, _, _) do
    send_command(command)
    :timer.sleep(2500)
    status = get_status()
    {:reply, status, status}
  end

  def handle_call({:command, command, delay}, _, _) do
    send_command(command)
    :timer.sleep(delay)
    status = get_status()
    {:reply, status, status}
  end

  defp get_status() do
    %ServerState{}
    |> set_status()
    |> set_content()
    |> set_view()
  end

  defp send_command(command) do
    get("http://192.168.1.254/#{command}")
  end

  defp set_status(state) do
    body = get("http://192.168.1.254/frame0.html")
    status =
      body
      |> Floki.find("table tr td")
      |> Enum.map(&Floki.text/1)
    power = parse_power_info(body)

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
      get("http://192.168.1.254/frame1.html")
      |> Floki.find("table tr td")
      |> Enum.map(&Floki.text/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(fn line -> String.length(line) == 0 end)

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
    case is_source_list?(content) do
      true ->
        Map.put(state, :current_view, :choose_source)
        |> Map.put(:zone, zone)
        |> Map.put(:source, source)
      false ->
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
    indicators = MapSet.new(["AppleTV\n", "Living Rm\n"])

    length =
      MapSet.intersection(content, indicators)
      |> Enum.count()

    length > 0
  end

  defp get(url) when is_binary(url) do
    retry with: exp_backoff() |> randomize() |> expiry(5_000) do
      HTTPoison.get(url)
    end
    |> Tuple.to_list()
    |> Enum.at(1)
    |> Map.get(:body)
  end

end
