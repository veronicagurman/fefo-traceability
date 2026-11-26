
import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject private var api: APIService

    @StateObject private var viewModel: ContentViewModel
    private let repository: any FEFORepository

    init(api: APIService, repository: any FEFORepository) {
        self.repository = repository
        _viewModel = StateObject(
            wrappedValue: ContentViewModel(repository: repository)
        )
    }

    var body: some View {
        Group {
            if api.token == nil {
                loginView
            } else {
                mainView
            }
        }
        .frame(minWidth: 900, minHeight: 680)
        .onChange(of: api.userRole) { _, _ in
            viewModel.selectedTab = 0
        }
    }

    private var loginView: some View {
        VStack(spacing: 18) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 52))
                .foregroundStyle(.blue)

            Text("FEFO Traceability")
                .font(.largeTitle.bold())

            Text("Аналитика складских запасов и сроков годности")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                TextField("Электронная почта", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)

                SecureField("Пароль", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)

                Text("Длина пароля: \(viewModel.password.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await viewModel.login()
                    }
                } label: {
                    HStack {
                        if api.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Войти")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(api.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
            }
            .frame(maxWidth: 340)

            if let error = api.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .padding(32)
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            HStack {
                Label("FEFO Traceability", systemImage: "shippingbox.fill")
                    .font(.title2.bold())

                Spacer()

                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                .disabled(api.isLoading)
            }
            .padding()

            Picker("Раздел", selection: $viewModel.selectedTab) {
                Text("Аналитическая панель").tag(0)
                Text("Приоритет FEFO").tag(1)

                if api.userRole != "sales_manager" {
                    Text("Склад и отчёты").tag(2)
                }

                Text("Бизнес-аналитика").tag(3)

                if api.userRole != "sales_manager" {
                    Text("Отгрузка").tag(4)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 12)

            if let error = api.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal)
            }

            if api.isLoading && api.analytics == nil {
                Spacer()
                ProgressView("Загрузка...")
                Spacer()
            } else {
                Group {
                    if viewModel.selectedTab == 0 {
                        dashboard
                    } else if viewModel.selectedTab == 1 {
                        fefoList
                    } else if viewModel.selectedTab == 2 {
                        AnalyticsExtrasView(api: api, repository: repository)
                    } else if viewModel.selectedTab == 3 {
                        BusinessAnalyticsView(repository: repository)
                    } else {
                        ShipmentView()
                    }
                }
            }
        }
    }

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                sectionTitle(
                    "Панель показателей",
                    subtitle: "Текущее состояние складских запасов"
                )

                if let data = api.analytics {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        metric("Товары", value: data.totalProducts, icon: "cube.box")
                        metric("Партии", value: data.totalBatches, icon: "shippingbox")
                        metric("Остаток, шт.", value: data.totalQuantity, icon: "shippingbox.fill")
                        metric("Места хранения", value: data.activeLocations, icon: "archivebox")
                        metric("Просроченные позиции", value: data.expiredPositions, icon: "exclamationmark.triangle")
                        metric("Скоро истекает", value: data.expiringWithinSevenDays, icon: "clock")
                        metric("Движения", value: data.recentMovements, icon: "arrow.left.arrow.right")
                    }
                } else {
                    ContentUnavailableView(
                        "Нет данных аналитики",
                        systemImage: "chart.bar",
                        description: Text("Не удалось загрузить данные. Проверьте подключение и попробуйте снова.")
                    )
                }

                if let response = api.fefo {
                    expiryChart(response)
                    stockByProductChart(response)
                    expiryDateChart(response)
                    sectionTitle(
                        "Позиции с ближайшими сроками",
                        subtitle: "Первые пять строк в порядке FEFO"
                    )

                    ForEach(Array(response.items.prefix(5))) { item in
                        fefoRow(item)
                    }
                }
            }
            .padding(20)
        }
    }

    private func expiryChart(_ response: FEFOResponse) -> some View {
        let expired = response.items.filter { $0.isExpired }.count
        let expiring = response.items.filter {
            !$0.isExpired
                && $0.daysUntilExpiration >= 0
                && $0.daysUntilExpiration <= 7
        }.count
        let normal = response.items.filter {
            !$0.isExpired && $0.daysUntilExpiration > 7
        }.count

        let data = [
            ExpirySlice(name: "Просроченные", count: expired),
            ExpirySlice(name: "Истекают за 7 дней", count: expiring),
            ExpirySlice(name: "Более 7 дней", count: normal)
        ].filter { $0.count > 0 }

        return chartCard(
            title: "Состояние сроков годности",
            subtitle: "Количество складских позиций по категориям"
        ) {
            if data.isEmpty {
                emptyChart
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Позиций", item.count),
                        innerRadius: .ratio(0.58),
                    )
                    .foregroundStyle(by: .value("Категория", item.name))
                    .annotation(position: .overlay) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.caption.bold())
                        }
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 230)
            }
        }
    }

    private func stockByProductChart(_ response: FEFOResponse) -> some View {
        let grouped = Dictionary(grouping: response.items, by: \.productName)

        let data = grouped.map { name, items in
            ProductStock(
                name: name,
                quantity: items.reduce(0) { $0 + $1.quantity }
            )
        }
        .sorted { $0.quantity > $1.quantity }
        .prefix(8)

        return chartCard(
            title: "Остатки по товарам",
            subtitle: "Количество размещённого товара, топ-8"
        ) {
            if data.isEmpty {
                emptyChart
            } else {
                Chart(Array(data)) { item in
                    BarMark(
                        x: .value("Количество", item.quantity),
                        y: .value("Товар", item.name)
                    )
                    .foregroundStyle(.blue.gradient)
                    .annotation(position: .trailing) {
                        Text("\(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxisLabel("Количество, шт.")
                .frame(height: max(180, CGFloat(data.count) * 38))
            }
        }
    }

    private func expiryDateChart(_ response: FEFOResponse) -> some View {
        let grouped = Dictionary(
            grouping: response.items,
            by: { Calendar.current.startOfDay(for: $0.expiresAt) }
        )

        let data = grouped.map { date, items in
            ExpiryDateStock(
                date: date,
                quantity: items.reduce(0) { $0 + $1.quantity }
            )
        }
        .sorted { $0.date < $1.date }

        return chartCard(
            title: "Остатки по датам истечения",
            subtitle: "Объём товара для каждой даты срока годности"
        ) {
            if data.isEmpty {
                emptyChart
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Дата", item.date, unit: .day),
                        y: .value("Остаток", item.quantity)
                    )
                    .foregroundStyle(.orange.gradient)
                    .annotation(position: .top) {
                        Text("\(item.quantity)")
                            .font(.caption2)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartYAxisLabel("Количество, шт.")
                .frame(height: 240)
            }
        }
    }

    private var fefoList: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                "Приоритет отгрузки",
                subtitle: "Сначала партии с ближайшим сроком годности"
            )

            Picker("Фильтр", selection: $viewModel.expiryFilter) {
                ForEach(viewModel.expiryFilters, id: \.self) { filter in
                    Text(filter).tag(filter)
                }
            }
            .pickerStyle(.menu)

            if let response = api.fefo {
                let items = viewModel.filteredItems(response.items)

                if items.isEmpty {
                    ContentUnavailableView(
                        "Нет подходящих позиций",
                        systemImage: "checkmark.circle",
                        description: Text("Для выбранного фильтра позиции не найдены.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(items) { item in
                                fefoRow(item)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Нет данных FEFO",
                    systemImage: "shippingbox",
                    description: Text("Обновите данные.")
                )
            }
        }
        .padding(20)
    }

    private var emptyChart: some View {
        ContentUnavailableView(
            "Нет данных для графика",
            systemImage: "chart.bar.xaxis",
            description: Text("В выбранной категории пока нет позиций.")
        )
        .frame(height: 180)
    }

    private func chartCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func metric(_ title: String, value: Int, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value.formatted())
                    .font(.title2.bold())
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fefoRow(_ item: FEFOItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(
                systemName: item.isExpired
                    ? "exclamationmark.triangle.fill"
                    : "shippingbox.fill"
            )
            .font(.title2)
            .foregroundStyle(item.isExpired ? .red : .blue)
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.productName)
                    .font(.headline)

                Text("Партия: \(item.batchNumber) · SKU: \(item.sku)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Место: \(item.storageLocationID.uuidString)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(
                    "Годен до: \(item.expiresAt.formatted(date: .abbreviated, time: .omitted))"
                )
                .font(.subheadline)

                Text(statusText(for: item))
                    .font(.caption.bold())
                    .foregroundStyle(statusColor(for: item))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.quantity) шт.")
                    .font(.headline)

                Text("Остаток")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusText(for item: FEFOItem) -> String {
        if item.isExpired {
            return "Просрочено"
        }
        if item.daysUntilExpiration == 0 {
            return "Истекает сегодня"
        }
        if item.daysUntilExpiration <= 7 {
            return "Скоро истекает · \(item.daysUntilExpiration) дн."
        }
        return "До истечения: \(item.daysUntilExpiration) дн."
    }

    private func statusColor(for item: FEFOItem) -> Color {
        if item.isExpired {
            return .red
        }
        if item.daysUntilExpiration <= 7 {
            return .orange
        }
        return .green
    }
}

private struct ExpirySlice: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

private struct ProductStock: Identifiable {
    let name: String
    let quantity: Int
    var id: String { name }
}

private struct ExpiryDateStock: Identifiable {
    let date: Date
    let quantity: Int
    var id: Date { date }
}
