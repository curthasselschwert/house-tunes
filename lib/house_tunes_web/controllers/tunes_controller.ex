defmodule HouseTunesWeb.TunesController do
  use HouseTunesWeb, :controller
  alias HouseTunes.MZC

  def index(conn, _params) do
    status = MZC.status()
    render conn, "index.html", status: status
  end

  def update(conn, %{ "action" => "select_option", "value" => value }) do
    MZC.select_option(String.to_integer(value))
    redirect conn, to: tunes_path(conn, :index)
  end

  def update(conn, %{ "action" => action }) do
    IO.inspect action, label: "Update Action"
    apply(MZC, String.to_atom(action), [])
    redirect conn, to: tunes_path(conn, :index)
  end
end
