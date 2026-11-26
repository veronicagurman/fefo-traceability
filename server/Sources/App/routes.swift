import Vapor

struct HealthResponse: Content {
    let status: String
    let service: String
}

func routes(_ app: Application) throws {
    app.get("api", "health") { _ async throws -> HealthResponse in
        HealthResponse(
            status: "ok",
            service: "fefo-traceability"
        )
    }

    let auth = AuthController()

    app.post("api", "auth", "register", use: auth.register)
    app.post("api", "auth", "login", use: auth.login)

    let authenticated = app.grouped(BearerTokenMiddleware())

    authenticated.get("api", "auth", "me", use: auth.me)
    authenticated.post("api", "auth", "logout", use: auth.logout)

    let allRoles: Set<String> = Set(AppUserRole.allCases.map(\.rawValue))

    let productReaders = authenticated.grouped(
        RoleMiddleware(allowedRoles: allRoles)
    )

    let products = ProductController()

    productReaders.get("api", "products", use: products.index)
    productReaders.get("api", "products", ":id", use: products.show)

    let productWriters = authenticated.grouped(
        RoleMiddleware(
            allowedRoles: [
                AppUserRole.admin.rawValue,
                AppUserRole.warehouseManager.rawValue
            ]
        )
    )

    productWriters.post("api", "products", use: products.create)

    let batchReaders = authenticated.grouped(
        RoleMiddleware(allowedRoles: allRoles)
    )

    let batches = BatchController()

    batchReaders.get("api", "batches", use: batches.index)

    let batchWriters = authenticated.grouped(
        RoleMiddleware(
            allowedRoles: [
                AppUserRole.admin.rawValue,
                AppUserRole.warehouseWorker.rawValue,
                AppUserRole.warehouseManager.rawValue
            ]
        )
    )

    batchWriters.post("api", "batches", use: batches.create)

    let warehouseReaders = authenticated.grouped(
        RoleMiddleware(allowedRoles: allRoles)
    )

    let warehouses = WarehouseController()

    warehouseReaders.get("api", "warehouses", use: warehouses.index)

    let warehouseWriters = authenticated.grouped(
        RoleMiddleware(
            allowedRoles: [
                AppUserRole.admin.rawValue,
                AppUserRole.warehouseManager.rawValue
            ]
        )
    )

    warehouseWriters.post("api", "warehouses", use: warehouses.create)

    let locationReaders = authenticated.grouped(
        RoleMiddleware(allowedRoles: allRoles)
    )

    let locations = StorageLocationController()

    locationReaders.get(
        "api",
        "storage-locations",
        use: locations.index
    )

    let locationWriters = authenticated.grouped(
        RoleMiddleware(
            allowedRoles: [
                AppUserRole.admin.rawValue,
                AppUserRole.warehouseWorker.rawValue,
                AppUserRole.warehouseManager.rawValue
            ]
        )
    )

    locationWriters.post(
        "api",
        "storage-locations",
        use: locations.create
    )
    let placementReaders = authenticated.grouped(
        RoleMiddleware(allowedRoles: allRoles)
    )
    let placements = BatchPlacementController()
    placementReaders.get(
        "api", "batch-placements",
        use: placements.index
    )

    let placementWriters = authenticated.grouped(
        RoleMiddleware(allowedRoles: [
            AppUserRole.admin.rawValue,
            AppUserRole.warehouseWorker.rawValue,
            AppUserRole.warehouseManager.rawValue
        ])
    )
    placementWriters.post(
        "api", "batch-placements",
        use: placements.create
    )
    
    let movementReaders = authenticated.grouped(
        RoleMiddleware(allowedRoles: allRoles)
    )
    let movements = StockMovementController()

    movementReaders.get(
        "api", "stock-movements",
        use: movements.index
    )

    let movementWriters = authenticated.grouped(
        RoleMiddleware(allowedRoles: [
            AppUserRole.admin.rawValue,
            AppUserRole.warehouseWorker.rawValue,
            AppUserRole.warehouseManager.rawValue
        ])
    )

    movementWriters.post(
        "api", "stock-movements",
        use: movements.create
    )
    

    let fefo = FEFOController()
    let fefoReaders = authenticated.grouped(
        RoleMiddleware(allowedRoles: allRoles)
    )
    fefoReaders.get("api", "fefo", use: fefo.index)

    let analytics = AnalyticsController()
    let analyticsReaders = authenticated.grouped(
        RoleMiddleware(allowedRoles: allRoles)
    )
    analyticsReaders.get("api", "analytics", use: analytics.index)
    
    let businessAnalytics = BusinessAnalyticsController()
    analyticsReaders.get("api", "analytics", "business", use: businessAnalytics.index)
}
