ExUnit.start()

{:ok, _, _} =
  Ecto.Migrator.with_repo(QTest.Repo, fn repo ->
    Ecto.Migrator.down(repo, 1, QTest.Repo.Migrations.SetupTables)
    Ecto.Migrator.up(repo, 1, QTest.Repo.Migrations.SetupTables)
  end)

QTest.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(QTest.Repo, :manual)
