defmodule SwatiWeb.AboutBusinessLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Tenancy

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl space-y-6">
        <div class="space-y-1">
          <h1 class="text-2xl font-semibold text-base-content">About business</h1>
          <p class="text-sm text-base-content/70">
            Tenant-level context used across agents.
          </p>
        </div>

        <.form for={@form} id="about-business-form" phx-change="validate" phx-submit="save">
          <div class="space-y-6 rounded-2xl border border-base-300 bg-base-100 p-6">
            <div class="flex items-center justify-between">
              <h2 class="text-sm font-semibold text-base-content">Business profile</h2>
              <.badge variant="soft" color="info" size="xs">
                {about_business_word_count(@form)}
              </.badge>
            </div>

            <div class="space-y-5">
              <div class="space-y-2">
                <.textarea
                  field={@form[:business_identity]}
                  label="Identity"
                  rows={5}
                  maxlength={500}
                />
                <ul class="list-disc space-y-1 pl-5 text-xs text-base-content/70">
                  <li>Business name, location/service area, what you do</li>
                  <li>Support hours (timezone)</li>
                  <li>3 main services/products</li>
                </ul>
                <p class="text-xs text-base-content/50 text-right">
                  {word_count(@form[:business_identity].value)}
                </p>
              </div>

              <div class="space-y-2">
                <.textarea
                  field={@form[:business_brand_voice]}
                  label="Brand voice"
                  rows={5}
                  maxlength={500}
                />
                <ul class="list-disc space-y-1 pl-5 text-xs text-base-content/70">
                  <li>Tone (friendly/professional/etc.)</li>
                  <li>Always emphasize</li>
                  <li>Never say</li>
                </ul>
                <p class="text-xs text-base-content/50 text-right">
                  {word_count(@form[:business_brand_voice].value)}
                </p>
              </div>

              <div class="space-y-2">
                <.textarea
                  field={@form[:business_operating_boundaries]}
                  label="Operating boundaries"
                  rows={5}
                  maxlength={500}
                />
                <ul class="list-disc space-y-1 pl-5 text-xs text-base-content/70">
                  <li>What you can confirm vs must escalate</li>
                  <li>Never ask for OTP/passwords, etc.</li>
                </ul>
                <p class="text-xs text-base-content/50 text-right">
                  {word_count(@form[:business_operating_boundaries].value)}
                </p>
              </div>

              <div class="space-y-2">
                <.textarea
                  field={@form[:business_escalation_map]}
                  label="Escalation map"
                  rows={4}
                  maxlength={400}
                />
                <ul class="list-disc space-y-1 pl-5 text-xs text-base-content/70">
                  <li>3-6 lines: Billing -> Priya, Tech -> Hari, Medical -> doctor</li>
                  <li>This can be plain text.</li>
                </ul>
                <p class="text-xs text-base-content/50 text-right">
                  {word_count(@form[:business_escalation_map].value)}
                </p>
              </div>

              <div class="space-y-2">
                <.textarea
                  field={@form[:business_top_workflows]}
                  label="Top workflows"
                  rows={8}
                  maxlength={1200}
                />
                <ul class="list-disc space-y-1 pl-5 text-xs text-base-content/70">
                  <li>
                    3 short playbooks, 4-6 steps each (appointment booking, order status,
                    service booking, etc.)
                  </li>
                </ul>
                <p class="text-xs text-base-content/50 text-right">
                  {word_count(@form[:business_top_workflows].value)}
                </p>
              </div>
            </div>

            <div class="flex justify-end pt-2">
              <.button type="submit" variant="solid" phx-disable-with="Saving...">
                Save changes
              </.button>
            </div>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if Swati.Accounts.authorized?(socket.assigns.current_scope, :manage_settings) do
      tenant = Tenancy.get_tenant!(socket.assigns.current_scope.tenant.id)

      {:ok,
       socket
       |> assign(:tenant, tenant)
       |> assign(:form, to_form(Tenancy.change_about_business(tenant, %{}), as: :about_business))}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("validate", %{"about_business" => params}, socket) do
    changeset =
      Tenancy.change_about_business(socket.assigns.tenant, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: :about_business))}
  end

  @impl true
  def handle_event("save", %{"about_business" => params}, socket) do
    case Tenancy.update_about_business(socket.assigns.tenant, params) do
      {:ok, tenant} ->
        {:noreply,
         socket
         |> assign(:tenant, tenant)
         |> assign(
           :form,
           to_form(Tenancy.change_about_business(tenant, %{}), as: :about_business)
         )
         |> put_flash(:info, "About business updated.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(Map.put(changeset, :action, :validate), as: :about_business))}
    end
  end

  defp about_business_word_count(form) do
    [
      form[:business_identity].value,
      form[:business_brand_voice].value,
      form[:business_operating_boundaries].value,
      form[:business_escalation_map].value,
      form[:business_top_workflows].value
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
    |> word_count()
  end

  defp word_count(nil), do: "0 words"

  defp word_count(text) when is_binary(text) do
    count = text |> String.split(~r/\s+/, trim: true) |> length()
    "#{count} words"
  end

  defp word_count(_), do: "0 words"
end
