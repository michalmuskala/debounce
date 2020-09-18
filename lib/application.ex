defmodule Debounce.Application do
  @moduledoc false

  use Application

  def start(_, _) do
    children = [
      {Task.Supervisor, name: Debounce.Supervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
