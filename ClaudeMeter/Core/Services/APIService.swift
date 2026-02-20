//
//  APIService.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import Foundation

/// API error response structure from Anthropic
struct APIErrorResponse: Codable {
    let type: String?
    let error: APIErrorDetail?

    struct APIErrorDetail: Codable {
        let type: String?
        let message: String?
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(statusCode: Int, message: String?)
    case unauthorized(message: String?) // 401
    case rateLimited  // 429
    case networkError(Error)
    case maxRetriesExceeded(lastError: Error?)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let code, let message):
            if let msg = message {
                return "Server error \(code): \(msg)"
            }
            return "Server error: \(code)"
        case .unauthorized(let message):
            if let msg = message {
                return "Unauthorized: \(msg)"
            }
            return "Unauthorized - check credentials"
        case .rateLimited:
            return "Rate limited - please wait"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .maxRetriesExceeded(let lastError):
            if let lastError = lastError {
                return "Maximum retries exceeded. Last error: \(lastError.localizedDescription)"
            }
            return "Maximum retries exceeded"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Retry Configuration
struct RetryConfiguration {
    var maxRetries: Int = Constants.Retry.maxRetries
    var initialDelay: TimeInterval = Constants.Retry.initialDelay
    var maxDelay: TimeInterval = Constants.Retry.maxDelay
    var multiplier: Double = Constants.Retry.multiplier

    /// Calculate delay for a given retry attempt (0-indexed)
    func delay(for attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(multiplier, Double(attempt))
        return min(delay, maxDelay)
    }
}

class APIService: APIServiceProtocol {
    private let baseURL = Constants.API.baseURL
    private let session: URLSession
    private let retryConfig: RetryConfiguration

    init(session: URLSession? = nil, retryConfig: RetryConfiguration = RetryConfiguration()) {
        if let session = session {
            self.session = session
        } else {
            // Configure URLSession with reasonable timeouts
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = Constants.API.requestTimeout
            config.timeoutIntervalForResource = Constants.API.resourceTimeout
            self.session = URLSession(configuration: config)
        }
        self.retryConfig = retryConfig
    }

    // MARK: - Endpoints
    enum Endpoint {
        case usage

        var path: String {
            switch self {
            case .usage: return Constants.API.usageEndpoint
            }
        }
    }

    // MARK: - Methods

    /// Fetch usage data without retry
    func fetchUsage(token: String) async throws -> UsageData {
        guard let url = URL(string: baseURL)?.appendingPathComponent(Endpoint.usage.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers(token: token)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                let decoder = JSONDecoder()
                // Model uses explicit CodingKeys for snake_case mapping
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(UsageData.self, from: data)
            } catch {
                throw APIError.decodingError
            }
        case 401:
            let message = parseErrorMessage(from: data)
            throw APIError.unauthorized(message: message)
        case 429:
            throw APIError.rateLimited
        case 500...599:
            let message = parseErrorMessage(from: data)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        default:
            let message = parseErrorMessage(from: data)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    /// Fetch usage data with automatic retry and exponential backoff
    func fetchUsageWithRetry(token: String) async throws -> UsageData {
        var lastError: Error = APIError.unknown(NSError(domain: "Unknown", code: -1))

        for attempt in 0..<retryConfig.maxRetries {
            do {
                return try await fetchUsage(token: token)
            } catch let error as APIError {
                lastError = error

                switch error {
                case .rateLimited:
                    // 429: Use exponential backoff
                    let delay = retryConfig.delay(for: attempt)
                    print("APIService: Rate limited, waiting \(delay)s before retry \(attempt + 1)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                case .serverError(let code, _) where code >= 500:
                    // 5xx: Wait longer before retry
                    let delay = max(retryConfig.delay(for: attempt), Constants.Retry.serverErrorMinDelay)
                    print("APIService: Server error \(code), waiting \(delay)s before retry \(attempt + 1)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                case .unauthorized:
                    // Don't retry auth errors
                    throw error

                case .networkError:
                    // Network errors: short delay and retry
                    let delay = retryConfig.delay(for: attempt)
                    print("APIService: Network error, waiting \(delay)s before retry \(attempt + 1)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                default:
                    // Other errors: don't retry
                    throw error
                }
            } catch {
                // URLSession errors (network issues)
                lastError = APIError.networkError(error)
                let delay = retryConfig.delay(for: attempt)
                print("APIService: Request failed, waiting \(delay)s before retry \(attempt + 1)")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw APIError.maxRetriesExceeded(lastError: lastError)
    }

    func validateToken(_ token: String) async -> Bool {
        do {
            _ = try await fetchUsage(token: token)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Error Parsing

    /// Extract error message from API error response body
    private func parseErrorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.error?.message
    }

    // MARK: - Headers
    private func headers(token: String) -> [String: String] {
        return [
            "Authorization": "Bearer \(token)",
            "User-Agent": Constants.API.userAgent,
            "anthropic-beta": Constants.API.anthropicBeta,
            "Accept": Constants.API.acceptType,
            "Content-Type": Constants.API.contentType
        ]
    }
}

// MARK: - OAuth Token Refresh

/// Response from the OAuth token refresh endpoint
struct OAuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int  // seconds
    let tokenType: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

extension APIService {
    /// Convenience method that automatically uses retry
    func getUsage(token: String, withRetry: Bool = true) async throws -> UsageData {
        if withRetry {
            return try await fetchUsageWithRetry(token: token)
        } else {
            return try await fetchUsage(token: token)
        }
    }

    /// Refresh an OAuth access token using the refresh token
    /// - Parameter refreshToken: The refresh token to use
    /// - Returns: New token response with fresh access token
    func refreshOAuthToken(refreshToken: String) async throws -> OAuthTokenResponse {
        guard let url = URL(string: Constants.OAuth.tokenEndpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Constants.OAuth.clientId
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data)
            throw APIError.unauthorized(message: message ?? "Token refresh failed (HTTP \(httpResponse.statusCode))")
        }

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }
}
