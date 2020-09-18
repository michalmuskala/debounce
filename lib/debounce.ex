defmodule Debounce do
  @moduledoc """
  A process-based debouncer for Elixir.

  ## What is a debouncer?

  A debouncer is responsible for calling a function with a delay, but if that
  function is called multiple times within the delay period, the time is reset
  and delay is counted again. In other words, the function will be called
  after a delay period has elapsed from the last application.

  Each time, the debounced function is called, a new task is started.

  ## Example

      iex> {:ok, pid} = Debounce.start_link({Kernel, :send, [self(), "Hello"]}, 100)
      iex> Debounce.apply(pid)  # Schedules call in 100 ms
      iex> :timer.sleep(50)
      iex> Debounce.apply(pid)  # Resets timer back to 100 ms
      iex> :timer.sleep(100)
      iex> receive do msg -> msg end
      "Hello"                   # Timer elapsed
      iex> Debounce.apply(pid)  # Schedules call in 100 ms
      iex> Debounce.cancel(pid) # Cancels scheduled call
      :ok

  """

  @behaviour :gen_statem

  @type mfargs :: {module, atom, [term]}
  @type apply :: (() -> term) | mfargs
  @type time :: non_neg_integer
  @type debouncer :: :gen_statem.server_ref()
  @type option :: {:name, GenServer.name()} | :gen_statem.start_opt()

  defmacrop is_apply(apply) do
    quote do
      is_function(unquote(apply)) or
        (is_atom(elem(unquote(apply), 0)) and
           is_atom(elem(unquote(apply), 1)) and
           is_list(elem(unquote(apply), 2)))
    end
  end

  @doc """
  Starts a `Debounce` process linked to the current process.

  This can be used to start the `Debounce` as part of a supervision tree.

  Delays invoking `apply` until after `timeout` millisecnds have elapsed
  since the last time the `apply/2` function was called.

  ## Options

    * `:name`- used for name registration, like in `GenServer.start_link/3`.
    * all other options supported by `:gen_statem.start_link/4`

  """
  @spec start_link(apply, time, [option]) :: :gen_statem.start_ret()
  def start_link(apply, timeout, opts \\ []) do
    do_start(:start_link, apply, timeout, opts)
  end

  @doc """
  Starts a `Debounce` process without links (outside of a supervision tree).

  See `start_link/3` for more information.
  """
  @spec start(apply, time, [option]) :: :gen_statem.start_ret()
  def start(apply, timeout, opts \\ []) do
    do_start(:start, apply, timeout, opts)
  end

  @doc """
  Synchronously stops the debouncer with the given `reason`.
  """
  @spec stop(debouncer, reason :: term, timeout) :: :ok
  def stop(debouncer, reason \\ :normal, timeout \\ :infinity) do
    :gen_statem.stop(debouncer, reason, timeout)
  end

  @doc """
  Schedules call to the current `debouncer`'s function.

  If the function is a fun, calls it with provided `args`.
  If the function is an `t:mfargs/0` tuple, appends provided `args`
  to the original ones.

  If this function is called again withing the current `debouncer`'s timeout
  value, the time will reset.
  """
  @spec apply(debouncer, [term]) :: :ok
  def apply(debouncer, args \\ []) do
    call(debouncer, {:apply, args})
  end

  @doc """
  Cancels any scheduled call to the current `debouncer`'s function.
  """
  @spec cancel(debouncer) :: :ok
  def cancel(debouncer) do
    call(debouncer, :cancel)
  end

  @doc """
  Immediately invokes the current `debouncer`'s function.

  If the function is a fun, calls it with provided `args`.
  If the function is an `t:mfargs/0` tuple, appends provided `args`
  to the original ones.
  """
  @spec flush(debouncer, [term]) :: :ok
  def flush(debouncer, args) do
    call(debouncer, {:flush, args})
  end

  @doc """
  Changes the function the `debouncer` is applying.

  Affects only future calls to `apply/2`.
  """
  @spec change_function(debouncer, apply) :: :ok
  def change_function(debouncer, new_function) do
    call(debouncer, {:change_function, new_function})
  end

  @doc """
  Changes the delay the `debouncer` operates with.

  Affects only future calls to `apply/2`.
  """
  @spec change_timeout(debouncer, time) :: :ok
  def change_timeout(debouncer, new_timeout) when is_integer(new_timeout) do
    call(debouncer, {:change_timeout, new_timeout})
  end

  ## Callbacks

  import Record

  defrecordp :data, [:apply, :timeout]

  @doc false
  def callback_mode, do: :state_functions

  @doc false
  def init({apply, timeout}) do
    {:ok, :waiting, data(apply: apply, timeout: timeout)}
  end

  @doc false
  def waiting({:call, from}, {:apply, args}, data(apply: apply, timeout: timeout) = data) do
    {:next_state, :counting, data,
     [{:reply, from, :ok}, {:state_timeout, timeout, {apply, args}}]}
  end

  def waiting({:call, from}, :cancel, data) do
    {:keep_state, data, {:reply, from, :ok}}
  end

  def waiting(event, event_content, data) do
    handle_event(event, event_content, data)
  end

  @doc false
  def counting({:call, from}, {:apply, args}, data(apply: apply, timeout: timeout) = data) do
    {:keep_state, data, [{:reply, from, :ok}, {:state_timeout, timeout, {apply, args}}]}
  end

  def counting({:call, from}, :cancel, data) do
    {:next_state, :waiting, data, {:reply, from, :ok}}
  end

  def counting(:state_timeout, {apply, args}, data) do
    apply_function(apply, args)
    {:next_state, :waiting, data}
  end

  def counting(event, event_content, data) do
    handle_event(event, event_content, data)
  end

  defp handle_event({:call, from}, {:change_function, apply}, data) do
    {:keep_state, data(data, apply: apply), {:reply, from, :ok}}
  end

  defp handle_event({:call, from}, {:change_timeout, timeout}, data) do
    {:keep_state, data(data, timeout: timeout), {:reply, from, :ok}}
  end

  defp handle_event({:call, from}, {:flush, args}, data(apply: apply) = data) do
    apply_function(apply, args)
    {:next_state, :waiting, data, {:reply, from, :ok}}
  end

  defp handle_event({:call, _from}, msg, data) do
    {:stop, {:bad_call, msg}, data}
  end

  defp handle_event(:cast, msg, data) do
    {:stop, {:bad_cast, msg}, data}
  end

  defp handle_event(:info, msg, data) do
    proc =
      case Process.info(self(), :registered_name) do
        {_, []} -> self()
        {_, name} -> name
      end

    :error_logger.error_msg(
      '~p ~p received unexpected message: ~p~n',
      [__MODULE__, proc, msg]
    )

    {:keep_state, data}
  end

  @doc false
  def terminate(_reason, _state, _data) do
    :ok
  end

  @doc false
  def code_change(_vsn, state, data, _extra) do
    {:ok, state, data}
  end

  ## Helpers

  defp do_start(start, apply, timeout, opts) when is_apply(apply) and is_integer(timeout) do
    if name = name(opts[:name]) do
      apply(:gen_statem, start, [name, __MODULE__, {apply, timeout}, opts])
    else
      apply(:gen_statem, start, [__MODULE__, {apply, timeout}, opts])
    end
  end

  defp name(nil), do: nil
  defp name(atom) when is_atom(atom), do: {:local, atom}
  defp name(other), do: other

  defp call(debounce, request) do
    :gen_statem.call(debounce, request, {:dirty_timeout, 5_000})
  end

  defp apply_function({m, f, a}, args) do
    Task.Supervisor.start_child(Debounce.Supervisor, m, f, a ++ args)
  end

  defp apply_function(fun, args) do
    Task.Supervisor.start_child(Debounce.Supervisor, :erlang, :apply, [fun, args])
  end
end
