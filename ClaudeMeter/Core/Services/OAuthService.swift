//
//  OAuthService.swift
//  ClaudeMeter
//
//  Copyright (c) 2026 puq.ai. All rights reserved.
//  Licensed under the MIT License. See LICENSE file.
//

import Foundation
import CryptoKit

/// Handles OAuth PKCE login flow for in-app authentication
class OAuthService {
    /// PKCE state held in memory during login
    private(set) var codeVerifier: String?

    // MARK: - PKCE Generation

    /// Generate a cryptographically random code verifier and its SHA-256 challenge
    func generatePKCE() -> (verifier: String, challenge: String) {
        // 32 random bytes → 43 base64url characters (meets 43-128 char requirement)
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = Data(bytes).base64URLEncoded()

        // SHA-256 hash of verifier → base64url encoded
        let hash = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(hash).base64URLEncoded()

        return (verifier, challenge)
    }

    // MARK: - Authorization

    /// Build the authorization URL and store the PKCE verifier for later exchange
    func startLogin() -> URL {
        let pkce = generatePKCE()
        self.codeVerifier = pkce.verifier

        var components = URLComponents(string: Constants.OAuth.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Constants.OAuth.clientId),
            URLQueryItem(name: "redirect_uri", value: Constants.OAuth.redirectURI),
            URLQueryItem(name: "scope", value: Constants.OAuth.scopes),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        return components.url!
    }

    // MARK: - Token Exchange

    /// Exchange an authorization code for access + refresh tokens
    func exchangeCode(_ code: String) async throws -> OAuthTokenResponse {
        guard let verifier = codeVerifier else {
            throw AppError.authenticationFailed("No PKCE verifier found. Please start login again.")
        }

        guard let url = URL(string: Constants.OAuth.tokenEndpoint) else {
            throw AppError.unknown("Invalid token endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": verifier,
            "client_id": Constants.OAuth.clientId,
            "redirect_uri": Constants.OAuth.redirectURI,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to extract error message from response
            if let errorJSON = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
               let message = errorJSON.error?.message {
                throw AppError.authenticationFailed(message)
            }
            throw AppError.authenticationFailed("Token exchange failed (HTTP \(httpResponse.statusCode))")
        }

        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)

        // Clear verifier after successful exchange
        self.codeVerifier = nil

        return tokenResponse
    }
}

// MARK: - Base64 URL Encoding

extension Data {
    /// Base64 URL encoding (no padding) as required by PKCE / RFC 7636
    func base64URLEncoded() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
