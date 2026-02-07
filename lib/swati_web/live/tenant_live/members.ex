defmodule SwatiWeb.TenantLive.Members do
  use SwatiWeb, :live_view

  alias Swati.Accounts
  alias Swati.Tenancy.Membership
  alias SwatiWeb.Formatting

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-10">
        <div class="space-y-1">
          <h1 class="text-2xl font-semibold">Members</h1>
          <p class="text-sm text-base-content/70">
            Manage access for {@current_scope.tenant.name}.
          </p>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Invite a teammate</h2>
            <p class="text-sm text-base-content/70">
              Send a magic link to add someone to this workspace.
            </p>
          </div>

          <.form for={@form} id="invite-member-form" phx-submit="invite">
            <div class="grid gap-4 sm:grid-cols-[1.5fr_1fr_auto] items-end">
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                autocomplete="email"
                required
              />

              <.select
                field={@form[:role]}
                label="Role"
                options={@role_options}
                native
              />

              <.button class="btn btn-primary w-full sm:w-auto" phx-disable-with="Sending invite...">
                Send invite
              </.button>
            </div>
          </.form>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Current members</h2>
            <p class="text-sm text-base-content/70">
              Roles control what each person can see and do.
            </p>
          </div>

          <.table>
            <.table_head>
              <:col>Name</:col>
              <:col>Email</:col>
              <:col>Title</:col>
              <:col>Role</:col>
              <:col>Joined</:col>
              <:col></:col>
            </.table_head>
            <.table_body id="members" phx-update="stream">
              <.table_row id="members-empty" class="hidden only:table-row">
                <:cell colspan="6" class="text-sm text-base-content/70 text-center py-6">
                  No members yet.
                </:cell>
              </.table_row>

              <.table_row :for={{id, membership} <- @streams.members} id={id}>
                <:cell class="font-medium">
                  {Membership.display_name(membership)}
                </:cell>
                <:cell class="text-sm text-base-content/70">
                  {membership.user.email}
                </:cell>
                <:cell class="text-sm text-base-content/70">
                  {membership.title || "—"}
                </:cell>
                <:cell>
                  <%= if membership.user_id == @current_scope.user.id do %>
                    <.badge color={role_color(membership.role)} variant="soft">
                      {format_role(membership.role)}
                    </.badge>
                  <% else %>
                    <form phx-change="change_role" phx-value-membership-id={membership.id}>
                      <select
                        name="role"
                        class="select select-sm select-bordered"
                        phx-debounce="300"
                      >
                        <%= for {label, value} <- role_select_options() do %>
                          <option value={value} selected={membership.role == value}>
                            {label}
                          </option>
                        <% end %>
                      </select>
                    </form>
                  <% end %>
                </:cell>
                <:cell class="text-sm text-base-content/70">
                  {format_date(membership.inserted_at, @current_scope.tenant)}
                </:cell>
                <:cell>
                  <.button
                    :if={membership.user_id != @current_scope.user.id}
                    phx-click="remove_member"
                    phx-value-membership-id={membership.id}
                    variant="ghost"
                    size="sm"
                    data-confirm="Remove this member? They will lose access to this workspace."
                  >
                    <.icon name="hero-trash" class="size-4 text-error" />
                  </.button>
                </:cell>
              </.table_row>
            </.table_body>
          </.table>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Members")
      |> assign(:role_options, role_options())

    if Accounts.authorized?(socket.assigns.current_scope, :manage_members) do
      {:ok, load_members(socket)}
    else
      {:ok, unauthorized(socket)}
    end
  end

  @impl true
  def handle_event("invite", %{"membership_invite" => params}, socket) do
    case Accounts.invite_member(
           socket.assigns.current_scope,
           params,
           &url(~p"/users/log-in/#{&1}")
         ) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invite sent.")
         |> refresh_members()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :unauthorized} ->
        {:noreply, unauthorized(socket)}
    end
  end

  @impl true
  def handle_event("change_role", %{"membership-id" => membership_id, "role" => role}, socket) do
    role_atom = String.to_existing_atom(role)

    case Accounts.update_member_role(socket.assigns.current_scope, membership_id, role_atom) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Role updated.")
         |> refresh_members()}

      {:error, :cannot_change_own_role} ->
        {:noreply, put_flash(socket, :error, "You cannot change your own role.")}

      {:error, :last_owner} ->
        {:noreply, put_flash(socket, :error, "Cannot change role of the last owner.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update role.")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"membership-id" => membership_id}, socket) do
    case Accounts.remove_member(socket.assigns.current_scope, membership_id) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Member removed.")
         |> refresh_members()}

      {:error, :cannot_remove_self} ->
        {:noreply, put_flash(socket, :error, "You cannot remove yourself.")}

      {:error, :last_owner} ->
        {:noreply, put_flash(socket, :error, "Cannot remove the last owner.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to remove member.")}
    end
  end

  defp load_members(socket) do
    case Accounts.list_members(socket.assigns.current_scope) do
      {:ok, members} ->
        socket
        |> assign_form(Accounts.change_membership_invite())
        |> stream(:members, members, reset: true)

      {:error, _reason} ->
        unauthorized(socket)
    end
  end

  defp refresh_members(socket) do
    case Accounts.list_members(socket.assigns.current_scope) do
      {:ok, members} ->
        socket
        |> assign_form(Accounts.change_membership_invite())
        |> stream(:members, members, reset: true)

      {:error, _reason} ->
        unauthorized(socket)
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: :membership_invite)
    assign(socket, form: form)
  end

  defp role_options do
    [
      {"Owner — Full access, including billing", :owner},
      {"Admin — Full access, except billing", :admin},
      {"Staff — Cases, customers, sessions", :staff},
      {"Member — View and work on assigned cases", :member},
      {"Viewer — Read-only access", :viewer}
    ]
  end

  defp role_select_options do
    [
      {"Owner", :owner},
      {"Admin", :admin},
      {"Staff", :staff},
      {"Member", :member},
      {"Viewer", :viewer}
    ]
  end

  defp format_role(role), do: role |> Atom.to_string() |> String.capitalize()

  defp role_color(:owner), do: "primary"
  defp role_color(:admin), do: "info"
  defp role_color(:staff), do: "accent"
  defp role_color(:member), do: "success"
  defp role_color(:viewer), do: "neutral"
  defp role_color(_), do: "primary"

  defp format_date(nil, _tenant), do: "—"
  defp format_date(%DateTime{} = dt, tenant), do: Formatting.date(dt, tenant)

  defp unauthorized(socket) do
    socket
    |> put_flash(:error, "You do not have access to manage members.")
    |> redirect(to: ~p"/")
  end
end
