//
//  UsageManager.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import Foundation
import Combine

@MainActor
class UsageManager: ObservableObject {
    @Published var usageData: UsageData?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let apiService: APIServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let cacheManager: CacheManagerProtocol
    private var isFetching: Bool = false

    init(
        apiService: APIServiceProtocol = APIService(),
        keychainService: KeychainServiceProtocol = KeychainService(),
        cacheManager: CacheManagerProtocol = CacheManager.shared
    ) {
        self.apiService = apiService
        self.keychainService = keychainService
        self.cacheManager = cacheManager

        // Load cached data on init
        loadCachedData()
    }

    // MARK: - Data Invalidation

    /// Invalidate stale data so UI shows loading state instead of outdated values
    func invalidateStaleData() {
        usageData = nil
        error = nil
        isLoading = true
        print("UsageManager: Stale data invalidated, UI will show loading state")
    }

    // MARK: - Fetch Usage

    func fetchUsage() async {
        guard !isFetching else {
            print("UsageManager: Fetch already in progress, skipping")
            return
        }
        isFetching = true
        defer { isFetching = false }

        isLoading = true
        error = nil

        do {
            // 1. Get Token
            guard var credentials = try keychainService.getCredentials() else {
                throw AppError.noCredentials
            }

            // 2. Refresh token if expired or expiring soon
            if !credentials.isValid || credentials.isExpiringSoon {
                print("UsageManager: Token expired or expiring soon, attempting refresh")
                credentials = try await refreshCredentials(credentials)
            }

            // 3. Fetch Data with retry
            do {
                let data = try await apiService.fetchUsageWithRetry(token: credentials.accessToken)
                self.usageData = data
                self.error = nil
                cacheManager.cacheUsageData(data)
            } catch let apiError as APIError {
                // 4. On 401, try refreshing token and retrying once
                if case .unauthorized = apiError {
                    print("UsageManager: Got 401, attempting token refresh and retry")
                    let refreshed = try await refreshCredentials(credentials)
                    let data = try await apiService.fetchUsageWithRetry(token: refreshed.accessToken)
                    self.usageData = data
                    self.error = nil
                    cacheManager.cacheUsageData(data)
                } else {
                    throw apiError
                }
            }

        } catch let error as APIError {
            self.error = AppError.from(error)
            print("UsageManager: API error - \(error)")
            loadCachedData()

        } catch let error as KeychainError {
            self.error = AppError.from(error)
            print("UsageManager: Keychain error - \(error)")

        } catch let error as AppError {
            self.error = error
            print("UsageManager: App error - \(error)")
            if error.shouldRetry {
                loadCachedData()
            }

        } catch {
            self.error = AppError.unknown(error.localizedDescription)
            print("UsageManager: Unknown error - \(error)")
        }

        isLoading = false
    }

    /// Refresh OAuth credentials and save the new token
    private func refreshCredentials(_ credentials: ClaudeCredentials) async throws -> ClaudeCredentials {
        let tokenResponse = try await apiService.refreshOAuthToken(refreshToken: credentials.refreshToken)

        let newCredentials = ClaudeCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? credentials.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            subscriptionType: credentials.subscriptionType
        )

        // Save refreshed credentials back to file
        try keychainService.updateCredentials(newCredentials)
        print("UsageManager: Token refreshed successfully, expires in \(tokenResponse.expiresIn)s")

        return newCredentials
    }

    // MARK: - Cache

    private func loadCachedData() {
        if let cached = cacheManager.getCachedUsageData(maxAge: nil) {
            // Only use cache if we don't have fresh data
            if usageData == nil {
                usageData = cached
            }
        }
    }

    /// Force refresh, ignoring cache
    func forceRefresh() async {
        cacheManager.clearCache()
        await fetchUsage()
    }

    // MARK: - Credentials Check

    var hasCredentials: Bool {
        return keychainService.hasCredentials()
    }

    func validateCredentials() async -> Bool {
        guard let credentials = try? keychainService.getCredentials() else {
            return false
        }
        return await apiService.validateToken(credentials.accessToken)
    }
}
