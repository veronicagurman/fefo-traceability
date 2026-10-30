import Fluent
import Vapor

struct FEFOService {
    func calculate(on db: Database) async throws -> FEFOResponse {
        let placements = try await BatchPlacement.query(on: db)
            .filter(\.$quantity > 0)
            .all()

        let batches = try await Batch.query(on: db).all()
        let products = try await Product.query(on: db).all()

        let batchesByID = Dictionary(
            uniqueKeysWithValues: batches.compactMap { batch in
                batch.id.map { ($0, batch) }
            }
        )

        let productsByID = Dictionary(
            uniqueKeysWithValues: products.compactMap { product in
                product.id.map { ($0, product) }
            }
        )

        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let today = calendar.startOfDay(for: now)

        var items: [FEFOItem] = []

        for placement in placements {
            let batchID = placement.$batch.id
            let locationID = placement.$storageLocation.id

            guard let batch = batchesByID[batchID] else {
                continue
            }

            guard let product = productsByID[batch.$product.id],
                  let productID = product.id else {
                continue
            }

            let expirationDay = calendar.startOfDay(for: batch.expiresAt)
            let daysUntilExpiration = calendar.dateComponents(
                [.day],
                from: today,
                to: expirationDay
            ).day ?? 0

            items.append(
                FEFOItem(
                    batchID: batchID,
                    batchNumber: batch.batchNumber,
                    productID: productID,
                    productName: product.name,
                    sku: product.sku,
                    storageLocationID: locationID,
                    quantity: placement.quantity,
                    expiresAt: batch.expiresAt,
                    daysUntilExpiration: daysUntilExpiration,
                    isExpired: expirationDay < today
                )
            )
        }

        items.sort {
            let firstDay = calendar.startOfDay(for: $0.expiresAt)
            let secondDay = calendar.startOfDay(for: $1.expiresAt)

            if firstDay != secondDay {
                return firstDay < secondDay
            }

            if $0.batchNumber != $1.batchNumber {
                return $0.batchNumber < $1.batchNumber
            }

            return $0.storageLocationID.uuidString < $1.storageLocationID.uuidString
        }

        return FEFOResponse(
            generatedAt: now,
            totalPositions: items.count,
            totalQuantity: items.reduce(0) { $0 + $1.quantity },
            expiredPositions: items.filter(\.isExpired).count,
            expiringWithinSevenDays: items.filter {
                !$0.isExpired &&
                $0.daysUntilExpiration >= 0 &&
                $0.daysUntilExpiration <= 7
            }.count,
            items: items
        )
    }
}
