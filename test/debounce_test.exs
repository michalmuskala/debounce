defmodule DebounceTest do
  use ExUnit.Case
  doctest Debounce

  test "single apply with mfargs" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    refute_receive :done, 15
    assert :ok = Debounce.apply(pid)
    assert_receive :done, 15
    refute_receive :done
  end

  test "single apply with fun" do
    test = self()
    {:ok, pid} = Debounce.start_link(fn -> send(test, :done) end, 10)
    refute_receive :done, 15
    assert :ok = Debounce.apply(pid)
    assert_receive :done, 15
    refute_receive :done
  end

  test "single apply with mfargs passing arguments" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self()]}, 10)
    refute_receive :done, 15
    assert :ok = Debounce.apply(pid, [:done])
    assert_receive :done, 15
    refute_receive :done
  end

  test "single apply with fun passing arguments" do
    {:ok, pid} = Debounce.start_link(fn to -> send(to, :done) end, 10)
    refute_receive :done, 15
    assert :ok = Debounce.apply(pid, [self()])
    assert_receive :done, 15
    refute_receive :done
  end

  test "multiple apply within timeout" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    refute_receive :done, 5
    assert :ok = Debounce.apply(pid)
    assert_receive :done, 15
    refute_receive :done
  end

  test "multiple apply after timeout" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    assert_receive :done, 15
    assert :ok = Debounce.apply(pid)
    assert_receive :done, 15
    refute_receive :done
  end

  test "cancel without apply" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.cancel(pid)
  end

  test "cancel after apply" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    assert :ok = Debounce.cancel(pid)
    refute_receive :done
  end

  test "change_function does not affect current timer" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    assert :ok = Debounce.change_function(pid, {:erlang, :send, [self(), :new]})
    assert_receive :done, 15
  end

  test "change_function affects future timers" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.change_function(pid, {:erlang, :send, [self(), :new]})
    assert :ok = Debounce.apply(pid)
    assert_receive :new, 15
  end

  test "change_timeout does not affect current timer" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.apply(pid)
    assert :ok = Debounce.change_timeout(pid, 100)
    assert_receive :done, 15
  end

  test "change_timeout affects future timers" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self(), :done]}, 10)
    assert :ok = Debounce.change_timeout(pid, 100)
    assert :ok = Debounce.apply(pid)
    refute_receive :done, 15
    assert_receive :done, 100
  end

  test "flush without apply" do
    {:ok, pid} = Debounce.start_link(fn to -> send(to, :done) end, 10)
    assert :ok = Debounce.flush(pid, [self()])
    assert_received :done
  end

  test "flush after apply" do
    {:ok, pid} = Debounce.start_link({:erlang, :send, [self()]}, 10)
    assert :ok = Debounce.apply(pid, [:not_done])
    assert :ok = Debounce.flush(pid, [:done])
    assert_received :done
    refute_receive :not_done
  end
end
