defmodule QTest.Repo do
  use Ecto.Repo, otp_app: :qh, adapter: Ecto.Adapters.Postgres
end
