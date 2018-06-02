defmodule HouseTunesWeb.TunesController do
  use HouseTunesWeb, :controller
  alias HouseTunes.MZC

  def index(conn, _params) do
    status = MZC.status()
    IO.inspect status
    render conn, "index.html", status: status
  end

  def update(conn, %{ "action" => "select_option", "value" => value, "version" => version }) do
    status =
      String.to_integer(value)
      |> MZC.select_option(String.to_integer(version))
    IO.inspect status
    redirect conn, to: tunes_path(conn, :index)
  end

  def update(conn, %{ "action" => action, "version" => version }) do
    status = apply(MZC, String.to_atom(action), [String.to_integer(version)])
    IO.inspect status
    redirect conn, to: tunes_path(conn, :index)
  end

  def version(conn, _) do
    status = MZC.status()
    IO.inspect status
    json(conn, %{ version: status.version })
  end
end
