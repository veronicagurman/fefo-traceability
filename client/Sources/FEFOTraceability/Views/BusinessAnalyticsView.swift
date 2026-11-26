import SwiftUI
import Charts

struct BusinessAnalyticsView: View {
    @EnvironmentObject private var api: APIService
    @StateObject private var viewModel: BusinessAnalyticsViewModel

    private let bucketColors: [Color] = [.red, .orange, .yellow, .teal, .green]

    init(repository: any FEFORepository) {
        _viewModel = StateObject(
            wrappedValue: BusinessAnalyticsViewModel(repository: repository)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let data = viewModel.data {
                    insightsSection(data.insights)
                    kpiGrid(data.kpi)

                    HStack(alignment: .top, spacing: 16) {
                        expiryBucketsCard(data)
                        shelfLifeCard(data)
                    }

                    timelineCard(data)
                    zonesCard(data)
                    abcCard(data)
                    paretoCard
                    risksCard(data)
                    movementsCard(data)

                    HStack(alignment: .top, spacing: 16) {
                        topUsersCard(data)
                        topRoutesCard(data)
                    }
                } else {
                    ContentUnavailableView(
                        "Нет данных бизнес-аналитики",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Не удалось загрузить данные. Попробуйте обновить информацию.")
                    )
                }
            }
            .padding(20)
        }
    }

    // MARK: - Заголовок и показатели

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Бизнес-аналитика")
                    .font(.title2.bold())

                if let data = viewModel.data {
                    Text("Актуальность данных: \(data.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Обновить", systemImage: "arrow.clockwise")
            }
            .disabled(api.isLoading)
        }
    }

    private func insightsSection(_ items: [BizInsight]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Рекомендации системы")
                .font(.headline)

            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insightIcon(item.level))
                        .foregroundStyle(insightColor(item.level))

                    Text(item.text)
                        .font(.subheadline)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    insightColor(item.level).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
        }
    }

    private func kpiGrid(_ kpi: BizKPI) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 200), spacing: 12)],
            spacing: 12
        ) {
            kpiCard(
                "Размещено, шт.",
                value: kpi.totalQuantity.formatted(),
                hint: "Позиций: \(kpi.totalPositions)",
                icon: "shippingbox.fill",
                tint: .blue
            )
            kpiCard(
                "Доля просроченного",
                value: percentText(kpi.expiredSharePercent),
                hint: "\(kpi.expiredQuantity) шт.",
                icon: "exclamationmark.triangle.fill",
                tint: .red
            )
            kpiCard(
                "Риск до 7 дней",
                value: percentText(kpi.atRiskSharePercent),
                hint: "\(kpi.atRiskQuantity) шт.",
                icon: "clock.fill",
                tint: .orange
            )
            kpiCard(
                "Остаток срока годности",
                value: percentText(kpi.avgShelfLifeLeftPercent),
                hint: "В среднем по остатку",
                icon: "hourglass",
                tint: .green
            )
            kpiCard(
                "Не размещено, шт.",
                value: kpi.unplacedQuantity.formatted(),
                hint: "Принято, но без ячейки",
                icon: "tray.and.arrow.down.fill",
                tint: .purple
            )
            kpiCard(
                "Заполненность ячеек",
                value: percentText(kpi.occupancyPercent),
                hint: "\(kpi.occupiedLocations) из \(kpi.totalLocations)",
                icon: "square.grid.3x3.fill",
                tint: .teal
            )
            kpiCard(
                "Перемещений за 30 дней",
                value: kpi.movementsLast30Days.formatted(),
                hint: "Операций",
                icon: "arrow.left.arrow.right",
                tint: .indigo
            )
            kpiCard(
                "Перемещено за 30 дней",
                value: kpi.movedQuantityLast30Days.formatted(),
                hint: "Единиц",
                icon: "shippingbox",
                tint: .indigo
            )
        }
    }

    // MARK: - Диаграммы

    private func expiryBucketsCard(_ data: BusinessAnalyticsResponse) -> some View {
        card(
            "Структура остатков по срокам",
            subtitle: "Количество единиц по оставшемуся сроку годности"
        ) {
            Chart(data.expiryBuckets) { bucket in
                BarMark(
                    x: .value("Категория", bucket.label),
                    y: .value("Количество", bucket.quantity)
                )
                .foregroundStyle(bucketColor(bucket.order))
                .annotation(position: .top) {
                    Text("\(bucket.quantity)")
                        .font(.caption2)
                }
            }
            .chartXScale(domain: data.expiryBuckets.map(\.label))
            .chartYAxisLabel("шт.")
            .frame(height: 230)
        }
    }

    private func shelfLifeCard(_ data: BusinessAnalyticsResponse) -> some View {
        let slices = data.shelfLifeBuckets.filter { $0.quantity > 0 }

        return card(
            "Доля оставшегося срока",
            subtitle: "Какая часть срока годности ещё не израсходована"
        ) {
            if slices.isEmpty {
                emptyChart
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Количество", slice.quantity),
                        innerRadius: .ratio(0.58)
                    )
                    .foregroundStyle(by: .value("Остаток срока", slice.label))
                }
                .chartForegroundStyleScale(
                    domain: slices.map(\.label),
                    range: slices.map { bucketColor($0.order) }
                )
                .chartLegend(position: .bottom)
                .frame(height: 230)
            }
        }
    }

    private func timelineCard(_ data: BusinessAnalyticsResponse) -> some View {
        card(
            "Прогноз истечения сроков",
            subtitle: "Сколько единиц истекает в ближайшие 8 недель (дни от сегодняшнего)"
        ) {
            Chart(data.expiryTimeline) { week in
                BarMark(
                    x: .value("Период", weekLabel(week)),
                    y: .value("Количество", week.quantity)
                )
                .foregroundStyle(week.fromDay == 0 ? Color.orange : Color.blue)
                .annotation(position: .top) {
                    Text("\(week.quantity)")
                        .font(.caption2)
                }
            }
            .chartXScale(domain: data.expiryTimeline.map { weekLabel($0) })
            .chartYAxisLabel("шт.")
            .frame(height: 230)
        }
    }

    private func zonesCard(_ data: BusinessAnalyticsResponse) -> some View {
        card(
            "Зоны склада",
            subtitle: "Остатки по зонам и заполненность ячеек"
        ) {
            if data.zones.isEmpty {
                emptyChart
            } else {
                Chart(viewModel.zoneSegments) { segment in
                    BarMark(
                        x: .value("Количество", segment.quantity),
                        y: .value("Зона", segment.zone)
                    )
                    .foregroundStyle(by: .value("Состояние", segment.category))
                }
                .chartForegroundStyleScale([
                    "Просрочено": Color.red,
                    "До 7 дней": Color.orange,
                    "В норме": Color.green
                ])
                .chartLegend(position: .bottom)
                .frame(height: max(160, CGFloat(data.zones.count) * 46 + 50))

                VStack(spacing: 10) {
                    ForEach(data.zones) { zone in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(zone.zone)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("занято \(zone.occupiedLocations) из \(zone.locations) ячеек")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(
                                value: Double(zone.occupiedLocations),
                                total: Double(max(zone.locations, 1))
                            )
                        }
                    }
                }
            }
        }
    }

    private func abcCard(_ data: BusinessAnalyticsResponse) -> some View {
        card(
            "ABC-анализ остатков",
            subtitle: "A: до 80% накопленного остатка, B: до 95%, C: остальные (топ-12 товаров)"
        ) {
            if viewModel.topABC.isEmpty {
                emptyChart
            } else {
                HStack(spacing: 12) {
                    ForEach(data.abcSummary) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Класс \(item.abcClass)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(item.products) тов.")
                                .font(.title3.bold())
                            Text("\(percentText(item.sharePercent)) остатка")
                                .font(.caption)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            abcColor(item.abcClass).opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }

                Chart(viewModel.topABC) { item in
                    BarMark(
                        x: .value("Количество", item.quantity),
                        y: .value("Товар", item.productName)
                    )
                    .foregroundStyle(by: .value("Класс", item.abcClass))
                    .annotation(position: .trailing) {
                        Text("\(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartForegroundStyleScale([
                    "A": Color.blue,
                    "B": Color.orange,
                    "C": Color.gray
                ])
                .chartYScale(domain: viewModel.topABC.map(\.productName))
                .chartLegend(position: .bottom)
                .frame(height: CGFloat(viewModel.topABC.count) * 34 + 60)
            }
        }
    }

    private var paretoCard: some View {
        card(
            "Кривая Парето",
            subtitle: "Накопленная доля остатка по товарам, линии на уровнях 80% и 95%"
        ) {
            if viewModel.paretoPoints.isEmpty {
                emptyChart
            } else {
                Chart {
                    ForEach(viewModel.paretoPoints) { point in
                        LineMark(
                            x: .value("Товар №", point.rank),
                            y: .value("Накопленная доля, %", point.cumulative)
                        )
                        .foregroundStyle(.blue)

                        PointMark(
                            x: .value("Товар №", point.rank),
                            y: .value("Накопленная доля, %", point.cumulative)
                        )
                        .foregroundStyle(.blue)
                    }

                    RuleMark(y: .value("Граница A", 80))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.orange)

                    RuleMark(y: .value("Граница B", 95))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.gray)
                }
                .chartYScale(domain: 0...100)
                .chartXAxisLabel("Товары по убыванию остатка")
                .chartYAxisLabel("Накопленная доля, %")
                .frame(height: 240)
            }
        }
    }

    private func risksCard(_ data: BusinessAnalyticsResponse) -> some View {
        card(
            "Товары с риском",
            subtitle: "Просроченные и истекающие в течение 7 дней, по убыванию объёма"
        ) {
            if data.productRisks.isEmpty {
                Text("Товаров с риском не выявлено.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(data.productRisks) { risk in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(risk.productName)
                                    .font(.subheadline.bold())
                                Text("SKU: \(risk.sku) · партий: \(risk.batches) · всего \(risk.quantity) шт.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                if risk.expiredQuantity > 0 {
                                    Text("Просрочено: \(risk.expiredQuantity) шт.")
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                }
                                if risk.atRiskQuantity > 0 {
                                    Text("До 7 дней: \(risk.atRiskQuantity) шт.")
                                        .font(.caption.bold())
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func movementsCard(_ data: BusinessAnalyticsResponse) -> some View {
        card(
            "Динамика перемещений",
            subtitle: "Последние 30 дней"
        ) {
            Picker("Показатель", selection: $viewModel.movementMetric) {
                ForEach(MovementMetric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            Chart(data.movementsByDay) { day in
                BarMark(
                    x: .value("Дата", day.date, unit: .day),
                    y: .value(
                        viewModel.movementMetric.rawValue,
                        viewModel.movementMetric == .operations ? day.operations : day.quantity
                    )
                )
                .foregroundStyle(.blue.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 230)
        }
    }

    private func topUsersCard(_ data: BusinessAnalyticsResponse) -> some View {
        card(
            "Активность пользователей",
            subtitle: "Операции перемещения за 30 дней"
        ) {
            if data.topUsers.isEmpty {
                emptyChart
            } else {
                Chart(data.topUsers) { item in
                    BarMark(
                        x: .value("Операций", item.operations),
                        y: .value("Пользователь", item.user)
                    )
                    .foregroundStyle(.indigo.gradient)
                    .annotation(position: .trailing) {
                        Text("\(item.operations)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: data.topUsers.map(\.user))
                .frame(height: CGFloat(data.topUsers.count) * 34 + 40)
            }
        }
    }

    private func topRoutesCard(_ data: BusinessAnalyticsResponse) -> some View {
        card(
            "Частые маршруты",
            subtitle: "Из какой ячейки в какую перемещают чаще всего"
        ) {
            if data.topRoutes.isEmpty {
                emptyChart
            } else {
                Chart(data.topRoutes) { item in
                    BarMark(
                        x: .value("Операций", item.operations),
                        y: .value("Маршрут", item.route)
                    )
                    .foregroundStyle(.teal.gradient)
                    .annotation(position: .trailing) {
                        Text("\(item.operations)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: data.topRoutes.map(\.route))
                .frame(height: CGFloat(data.topRoutes.count) * 34 + 40)
            }
        }
    }

    // MARK: - Вспомогательное

    private var emptyChart: some View {
        ContentUnavailableView(
            "Нет данных для графика",
            systemImage: "chart.bar.xaxis",
            description: Text("Появится после добавления данных.")
        )
        .frame(height: 180)
    }

    private func card<Content: View>(
        _ title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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

    private func kpiCard(
        _ title: String,
        value: String,
        hint: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title2.bold())

                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func percentText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1))) + "%"
    }

    private func weekLabel(_ week: BizWeek) -> String {
        "\(week.fromDay)-\(week.toDay) дн."
    }

    private func bucketColor(_ order: Int) -> Color {
        bucketColors[min(max(order, 0), bucketColors.count - 1)]
    }

    private func abcColor(_ letter: String) -> Color {
        switch letter {
        case "A": return .blue
        case "B": return .orange
        default: return .gray
        }
    }

    private func insightIcon(_ level: String) -> String {
        switch level {
        case "critical": return "exclamationmark.octagon.fill"
        case "warning": return "exclamationmark.triangle.fill"
        default: return "info.circle.fill"
        }
    }

    private func insightColor(_ level: String) -> Color {
        switch level {
        case "critical": return .red
        case "warning": return .orange
        default: return .blue
        }
    }
}
