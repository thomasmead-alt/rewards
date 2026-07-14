import SwiftUI
import RewardsKit

struct FunZoneView: View {
    @State private var section = 0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Section", selection: $section) {
                    Text("My Pet").tag(0)
                    Text("Stickers").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if section == 0 {
                    PetView()
                } else {
                    StickerAlbumView()
                }
            }
            .navigationTitle("Fun Zone")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { BalanceBadge() }
            }
        }
    }
}

// MARK: - Pet

struct PetView: View {
    @Environment(RewardsEngine.self) private var engine
    @State private var bounce = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let pet = engine.state.pet {
                    petHeader(pet)
                    inventorySection(pet)
                    shopSection(pet)
                } else {
                    ContentUnavailableView(
                        "No pet yet",
                        systemImage: "pawprint",
                        description: Text("Your pet arrives after onboarding.")
                    )
                }
            }
            .padding()
        }
    }

    private func petHeader(_ pet: Pet) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Text(pet.species.emoji)
                    .font(.system(size: 110))
                    .scaleEffect(bounce % 2 == 0 ? 1 : 1.08)
                    .animation(.bouncy, value: bounce)
                if let accessoryID = pet.equippedAccessory,
                   let accessory = PetCatalog.item(id: accessoryID) {
                    Text(accessory.emoji)
                        .font(.system(size: 40))
                        .offset(x: 10, y: -10)
                }
            }
            Text(pet.name)
                .font(.title.bold())
            Text("\(pet.name) is \(pet.moodDescription) \(pet.isSleepy ? "😴" : "😊")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(pet.happiness), total: 100) {
                EmptyView()
            }
            .tint(pet.isSleepy ? .orange : .green)
            .padding(.horizontal, 40)
            Text("Happiness: \(pet.happiness)/100")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
    }

    private func inventorySection(_ pet: Pet) -> some View {
        let owned = PetCatalog.items.filter { item in
            (pet.inventory[item.id] ?? 0) > 0 || pet.ownedAccessories.contains(item.id)
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text("My stuff")
                .font(.headline)
            if owned.isEmpty {
                Text("Buy \(pet.name) a snack or a toy below!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(owned) { item in
                HStack(spacing: 12) {
                    Text(item.emoji).font(.title)
                    VStack(alignment: .leading) {
                        Text(item.name).font(.body.weight(.medium))
                        if item.kind != .accessory {
                            Text("×\(pet.inventory[item.id] ?? 0)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if item.kind == .accessory {
                        let equipped = pet.equippedAccessory == item.id
                        Button(equipped ? "Take off" : "Wear") {
                            try? engine.equipAccessory(equipped ? nil : item.id)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(item.kind == .food ? "Feed" : "Play") {
                            if (try? engine.usePetItem(item.id)) != nil {
                                bounce += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func shopSection(_ pet: Pet) -> some View {
        let unit = engine.state.profile?.rewardUnit ?? .star
        return VStack(alignment: .leading, spacing: 10) {
            Text("Pet shop")
                .font(.headline)
            ForEach(PetCatalog.items) { item in
                let ownedAccessory = item.kind == .accessory && pet.ownedAccessories.contains(item.id)
                HStack(spacing: 12) {
                    Text(item.emoji).font(.title)
                    VStack(alignment: .leading) {
                        Text(item.name).font(.body.weight(.medium))
                        Text(item.kind == .accessory ? "Accessory" : "+\(item.boost) happiness")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if ownedAccessory {
                        Text("Owned ✓")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Button(unit.label(for: item.cost)) {
                            try? engine.buyPetItem(item.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(item.cost > engine.balance)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

// MARK: - Sticker album

struct StickerAlbumView: View {
    @Environment(RewardsEngine.self) private var engine
    @State private var confetti = 0

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(StickerCatalog.collections) { collection in
                    collectionSection(collection)
                }
            }
            .padding()
        }
        .overlay { ConfettiView(trigger: confetti) }
    }

    private func collectionSection(_ collection: StickerCollection) -> some View {
        let ownedCount = collection.stickers.filter { engine.ownsSticker($0.id) }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(collection.emoji) \(collection.title)")
                    .font(.headline)
                Spacer()
                Text("\(ownedCount)/\(collection.stickers.count)")
                    .font(.subheadline.bold())
                    .foregroundStyle(ownedCount == collection.stickers.count ? .green : .secondary)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(collection.stickers) { sticker in
                    StickerCell(sticker: sticker) {
                        if (try? engine.buySticker(sticker.id)) != nil {
                            confetti += 1
                        }
                    }
                }
            }
        }
    }
}

private struct StickerCell: View {
    @Environment(RewardsEngine.self) private var engine
    let sticker: Sticker
    let buy: () -> Void

    var body: some View {
        let owned = engine.ownsSticker(sticker.id)
        let unit = engine.state.profile?.rewardUnit ?? .star

        VStack(spacing: 6) {
            Text(sticker.emoji)
                .font(.system(size: 40))
                .grayscale(owned ? 0 : 1)
                .opacity(owned ? 1 : 0.35)
            if owned {
                Text(sticker.name)
                    .font(.caption2)
                    .lineLimit(1)
            } else {
                Button(unit.label(for: sticker.cost)) {
                    buy()
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(sticker.cost > engine.balance)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            (owned ? Color.yellow.opacity(0.15) : Color(.secondarySystemGroupedBackground)),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}

#Preview {
    FunZoneView()
        .environment(RewardsEngine(store: InMemoryStore()))
}
