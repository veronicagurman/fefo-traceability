import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers

struct AnalyticsExtrasView: View {
    @EnvironmentObject private var api: APIService
    @StateObject private var viewModel: AnalyticsExtrasViewModel

    init(api: APIService, repository: any FEFORepository) {
        _viewModel = StateObject(
            wrappedValue: AnalyticsExtrasViewModel(repository: repository)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Аналитика склада")
                        .font(.title2.bold())

                    Text("Загрузка из базы данных склада")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if api.userRole != "sales_manager" {
                        Button {
                            viewModel.showingMoveSheet = true
                        } label: {
                            Label(
                                "Переместить товар",
                                systemImage: "arrow.left.arrow.right"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            (api.fefo?.items.isEmpty ?? true)
                                || api.locations.count < 2
                        )
                    }

                    Spacer()

                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Label(
                            "Обновить данные",
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .disabled(api.isLoading)
                }

                heatMapSection
                movementSection
                movementTable
                reportSection
            }
            .padding(20)
        }
        .sheet(isPresented: $viewModel.showingMoveSheet) {
            MoveStockSheet()
                .environmentObject(api)
        }
    }

    private var heatMapSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Тепловая карта склада")
                .font(.headline)

            Text("Цвет показывает срочность по сроку годности партий.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Зона", selection: $viewModel.selectedZone) {
                ForEach(viewModel.zones, id: \.self) { zone in
                    Text(zone).tag(zone)
                }
            }
            .frame(maxWidth: 260)

            if viewModel.filteredLocations.isEmpty {
                ContentUnavailableView(
                    "Нет ячеек",
                    systemImage: "square.grid.3x3",
                    description: Text("Добавьте ячейки хранения и обновите данные.")
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 145), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(viewModel.filteredLocations) { location in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(location.code)
                                .font(.headline)

                            Text(location.zone)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            let items = viewModel.items(in: location.id)

                            if items.isEmpty {
                                Text("Пусто")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.batchNumber)
                                            .font(.caption.bold())
                                            .lineLimit(1)

                                        Text("\(item.quantity) шт.")
                                            .font(.caption)

                                        Text(expiryDescription(item))
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(
                                        expiryColor(item).opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: 7)
                                    )
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(expiryColor(item))
                                            .frame(width: 4)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            HStack(spacing: 16) {
                legendItem(color: .red, title: "Просрочено")
                legendItem(color: .orange, title: "До 7 дней")
                legendItem(color: .green, title: "Более 7 дней")
                legendItem(color: .gray, title: "Нет данных")
            }
            .font(.caption)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var movementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Динамика перемещений")
                .font(.headline)

            Text("Количество перемещённых единиц по дням.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.movementDays.isEmpty {
                ContentUnavailableView(
                    "Нет перемещений",
                    systemImage: "chart.bar",
                    description: Text("После выполнения перемещений график появится здесь.")
                )
                .frame(height: 180)
            } else {
                Chart(viewModel.movementDays) { day in
                    BarMark(
                        x: .value("Дата", day.date, unit: .day),
                        y: .value("Количество", day.quantity)
                    )
                    .foregroundStyle(.blue.gradient)
                    .position(by: .value("Показатель", "Количество"))
                }
                .frame(height: 230)
                .chartYAxisLabel("Единиц")
                .chartXAxisLabel("Дата")
            }

            HStack(spacing: 16) {
                summaryCard(
                    title: "Операций",
                    value: "\(viewModel.movementOperationsCount)",
                    symbol: "arrow.left.arrow.right"
                )

                summaryCard(
                    title: "Перемещено",
                    value: "\(viewModel.totalMovementQuantity) шт.",
                    symbol: "shippingbox"
                )
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var movementTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("История перемещений")
                .font(.headline)

            if api.movements.isEmpty {
                Text("Записи о перемещениях отсутствуют.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.recentMovements) { movement in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(movement.quantity) шт.")
                                .font(.headline)

                            Spacer()

                            Text(movement.operationType)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Text("Партия: \(movement.batchID.uuidString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        Text("Пользователь: \(movement.userEmail ?? "Не указан")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        Text(
                            "\(viewModel.locationName(movement.fromLocationID)) → "
                                + "\(viewModel.locationName(movement.toLocationID))"
                        )
                        .font(.subheadline)

                        Text(
                            movement.createdAt.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Отчёт по остаткам")
                .font(.headline)

            Picker("Категория", selection: $viewModel.reportFilter) {
                Text("Все позиции").tag("Все позиции")
                Text("Просроченные").tag("Просроченные")
                Text("Скоро истекают").tag("Скоро истекают")
                Text("Без просрочки").tag("Без просрочки")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 260)

            HStack {
                Label(
                    "Позиций: \(viewModel.filteredFEFOItems.count)",
                    systemImage: "shippingbox"
                )

                Spacer()

                Text(
                    "Количество: \(viewModel.filteredFEFOItems.reduce(0) { $0 + $1.quantity })"
                )
            }
            .font(.subheadline)

            if viewModel.filteredFEFOItems.isEmpty {
                Text("Нет позиций, соответствующих фильтру.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.filteredFEFOItems) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(expiryColor(item))
                            .frame(width: 9, height: 9)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(item.productName) — \(item.batchNumber)")
                                .font(.subheadline.bold())

                            Text("SKU: \(item.sku)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Ячейка: \(viewModel.locationName(item.storageLocationID))")
                                .font(.caption)

                            Text("Количество: \(item.quantity) шт.")
                                .font(.caption)

                            Text(
                                "Годен до: \(item.expiresAt.formatted(date: .numeric, time: .omitted))"
                            )
                            .font(.caption)

                            Text(expiryDescription(item))
                                .font(.caption)
                                .foregroundStyle(expiryColor(item))
                        }

                        Spacer()
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Button {
                exportCSV()
            } label: {
                Label("Экспортировать CSV", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)

            if let exportMessage = viewModel.exportMessage {
                Text(exportMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func expiryColor(_ item: FEFOItem) -> Color {
        if item.isExpired {
            return .red
        }

        if item.daysUntilExpiration >= 0
            && item.daysUntilExpiration <= 7 {
            return .orange
        }

        return .green
    }

    private func expiryDescription(_ item: FEFOItem) -> String {
        if item.isExpired {
            return "Срок годности истёк"
        }

        if item.daysUntilExpiration == 0 {
            return "Истекает сегодня"
        }

        return "Осталось дней: \(item.daysUntilExpiration)"
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
        }
    }

    private func summaryCard(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title2.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.title = "Экспорт отчёта по остаткам"
        panel.nameFieldStringValue = "warehouse_report.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let header = [
            "Product",
            "SKU",
            "Batch",
            "Location",
            "Quantity",
            "ExpiresAt",
            "DaysUntilExpiration",
            "Expired"
        ]

        var rows = [header.map(csvField).joined(separator: ",")]

        for item in viewModel.filteredFEFOItems {
            let values = [
                item.productName,
                item.sku,
                item.batchNumber,
                viewModel.locationName(item.storageLocationID),
                String(item.quantity),
                ISO8601DateFormatter().string(from: item.expiresAt),
                String(item.daysUntilExpiration),
                item.isExpired ? "Да" : "Нет"
            ]

            rows.append(values.map(csvField).joined(separator: ","))
        }

        let csv = "\u{FEFF}" + rows.joined(separator: "\n")

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            viewModel.exportSucceeded(fileName: url.lastPathComponent)
        } catch {
            viewModel.exportFailed(error: error)
        }
    }
}
