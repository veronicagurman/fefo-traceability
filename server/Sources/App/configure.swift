import Fluent
import FluentPostgresDriver
import Vapor

func configure(_ app: Application) throws {
    let databaseUsername = Environment.get("DATABASE_USERNAME") ?? Environment.get("USER") ?? "postgres"

    let databaseHost = Environment.get("DATABASE_HOST") ?? "127.0.0.1"
    let databasePort = Int(Environment.get("DATABASE_PORT") ?? "5432") ?? 5432
    let databasePassword = Environment.get("DATABASE_PASSWORD") ?? ""
    let databaseName = Environment.get("DATABASE_NAME") ?? "fefo_traceability"

    app.databases.use(
        .postgres(
            configuration: .init(
                hostname: databaseHost,
                port: databasePort,
                username: databaseUsername,
                password: databasePassword,
                database: databaseName,
                tls: .disable
            )
        ),
        as: .psql
    )

    app.migrations.add(CreateProduct())
    app.migrations.add(CreateBatch())
    app.migrations.add(CreateAppUser())
    app.migrations.add(CreateAuthToken())
    app.migrations.add(CreateWarehouse())
    app.migrations.add(CreateStorageLocation())
    app.migrations.add(CreateBatchPlacement())
    app.migrations.add(CreateStockMovement())
    app.migrations.add(AddUserToStockMovement())

    try routes(app)
}
