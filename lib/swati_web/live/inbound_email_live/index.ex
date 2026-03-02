defmodule SwatiWeb.InboundEmailLive.Index do
  use SwatiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: ~p"/inbound-email/setup")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div></div>
    """
  end
end
