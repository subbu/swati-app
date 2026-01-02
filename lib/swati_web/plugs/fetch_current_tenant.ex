defmodule SwatiWeb.Plugs.FetchCurrentTenant do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    current_scope = conn.assigns[:current_scope]
    tenant = current_scope && current_scope.tenant

    assign(conn, :current_tenant, tenant)
  end
end
