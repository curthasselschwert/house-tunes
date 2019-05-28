defmodule HouseTunesWeb.Live do
  use Phoenix.LiveView

  alias HouseTunesWeb.TunesView
  alias HouseTunes.MZC

  @topic "status"

  def mount(_session, socket) do
    HouseTunesWeb.Endpoint.subscribe(@topic)
    status = MZC.status()
    socket =
      socket
      |> assign(:status, status)
      |> assign(:content, Enum.with_index(status.content))

    {:ok, socket}
  end

  def render(assigns), do: TunesView.render("index.html", assigns)

  def handle_info(%{topic: @topic, payload: status}, socket) do
    socket =
      socket
      |> assign(:status, status)
      |> assign(:content, Enum.with_index(status.content))

    {:noreply, socket}
  end

  def handle_event("go_back", _value, socket) do
    MZC.go_back()
    {:noreply, socket}
  end

  def handle_event("select_option", value, socket) do
    MZC.select_option(String.to_integer(value))
    {:noreply, socket}
  end

  def handle_event("page_up", _value, socket) do
    MZC.page_up()
    {:noreply, socket}
  end

  def handle_event("page_down", _value, socket) do
    MZC.page_down()
    {:noreply, socket}
  end

  def handle_event("volume_up", _value, socket) do
    MZC.volume_up()
    {:noreply, socket}
  end

  def handle_event("volume_down", _value, socket) do
    MZC.volume_down()
    {:noreply, socket}
  end

  def handle_event("unmute", _value, socket) do
    MZC.mute_off()
    {:noreply, socket}
  end

  def handle_event("mute", _value, socket) do
    MZC.mute_on()
    {:noreply, socket}
  end

  def handle_event("power_off", _value, socket) do
    MZC.power_off()
    {:noreply, socket}
  end
end
