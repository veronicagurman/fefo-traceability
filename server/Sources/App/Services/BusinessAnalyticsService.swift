import Fluent
import Vapor

struct BusinessAnalyticsService {
    private struct Position {
        let product: Product
        let batch: Batch
        let location: StorageLocation?
        let quantity: Int
        let daysLeft: Int
        let lifeLeftPercent: Double
    }

    func calculate(on db: Database) async throws -> BusinessAnalyticsResponse {
        let products = try await Product.query(on: db).all()
        let batches = try await Batch.query(on: db).all()
        let locations = try await StorageLocation.query(on: db).all()
        let users = try await AppUser.query(on: db).all()
        let movements = try await StockMovement.query(on: db).all()
        let placements = try await BatchPlacement.query(on: db)
            .filter(\.$quantity > 0)
            .all()

        let productsByID = index(products)
        let batchesByID = index(batches)
        let locationsByID = index(locations)
        let usersByID = index(users)

        let now = Date()
        let calendar = Self.makeCalendar()
        let today = calendar.startOfDay(for: now)

        func daysLeft(_ date: Date) -> Int {
            calendar.dateComponents(
                [.day],
                from: today,
                to: calendar.startOfDay(for: date)
            ).day ?? 0
        }

        func lifeLeft(_ batch: Batch) -> Double {
            let total = batch.expiresAt.timeIntervalSince(batch.receivedAt)
            guard total > 0 else { return 0 }
            let left = batch.expiresAt.timeIntervalSince(now)
            return min(100, max(0, left / total * 100))
        }

        func sum(_ items: [Position]) -> Int {
            items.reduce(0) { $0 + $1.quantity }
        }

        // Позиции: партия в ячейке
        var positions: [Position] = []
        for placement in placements {
            guard let batch = batchesByID[placement.$batch.id],
                  let product = productsByID[batch.$product.id] else {
                continue
            }

            positions.append(
                Position(
                    product: product,
                    batch: batch,
                    location: locationsByID[placement.$storageLocation.id],
                    quantity: placement.quantity,
                    daysLeft: daysLeft(batch.expiresAt),
                    lifeLeftPercent: lifeLeft(batch)
                )
            )
        }

        let totalQty = sum(positions)
        let expiredQty = sum(positions.filter { $0.daysLeft < 0 })
        let atRiskQty = sum(positions.filter { $0.daysLeft >= 0 && $0.daysLeft <= 7 })

        let lifeWeighted = positions.reduce(0.0) {
            $0 + $1.lifeLeftPercent * Double($1.quantity)
        }
        let avgLife = totalQty > 0
            ? Self.round1(lifeWeighted / Double(totalQty))
            : 0

        // Принято, но не размещено
        var placedByBatch: [UUID: Int] = [:]
        for placement in placements {
            placedByBatch[placement.$batch.id, default: 0] += placement.quantity
        }

        var unplaced = 0
        for batch in batches {
            guard let id = batch.id else { continue }
            unplaced += max(0, batch.remainingQuantity - (placedByBatch[id] ?? 0))
        }

        // Ячейки
        let occupiedIDs = Set(placements.map { $0.$storageLocation.id })
        let occupancy = Self.percent(occupiedIDs.count, of: locations.count)

        // Движения за 30 дней
        let from30 = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let recent = movements.filter { $0.createdAt >= from30 }
        let movedQty = recent.reduce(0) { $0 + $1.quantity }

        // Корзины по сроку годности
        let expiryLabels = [
            "Просрочено", "до 7 дней", "8-30 дней", "31-90 дней", "более 90 дней"
        ]

        func expiryIndex(_ days: Int) -> Int {
            switch days {
            case ..<0: return 0
            case 0...7: return 1
            case 8...30: return 2
            case 31...90: return 3
            default: return 4
            }
        }

        var expiryQty = Array(repeating: 0, count: expiryLabels.count)
        var expiryPos = Array(repeating: 0, count: expiryLabels.count)
        for position in positions {
            let i = expiryIndex(position.daysLeft)
            expiryQty[i] += position.quantity
            expiryPos[i] += 1
        }

        let expiryBuckets = expiryLabels.indices.map { i in
            BizBucket(
                order: i,
                label: expiryLabels[i],
                quantity: expiryQty[i],
                positions: expiryPos[i]
            )
        }

        // Корзины по доле оставшегося срока
        let lifeLabels = [
            "Просрочено", "до 25% срока", "25-50% срока", "50-75% срока", "более 75% срока"
        ]

        func lifeIndex(_ position: Position) -> Int {
            if position.daysLeft < 0 { return 0 }
            if position.lifeLeftPercent < 25 { return 1 }
            if position.lifeLeftPercent < 50 { return 2 }
            if position.lifeLeftPercent < 75 { return 3 }
            return 4
        }

        var lifeQty = Array(repeating: 0, count: lifeLabels.count)
        var lifePos = Array(repeating: 0, count: lifeLabels.count)
        for position in positions {
            let i = lifeIndex(position)
            lifeQty[i] += position.quantity
            lifePos[i] += 1
        }

        let shelfLifeBuckets = lifeLabels.indices.map { i in
            BizBucket(
                order: i,
                label: lifeLabels[i],
                quantity: lifeQty[i],
                positions: lifePos[i]
            )
        }

        // Прогноз истечения на 8 недель
        var weekQty = Array(repeating: 0, count: 8)
        var weekPos = Array(repeating: 0, count: 8)
        for position in positions where position.daysLeft >= 0 && position.daysLeft < 56 {
            let week = position.daysLeft / 7
            weekQty[week] += position.quantity
            weekPos[week] += 1
        }

        let expiryTimeline = (0..<8).map { week in
            BizWeek(
                fromDay: week * 7,
                toDay: week * 7 + 6,
                quantity: weekQty[week],
                positions: weekPos[week]
            )
        }

        // Зоны склада
        let zones: [BizZone] = Set(locations.map(\.zone)).sorted().map { zone in
            let zoneLocations = locations.filter { $0.zone == zone }
            let zonePositions = positions.filter { $0.location?.zone == zone }

            var occupied = 0
            for location in zoneLocations {
                if let id = location.id, occupiedIDs.contains(id) {
                    occupied += 1
                }
            }

            return BizZone(
                zone: zone,
                quantity: sum(zonePositions),
                locations: zoneLocations.count,
                occupiedLocations: occupied,
                expiredQuantity: sum(zonePositions.filter { $0.daysLeft < 0 }),
                atRiskQuantity: sum(
                    zonePositions.filter { $0.daysLeft >= 0 && $0.daysLeft <= 7 }
                )
            )
        }

        // ABC-анализ по размещённому остатку
        var qtyByProduct: [UUID: Int] = [:]
        for position in positions {
            if let id = position.product.id {
                qtyByProduct[id, default: 0] += position.quantity
            }
        }

        var ranked: [(product: Product, quantity: Int)] = []
        for (id, quantity) in qtyByProduct {
            if let product = productsByID[id] {
                ranked.append((product: product, quantity: quantity))
            }
        }
        ranked.sort {
            $0.quantity != $1.quantity
                ? $0.quantity > $1.quantity
                : $0.product.name < $1.product.name
        }

        var cumulative = 0
        var abcAll: [BizABCItem] = []
        for entry in ranked {
            let before = totalQty > 0
                ? Double(cumulative) / Double(totalQty) * 100
                : 0
            cumulative += entry.quantity

            let abcClass = before < 80 ? "A" : (before < 95 ? "B" : "C")

            abcAll.append(
                BizABCItem(
                    productName: entry.product.name,
                    sku: entry.product.sku,
                    quantity: entry.quantity,
                    sharePercent: Self.percent(entry.quantity, of: totalQty),
                    cumulativePercent: Self.percent(cumulative, of: totalQty),
                    abcClass: abcClass
                )
            )
        }

        let abcSummary = ["A", "B", "C"].map { letter -> BizABCClass in
            let items = abcAll.filter { $0.abcClass == letter }
            let quantity = items.reduce(0) { $0 + $1.quantity }
            return BizABCClass(
                abcClass: letter,
                products: items.count,
                quantity: quantity,
                sharePercent: Self.percent(quantity, of: totalQty)
            )
        }

        // Товары с риском
        var byProduct: [UUID: [Position]] = [:]
        for position in positions {
            if let id = position.product.id {
                byProduct[id, default: []].append(position)
            }
        }

        var risks: [BizProductRisk] = []
        for items in byProduct.values {
            guard let first = items.first else { continue }

            let expired = sum(items.filter { $0.daysLeft < 0 })
            let atRisk = sum(items.filter { $0.daysLeft >= 0 && $0.daysLeft <= 7 })
            guard expired + atRisk > 0 else { continue }

            risks.append(
                BizProductRisk(
                    productName: first.product.name,
                    sku: first.product.sku,
                    quantity: sum(items),
                    batches: Set(items.compactMap { $0.batch.id }).count,
                    expiredQuantity: expired,
                    atRiskQuantity: atRisk,
                    nearestDaysLeft: items.map(\.daysLeft).min()
                )
            )
        }
        risks.sort {
            let left = $0.expiredQuantity + $0.atRiskQuantity
            let right = $1.expiredQuantity + $1.atRiskQuantity
            return left != right ? left > right : $0.productName < $1.productName
        }
        let productRisks = Array(risks.prefix(15))

        // Динамика перемещений по дням
        var perDay: [Date: (operations: Int, quantity: Int)] = [:]
        for movement in recent {
            let day = calendar.startOfDay(for: movement.createdAt)
            var current = perDay[day] ?? (operations: 0, quantity: 0)
            current.operations += 1
            current.quantity += movement.quantity
            perDay[day] = current
        }

        let movementsByDay = (0..<30).compactMap { offset -> BizDayStat? in
            guard let raw = calendar.date(byAdding: .day, value: offset, to: from30) else {
                return nil
            }
            let day = calendar.startOfDay(for: raw)
            let value = perDay[day]
            return BizDayStat(
                date: day,
                operations: value?.operations ?? 0,
                quantity: value?.quantity ?? 0
            )
        }

        // Активность пользователей
        var userAgg: [String: (operations: Int, quantity: Int)] = [:]
        for movement in recent {
            let name = movement.$user.id.flatMap { usersByID[$0]?.email } ?? "Не указан"
            var current = userAgg[name] ?? (operations: 0, quantity: 0)
            current.operations += 1
            current.quantity += movement.quantity
            userAgg[name] = current
        }

        var topUsers = userAgg.map {
            BizUserStat(
                user: $0.key,
                operations: $0.value.operations,
                quantity: $0.value.quantity
            )
        }
        topUsers.sort {
            $0.operations != $1.operations
                ? $0.operations > $1.operations
                : $0.user < $1.user
        }

        // Самые частые маршруты
        func code(_ id: UUID?) -> String {
            guard let id, let location = locationsByID[id] else {
                return "не указана"
            }
            return location.code
        }

        var routeAgg: [String: (operations: Int, quantity: Int)] = [:]
        for movement in recent {
            let route = "\(code(movement.$fromLocation.id)) → \(code(movement.$toLocation.id))"
            var current = routeAgg[route] ?? (operations: 0, quantity: 0)
            current.operations += 1
            current.quantity += movement.quantity
            routeAgg[route] = current
        }

        var topRoutes = routeAgg.map {
            BizRouteStat(
                route: $0.key,
                operations: $0.value.operations,
                quantity: $0.value.quantity
            )
        }
        topRoutes.sort {
            $0.operations != $1.operations
                ? $0.operations > $1.operations
                : $0.route < $1.route
        }

        // Рекомендации
        var insights: [BizInsight] = []

        if expiredQty > 0 {
            insights.append(
                BizInsight(
                    level: "critical",
                    text: "Просрочено \(expiredQty) шт. (\(Self.percent(expiredQty, of: totalQty))% размещённого остатка). Нужно списание или утилизация."
                )
            )
        }

        if atRiskQty > 0 {
            insights.append(
                BizInsight(
                    level: "warning",
                    text: "В ближайшие 7 дней истекает срок годности у \(atRiskQty) шт. Отгружайте их в первую очередь по правилу FEFO."
                )
            )
        }

        if unplaced > 0 {
            insights.append(
                BizInsight(
                    level: "warning",
                    text: "Принято, но не размещено по ячейкам: \(unplaced) шт. Такой товар не попадает в FEFO-очередь."
                )
            )
        }

        if !locations.isEmpty && occupancy >= 90 {
            insights.append(
                BizInsight(
                    level: "warning",
                    text: "Заполненность ячеек \(occupancy)%. Свободных мест почти не осталось."
                )
            )
        }

        if let classA = abcSummary.first(where: { $0.abcClass == "A" }), classA.products > 0 {
            insights.append(
                BizInsight(
                    level: "info",
                    text: "Класс A: \(classA.products) тов. формируют около 80% остатков. Держите их запас под особым контролем."
                )
            )
        }

        if recent.isEmpty {
            insights.append(
                BizInsight(
                    level: "info",
                    text: "За последние 30 дней перемещений не было."
                )
            )
        }

        if expiredQty == 0 && atRiskQty == 0 {
            insights.insert(
                BizInsight(
                    level: "info",
                    text: "Критичных рисков по срокам годности не выявлено."
                ),
                at: 0
            )
        }

        return BusinessAnalyticsResponse(
            generatedAt: now,
            kpi: BizKPI(
                totalQuantity: totalQty,
                totalPositions: positions.count,
                expiredQuantity: expiredQty,
                atRiskQuantity: atRiskQty,
                expiredSharePercent: Self.percent(expiredQty, of: totalQty),
                atRiskSharePercent: Self.percent(atRiskQty, of: totalQty),
                avgShelfLifeLeftPercent: avgLife,
                unplacedQuantity: unplaced,
                totalLocations: locations.count,
                occupiedLocations: occupiedIDs.count,
                occupancyPercent: occupancy,
                movementsLast30Days: recent.count,
                movedQuantityLast30Days: movedQty
            ),
            insights: insights,
            expiryBuckets: expiryBuckets,
            shelfLifeBuckets: shelfLifeBuckets,
            expiryTimeline: expiryTimeline,
            zones: zones,
            abc: Array(abcAll.prefix(30)),
            abcSummary: abcSummary,
            productRisks: productRisks,
            movementsByDay: movementsByDay,
            topUsers: Array(topUsers.prefix(8)),
            topRoutes: Array(topRoutes.prefix(8))
        )
    }

    private func index<M: Model>(_ items: [M]) -> [UUID: M] where M.IDValue == UUID {
        var result: [UUID: M] = [:]
        for item in items {
            if let id = item.id {
                result[id] = item
            }
        }
        return result
    }

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    private static func percent(_ part: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return (Double(part) / Double(total) * 1000).rounded() / 10
    }

    private static func round1(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
