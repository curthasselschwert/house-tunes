defmodule HouseTunesWeb.TunesView do
  use HouseTunesWeb, :view

  def view_title(status) do
    case status.current_view do
      :choose_zone -> "Choose Zone"
      :choose_source -> "Choose Source"
      :source_options -> status.source
      :now_playing -> "Now Playing"
    end
  end

  def show_pagination?(status) do
    status.current_view != :now_playing
  end

  def show_volume_controls?(status) do
    status.current_view != :choose_zone && status.power_on && status.playing
  end
end
