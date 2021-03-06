defmodule EZCalendar.CalendarBuilderTest do
  use ExUnit.Case
  alias EZCalendar.{CalendarBuilder, Repo, Shift, Event, TimexEvent, CalectoEvent}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EZCalendar.Repo)
  end

  defp build_dates query, start_date, end_date, opts \\ [] do
    CalendarBuilder.build(query, Repo, start_date, end_date, opts)
  end
 
  defp timex_datetime({year, month, day}) do
    Timex.parse!("#{year}-#{month}-#{day}", "{YYYY}-{M}-{D}")
  end

  defp ecto_datetime({year, month, day}) do
    Ecto.DateTime.from_erl({{year, month, day}, {0, 0, 0}})
  end

  defp calecto_datetime({year, month, day}) do
    Calendar.DateTime.from_erl!({{year, month, day}, {0, 0, 0}}, "UTC")
  end

  defp calendar_data dates do
    dates
    |> Enum.map(&(&1.data))
    |> List.flatten
    |> List.first
  end
 
  test "calendar dates have a today? flag" do
    today = DateTime.utc_now |> DateTime.to_date
    date = build_dates(Event, today, today) |> List.first

    assert date.today? == true
  end

  test "calendar dates include the weekday" do
    date = build_dates(Event, ~D[2016-10-30], ~D[2016-11-03]) |> List.first

    assert date.weekday == "Sunday"
  end

  test "calendar dates include date information" do
    date = build_dates(Event, ~D[2016-10-30], ~D[2016-11-03]) |> List.first

    assert date.day == 30
    assert date.month == 10
    assert date.year == 2016
  end

  test "calendar dates include query results for proper day" do
    %Event{ date: ~D[2016-10-30] |> Ecto.Date.cast! } |> Repo.insert!
    %Event{ date: ~D[2016-11-03] |> Ecto.Date.cast! } |> Repo.insert!
    dates = build_dates(Event, ~D[2016-10-30], ~D[2016-11-03])
    
    data1 = List.first(dates) |> Map.get(:data) |> List.first
    data2 = List.last(dates) |> Map.get(:data)  |> List.first

    assert data1.__struct__ == EZCalendar.Event
    assert Ecto.Date.to_erl(data1.date) == {2016, 10, 30}
    assert Ecto.Date.to_erl(data2.date) == {2016, 11, 3}
  end

  test "calendars can be built from a given field" do
    %Event{ title: "Posted", posted_on: ~D[2016-11-01] |> Ecto.Date.cast! } |> Repo.insert!
    
    event = build_dates(Event, ~D[2016-11-01], ~D[2016-11-01], field: :posted_on)
    |> calendar_data
    
    assert event.title == "Posted"
  end
  
  test "Ecto.Date is a valid schema type" do
    %Event{title: "Date", date: ~D[2016-10-30] |> Ecto.Date.cast!} |> Repo.insert!

    event = build_dates(Event, ~D[2016-10-30], ~D[2016-10-30], field: :date)
    |> calendar_data

    assert event.title == "Date"
  end
  
  test "Ecto.DateTime is a valid schema type" do
    %Event{title: "DateTime", datetime: ecto_datetime({2016, 10, 30})} |> Repo.insert!

    event = build_dates(Event, ~D[2016-10-30], ~D[2016-10-30], field: :datetime)
    |> calendar_data

    assert event.title == "DateTime"
  end

  test "Timex.Ecto.Date is a valid schema type" do
    %TimexEvent{title: "Timex Date", date: ~D[2016-10-30]} |> Repo.insert!

    event = build_dates(TimexEvent, ~D[2016-10-30], ~D[2016-10-30], [])
    |> calendar_data

    assert event.title == "Timex Date"
  end

  test "Timex.Ecto.DateTime is a valid schema type" do
    %TimexEvent{title: "Timex DateTime", datetime: timex_datetime({2016, 10, 30})} |> Repo.insert!

    event = build_dates(TimexEvent, ~D[2016-10-30], ~D[2016-10-30], field: :datetime)
    |> calendar_data

    assert event.title == "Timex DateTime"
  end

  test "Calecto.Date is a valid schema type" do
    %CalectoEvent{title: "Calecto Date", date: ~D[2016-10-30]} |> Repo.insert!

    event = build_dates(CalectoEvent, ~D[2016-10-30], ~D[2016-10-30])
    |> calendar_data

    assert event.title == "Calecto Date"
  end

  test "Calecto.DateTimeUTC is a valid schema type" do
    %TimexEvent{title: "Calecto DateTime", datetime: calecto_datetime({2016, 10, 30})} |> Repo.insert!

    event = build_dates(TimexEvent, ~D[2016-10-30], ~D[2016-10-30], field: :datetime)
    |> calendar_data

    assert event.title == "Calecto DateTime"
  end

  test "can accept a keyword list of queries" do
    %Event{ title: "Posted", date: ~D[2016-11-01] |> Ecto.Date.cast! } |> Repo.insert!
    %Shift{ employee: "Name", date: ~D[2016-11-01] |> Ecto.Date.cast! } |> Repo.insert!
    
    dates = [
      events: [Event, :date],
      shifts: [Shift, :date]
    ]
    |> build_dates(~D[2016-11-01], ~D[2016-11-01])
    
    data = dates |> List.first |> Map.get(:data)
    
    event = data.events |> List.first
    shift = data.shifts |> List.first

    assert event.__struct__ == Event
    assert shift.__struct__ == Shift
  end

  test "can accept a tuple for the field name to use as a range" do
    %Shift{starting: ecto_datetime({2016, 11, 01}), ending: ecto_datetime({2016, 11, 02}) } |> Repo.insert!
    
    ### Multi Query

    dates = [
      shifts: [Shift, {:starting, :ending}]
    ]
    |> build_dates(~D[2016-10-31], ~D[2016-11-03])

    day1 = dates |> Enum.at(0) |> Map.get(:data) |> Map.get(:shifts)
    assert day1 == []
    day2 = dates |> Enum.at(1) |> Map.get(:data) |> Map.get(:shifts) |> List.first |> Map.get(:__struct__)
    assert day2 == Shift
    day3 = dates |> Enum.at(2) |> Map.get(:data) |> Map.get(:shifts) |> List.first |> Map.get(:__struct__)
    assert day3 == Shift
    day4 = dates |> Enum.at(3) |> Map.get(:data) |> Map.get(:shifts)
    assert day4 == []
    
    ### Single Query

    dates = build_dates(Shift, ~D[2016-10-31], ~D[2016-11-03], field: {:starting, :ending})

    day1 = dates |> Enum.at(0) |> Map.get(:data)
    assert day1 == []
    day2 = dates |> Enum.at(1) |> Map.get(:data) |> List.first |> Map.get(:__struct__)
    assert day2 == Shift
    day3 = dates |> Enum.at(2) |> Map.get(:data) |> List.first |> Map.get(:__struct__)
    assert day3 == Shift
    day4 = dates |> Enum.at(3) |> Map.get(:data)
    assert day4 == []

  end

end
