import SwiftUI

struct ShipmentView: View {
    @EnvironmentObject private var api: APIService

    @State private var selectedProductID: UUID?
    @State private var quantityText = "1"
    @State private var isSubmitting = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    private var products: [ShipmentProductOption] {
        let items = api.fefo?.items ?? []
        let grouped = Dictionary(grouping: items, by: \.productID)

        return grouped.compactMap { productID, positions in
            guard let first = positions.first else { return nil }

            let available = positions
                .filter { !$0.isExpired }
                .reduce(0) { $0 + $1.quantity }

            return ShipmentProductOption(
                id: productID,
                name: first.productName,
                sku: first.sku,
                availableQuantity: available
            )
        }
        .sorted { $0.name < $1.name }
    }

    private var selectedProduct: ShipmentProductOption? {
        products.first { $0.id == selectedProductID }
    }

    private var availablePositions: [FEFOItem] {
        (api.fefo?.items ?? [])
            .filter {
                $0.productID == selectedProductID && !$0.isExpired
            }
            .sorted { $0.expiresAt < $1.expiresAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Отгрузка товаров")
                        .font(.title2.bold())

                    Text("Отгрузка выполняется автоматически с соблюдением принципа FEFO.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                GroupBox("Параметры отгрузки") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Товар", selection: $selectedProductID) {
                            Text("Выберите товар").tag(UUID?.none)

                            ForEach(products) { product in
                                Text("\(product.name) · \(product.sku)")
                                    .tag(Optional(product.id))
                            }
                        }
                        .disabled(products.isEmpty)

                        if let product = selectedProduct {
                            HStack {
                                Text("Доступно к отгрузке")
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text("\(product.availableQuantity) шт.")
                                    .fontWeight(.semibold)
                            }
                        }

                        HStack {
                            Text("Количество")

                            Spacer()

                            TextField("Количество", text: $quantityText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)
                        }

                        Button {
                            Task {
                                await submitShipment()
                            }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .controlSize(.small)
                                }

                                Label("Выполнить отгрузку", systemImage: "shippingbox")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            isSubmitting
                            || selectedProductID == nil
                            || (Int(quantityText) ?? 0) <= 0
                        )
                    }
                    .padding(.vertical, 5)
                }

                if let resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(.vertical, 4)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(.vertical, 4)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Доступные позиции FEFO")
                        .font(.headline)

                    Text("Доступные для отгрузки партии выбранного товара в порядке FEFO.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if selectedProductID == nil {
                        ContentUnavailableView(
                            "Выберите товар",
                            systemImage: "shippingbox",
                            description: Text("После выбора здесь появятся доступные партии.")
                        )
                    } else if availablePositions.isEmpty {
                        ContentUnavailableView(
                            "Нет доступных партий",
                            systemImage: "tray",
                            description: Text("Для выбранного товара нет размещённых непросроченных остатков.")
                        )
                    } else {
                        ForEach(availablePositions) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.batchNumber)
                                        .font(.headline)

                                    Spacer()

                                    Text("\(item.quantity) шт.")
                                        .fontWeight(.semibold)
                                }

                                Text("Годен до: \(item.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline)

                                Text("Ячейка: \(item.storageLocationID.uuidString)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(item.daysUntilExpiration == 0
                                     ? "Истекает сегодня"
                                     : "Осталось дней: \(item.daysUntilExpiration)")
                                    .font(.caption)
                                    .foregroundStyle(item.daysUntilExpiration <= 7 ? .orange : .secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(20)
        }
        .onChange(of: api.fefo?.items.count ?? 0) { _, _ in
            if selectedProductID == nil {
                selectedProductID = products.first?.id
            }
        }
        .onChange(of: selectedProductID) { _, _ in
            resultMessage = nil
            errorMessage = nil
        }
    }

    @MainActor
    private func submitShipment() async {
        guard let productID = selectedProductID,
              let quantity = Int(quantityText),
              quantity > 0 else {
            errorMessage = "Укажите товар и корректное количество."
            return
        }

        isSubmitting = true
        resultMessage = nil
        errorMessage = nil

        defer {
            isSubmitting = false
        }

        do {
            try await api.createShipment(
                productID: productID,
                quantity: quantity
            )

            resultMessage = "Отгрузка выполнена. Остатки обновлены."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShipmentProductOption: Identifiable {
    let id: UUID
    let name: String
    let sku: String
    let availableQuantity: Int
}
