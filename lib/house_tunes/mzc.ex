defmodule HouseTunes.MZC do
  use Retry

  alias HouseTunes.MZC

  @views [
    :choose_zone,
    :choose_source,
    :view_source,
    :source_options,
    :now_playing
  ]

  defstruct current_view: :choose_zone,
            priv: %{
              content: [],
              status: []
            },
            zone: nil,
            source: nil

  def status() do
    %MZC{}
    |> set_status()
    |> set_content()
    |> set_view()
  end

  def go_back() do
    send_command("SelMenuBk")
  end

  def select_option(option) when option < 7 do
    send_command("SelLine#{option}")
  end

  def page_up() do
    send_command("SelPageUp")
  end

  def page_down() do
    send_command("SelPageDn")
  end

  def power_on() do
    send_command("SelPower1")
  end

  def power_off() do
    send_command("SelPower0")
  end

  def mute_on() do
    send_command("SelMute1")
  end

  def mute_off() do
    send_command("SelMute0")
  end

  def volume_down() do
    send_command("SelVolDn")
  end

  def volume_up() do
    send_command("SelVolUp")
  end

  defp send_command(command) do
    get("http://192.168.1.254/#{command}")
    :timer.sleep(2000)
    status()
  end

  defp set_status(state) do
    status =
      get("http://192.168.1.254/frame0.html")
      |> Floki.find("table tr td")
      |> Enum.map(&Floki.text/1)

    Kernel.put_in(state.priv.status, status)
  end

  defp set_content(state) do
    content =
      get("http://192.168.1.254/frame1.html")
      |> Floki.find("table tr td")
      |> Enum.map(&Floki.text/1)

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