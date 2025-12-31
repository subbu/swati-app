defmodule SwatiWeb.PageController do
  use SwatiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
