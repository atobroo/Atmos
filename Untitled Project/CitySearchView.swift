//
//  CitySearchView.swift
//  Atmos
//

import SwiftUI
import CoreLocation

struct CitySearchView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (SavedCity) -> Void

    @State private var query = ""
    @State private var results: [AtmosGeocoder.Result] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    @StateObject private var location = LocationManager()
    @State private var pendingLocationPick = false

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosBackground(glow: AtmosPalette.cyan, showStars: true)

                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        searchField
                        useLocationButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    if location.authorizationStatus == .denied ||
                       location.authorizationStatus == .restricted {
                        locationDeniedBanner
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }

                    content
                }
            }
            .navigationTitle("Add city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AtmosPalette.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { searchTask?.cancel() }
        .onChange(of: location.resolvedCity) { newValue in
            guard pendingLocationPick, let city = newValue else { return }
            pendingLocationPick = false
            onPick(city)
            dismiss()
        }
        .onChange(of: location.errorMessage) { newValue in
            if pendingLocationPick, !newValue.isEmpty {
                pendingLocationPick = false
            }
        }
    }

    // MARK: Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AtmosPalette.secondaryText)

            TextField("Search city", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .submitLabel(.search)
                .onSubmit { scheduleSearch() }

            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AtmosPalette.tertiaryText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onChange(of: query) { _ in scheduleSearch() }
    }

    // MARK: Use my location

    private var useLocationButton: some View {
        Button {
            pendingLocationPick = true
            location.requestLocation()
        } label: {
            HStack(spacing: 10) {
                if location.isLoading {
                    ProgressView()
                        .tint(AtmosPalette.cyan)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AtmosPalette.cyan)
                }

                Text(location.isLoading ? "Locating…" : "Use my location")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if !location.isLoading {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AtmosPalette.tertiaryText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AtmosPalette.cyan.opacity(0.18),
                                AtmosPalette.violet.opacity(0.12)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AtmosPalette.cyan.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(location.isLoading)
    }

    // MARK: Denied banner

    private var locationDeniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(AtmosPalette.amber)
            Text("Location access is off.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AtmosPalette.secondaryText)
            Spacer()
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AtmosPalette.cyan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if isSearching && results.isEmpty {
            Spacer()
            ProgressView().tint(AtmosPalette.cyan)
            Spacer()
        } else if let errorMessage {
            Spacer()
            Text(errorMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AtmosPalette.amber)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        } else if results.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(AtmosPalette.cyan.opacity(0.7))
                Text(query.isEmpty ? "Type a city name" : "Nothing found")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AtmosPalette.secondaryText)
            }
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(results) { result in
                        Button {
                            onPick(result.saved)
                            dismiss()
                        } label: {
                            CityRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: Search scheduling

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ text: String) async {
        isSearching = true
        errorMessage = nil
        do {
            let found = try await AtmosGeocoder.search(text)
            if Task.isCancelled { return }
            results = found
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            errorMessage = "Couldn't search right now. Try again."
            results = []
        }
        isSearching = false
    }
}

private struct CityRow: View {
    let result: AtmosGeocoder.Result

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AtmosPalette.secondaryText)
                }
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AtmosPalette.cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}
