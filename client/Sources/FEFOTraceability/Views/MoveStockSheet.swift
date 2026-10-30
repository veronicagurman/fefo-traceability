
import SwiftUI

struct MoveStockSheet: View {
    @EnvironmentObject private var api: APIService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedBatchKey = ""
    @State private var selectedSourceID = ""
    @State private var selectedDestinationID = ""
    @State private var quantityText = "1"
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var successText: String?
   

    private var stockItems: [FEFOItem] {
        api.fefo?.items.filter { $0.quantity > 0 } ?? []
    }

    private var batchOptions: [FEFOItem] {
        var seen = Set<UUID>()
        return stockItems
            .filter { seen.insert($0.batchID).inserted }
            .sorted { $0.batchNumber < $1.batchNumber }
    }

    private var selectedBatch: FEFOItem? {
        batchOptions.first { batchKey($0) == selectedBatchKey }
    }

    private func batchKey(_ item: FEFOItem) -> String {
        item.batchID.uuidString
    }

    private var sourceOptions: [FEFOItem] {
        guard let selectedBatch else { return [] }
        return stockItems.filter { $0.batchID == selectedBatch.batchID }
    }

    private var selectedSource: FEFOItem? {
        sourceOptions.first {
            $0.storageLocationID.uuidString == selectedSourceID
        }
    }

    
    private var destinationOptions: [LocationItem] {
        return api.locations
            .filter { $0.id.uuidString != selectedSourceID }
            .sorted {
                $0.code.localizedStandardCompare($1.code) == .orderedAscending
            }
    }

    private var quantity: Int? {
        Int(quantityText)
    }

    private var canSubmit: Bool {
        selectedBatch != nil
            && selectedSource != nil
            && !selectedDestinationID.isEmpty
            && quantity != nil
            && quantity! > 0
            && quantity! <= (selectedSource?.quantity ?? 0)
            && !isSaving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Перемещение товара")
                .font(.title2.bold())

            Text("Выберите партию и укажите, сколько единиц переместить в другую ячейку.")
                .foregroundStyle(.secondary)

            Form {
                Section("Партия") {
                    Picker("Партия", selection: $selectedBatchKey) {
                        Text("Выберите партию").tag("")
                        ForEach(batchOptions) { item in
                            Text("\(item.batchNumber) — \(item.productName)")
                                .tag(batchKey(item))
                        }
                    }
                    .onChange(of: selectedBatchKey) { _, _ in
                        selectedSourceID = ""
                        selectedDestinationID = ""
                    }
                }

                Section("Откуда") {
                    Picker("Ячейка-источник", selection: $selectedSourceID) {
                        Text("Выберите ячейку").tag("")
                        ForEach(sourceOptions) { item in
                            Text("\(locationName(item.storageLocationID)) — \(item.quantity) шт.")
                                .tag(item.storageLocationID.uuidString)
                        }
                    }
                    .onChange(of: selectedSourceID) { _, _ in
                        selectedDestinationID = ""
                    }

                    if let selectedSource {
                        LabeledContent(
                            "Доступный остаток",
                            value: "\(selectedSource.quantity) шт."
                        )
                    }
                }

                Section("Куда") {
                    Picker("Ячейка назначения", selection: $selectedDestinationID) {
                        Text("Выберите ячейку").tag("")
                        ForEach(destinationOptions) { location in
                            Text("\(location.code) — \(location.zone)")
                                .tag(location.id.uuidString)
                        }
                    }
                }

                Section("Количество") {
                    TextField("Количество, шт.", text: $quantityText)
                        .onChange(of: quantityText) { _, value in
                            quantityText = String(value.filter(\.isNumber).prefix(8))
                        }

                    if let selectedSource, let quantity,
                       quantity > selectedSource.quantity {
                        Text("Недостаточно товара в выбранной ячейке.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            if let successText {
                Text(successText)
                    .foregroundStyle(.green)
                    .font(.callout)
            }

            HStack {
                Button("Отмена") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task { await submitMovement() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Подтвердить перемещение", systemImage: "arrow.left.arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
        }
        .padding(20)
        .frame(minWidth: 540, minHeight: 570)
        .onAppear {
            if selectedBatchKey.isEmpty, let first = batchOptions.first {
                selectedBatchKey = batchKey(first)
            }
        }
    }

    private func locationName(_ id: UUID) -> String {
        api.locations.first { $0.id == id }?.code ?? id.uuidString
    }

    @MainActor
    private func submitMovement() async {
        guard let selectedBatch,
              let selectedSource,
              let quantity,
              let destinationID = UUID(uuidString: selectedDestinationID) else {
            errorText = "Заполните все поля."
            return
        }

        guard quantity > 0, quantity <= selectedSource.quantity else {
            errorText = "Проверьте количество товара."
            return
        }

        isSaving = true
        errorText = nil
        successText = nil
        defer { isSaving = false }

        do {
            try await api.moveStock(
                batchID: selectedBatch.batchID,
                fromLocationID: selectedSource.storageLocationID,
                toLocationID: destinationID,
                quantity: quantity
            )

            successText = "Перемещение выполнено. Остатки обновлены."
            try? await Task.sleep(for: .milliseconds(700))
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
