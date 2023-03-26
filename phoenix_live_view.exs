Application.put_env(:sample, Example.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64)
)

Mix.install([
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.0"},
  {:phoenix, "~> 1.7.2", override: true},
  {:phoenix_ecto, "~> 4.4"},
  {:phoenix_live_view, "~> 0.18.17"}
])

defmodule Example.ErrorView do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Example.Article do
  use Ecto.Schema
  import Ecto.Changeset

  schema "articles" do
    field(:title, :string)
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end
end

defmodule Example.HomeLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  import Phoenix.HTML.Form

  @articles [
    %Example.Article{title: "my title"},
    %Example.Article{title: "another article"}
  ]

  def mount(_params, _session, socket) do
    changeset = Ecto.Changeset.change(%Example.Article{title: ""})

    {:ok,
     socket
     |> assign(:form, Phoenix.Component.to_form(changeset))
     |> assign(:articles, @articles)}
  end

  def render("live.html", assigns) do
    ~H"""
    <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.1/priv/static/phoenix.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/phoenix_live_view@0.18.17/priv/static/phoenix_live_view.min.js"></script>
    <script>
      window.addEventListener("phx:page-loading-stop", info => {
      console.log("page loading stop", info)
      let el = document.getElementById("current-query-params")
      el.textContent = window.location.href
      })
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
    </script>
    <style>
      * { font-size: 1.1em; }

    </style>
    <%= @inner_content %>
    """
  end

  def render(assigns) do
    ~H"""
    <blockquote>
    Description:<br /> I would expect <b>phx:page-loading-stop</b>
    handler to execute in similar manner
    wether query parameters are updated with push_patch (text input) or with .link patch.<br /><br />
    On example case, content for <b>span id="current-query-params"</b>
    is lost when text is typed to search field or search field is cleared.
    </blockquote>
    <.form for={@form} phx-change="validate" onkeydown="return event.key != 'Enter';">
    <div>
      <label for="article_title">push_patch(socket, to: ~p"/?title=#{title}")</label>
      <%= text_input @form, :title %>
    </div>
    <br />
    <div>
      <label>
        .link patch={~p"/?title=my+title"}
      </label>
      <.link patch={"/?title=my+title"}>
        <button>
          update query parameters
        </button>
      </.link>
    </div>
    </.form>
    <hr />
    <p>Url from app.js: <i id="current-query-params" /></p>
    <div :for={article <- @articles}>
      <h5>title: <%= article.title %></h5>
    </div>
    """
  end

  def handle_params(%{"title" => title}, _url, socket) do
    articles = Enum.filter(@articles, fn article -> String.contains?(article.title, title) end)
    {:noreply, assign(socket, :articles, articles)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", %{"article" => %{"title" => title}}, socket) do
    {:noreply, push_patch(socket, to: "/?title=#{title}")}
  end
end

defmodule Example.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", Example do
    pipe_through(:browser)

    live("/", HomeLive, :index)
  end
end

defmodule Example.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket("/live", Phoenix.LiveView.Socket)
  plug(Example.Router)
end

{:ok, _} = Supervisor.start_link([Example.Endpoint], strategy: :one_for_one)
Process.sleep(:infinity)
