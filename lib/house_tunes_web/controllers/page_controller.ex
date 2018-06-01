defmodule HouseTunesWeb.PageController do
  use HouseTunesWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
