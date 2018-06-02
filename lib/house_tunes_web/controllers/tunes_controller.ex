defmodule HouseTunesWeb.TunesController do
  use HouseTunesWeb, :controller
  alias HouseTunes.MZC

  def index(conn, _params) do
    status = MZC.status()
    IO.inspect status
    render conn, "index.html", status: status
  end

  def update(conn, %{ "action" => "select_option", "value" => value }) do
    status = String.to_integer(value) |> MZC.select_option()
    IO.inspect status
    redirect conn, to: tunes_path(conn, :index)
  end

  def update(conn, %{ "action" => action }) do
    status = apply(MZC, String.to_atom(action), [])
    IO.inspect status
    redirect conn, to: tunes_path(conn, :index)
  end
end
