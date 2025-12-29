//
//  AIBackendSettings.swift
//  OpenWebUI
//
//  Protocol for backend-specific settings
//

import Foundation
import SwiftUI

/// Protocol that all backend settings must implement
@MainActor
protocol AIBackendSettings: Codable {
    /// The backend this settings object belongs to
    var backendId: String { get }
    
    /// Create a SwiftUI view for configuring these settings
    func settingsView() -> AnyView
    
    /// Validate the current settings
    /// - Returns: Result indicating success or validation errors
    func validate() -> Result<Void, SettingsError>
    
    /// Reset settings to default values
    mutating func resetToDefaults()
}

/// Errors related to settings validation
enum SettingsError: LocalizedError {
    case missingRequiredField(String)
    case invalidValue(field: String, reason: String)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Required field missing: \(field)"
        case .invalidValue(let field, let reason):
            return "Invalid value for \(field): \(reason)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        }
    }
}

/// Settings persistence manager
@MainActor
class BackendSettingsManager: ObservableObject {
    static let shared = BackendSettingsManager()
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "backend_settings"
    
    @Published private(set) var settings: [String: Data] = [:]
    
    private init() {
        loadAllSettings()
    }
    
    /// Save settings for a specific backend
    func saveSettings<T: AIBackendSettings>(_ settings: T) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        self.settings[settings.backendId] = data
        userDefaults.set(data, forKey: settingsKey + "_" + settings.backendId)
    }
    
    /// Load settings for a specific backend
    func loadSettings<T: AIBackendSettings>(for backendId: String, type: T.Type) -> T? {
        guard let data = settings[backendId] else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }
    
    /// Load all saved settings from UserDefaults
    private func loadAllSettings() {
        // Load settings for all known backends
        // This will be populated as backends register themselves
    }
    
    /// Clear settings for a specific backend
    func clearSettings(for backendId: String) {
        settings.removeValue(forKey: backendId)
        userDefaults.removeObject(forKey: settingsKey + "_" + backendId)
    }
    
    /// Clear all settings
    func clearAllSettings() {
        settings.removeAll()
        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(settingsKey) }
        keys.forEach { userDefaults.removeObject(forKey: $0) }
    }
}

/// Base settings view components
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            content
        }
        .padding(.vertical, 8)
    }
}

struct SettingsRow: View {
    let label: String
    let value: String
    let icon: String?
    
    init(label: String, value: String, icon: String? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            
            Text(label)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let isSecure: Bool
    
    init(
        label: String,
        placeholder: String = "",
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

struct SettingsToggle: View {
    let label: String
    let description: String?
    @Binding var isOn: Bool
    let icon: String?
    
    init(
        label: String,
        description: String? = nil,
        isOn: Binding<Bool>,
        icon: String? = nil
    ) {
        self.label = label
        self.description = description
        self._isOn = isOn
        self.icon = icon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $isOn) {
                HStack {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                        if let description = description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct SettingsSlider: View {
    let label: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    
    init(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.1,
        format: String = "%.1f"
    ) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
        self.format = format
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
