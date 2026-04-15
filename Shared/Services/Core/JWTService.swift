import Foundation
import Combine
import AuthenticationServices
import OSLog

/// Service responsible for JWT token management and exchange
protocol JWTServiceProtocol {
    func exchangeAppleTokenForJWT(_ credential: ASAuthorizationAppleIDCredential) -> AnyPublisher<String, Error>
    func createAppSpecificJWT(for user: User) -> AnyPublisher<String, Error>
    func refreshJWT() -> AnyPublisher<String, Error>
    func storeJWT(_ jwt: String)
    func getStoredJWT() -> String?
    func clearJWT()
    func hasValidJWT() -> Bool
    func isJWTExpired() -> Bool
}

final class RHEIRJWTService: JWTServiceProtocol {
    // MARK: - Constants
    private let authLambdaURL = "https://95yvslvl2i.execute-api.us-east-2.amazonaws.com/issueToken"
    private let jwtStorageKey = "rheir_jwt_token"
    private let jwtExpiryKey = "rheir_jwt_expiry"
    
    // MARK: - Public Methods
    
    func exchangeAppleTokenForJWT(_ credential: ASAuthorizationAppleIDCredential) -> AnyPublisher<String, Error> {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            return Fail(error: JWTError.invalidAppleToken).eraseToAnyPublisher()
        }
        
        Logger.auth.notice("Exchanging Apple identity token for RHEIR JWT.")
        Logger.auth.debug("Apple identity token length: \(tokenString.count, privacy: .public)")
        
        guard let url = URL(string: authLambdaURL) else {
            return Fail(error: JWTError.invalidURL).eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "appleIdentityToken": tokenString
        ]
        
        return performJWTRequest(url: url, payload: payload, requestType: "Apple Token Exchange")
    }
    
    func createAppSpecificJWT(for user: User) -> AnyPublisher<String, Error> {
        Logger.auth.info(
            "Creating app-specific JWT [user=\(user.id, privacy: .private(mask: .hash))]"
        )
        
        guard let url = URL(string: authLambdaURL) else {
            return Fail(error: JWTError.invalidURL).eraseToAnyPublisher()
        }
        
        let payload: [String: Any] = [
            "userID": user.id,
            "email": user.email.isEmpty ? "user@rheirhome.com" : user.email,
            "appName": "RHEIR",
            "platform": "iOS",
            "timestamp": Int(Date().timeIntervalSince1970),
            "version": "1.0",
            "requestType": "app_auth"
        ]
        
        return performJWTRequest(url: url, payload: payload, requestType: "App-Specific JWT")
            .catch { [weak self] error -> AnyPublisher<String, Error> in
                // Fallback to local JWT if Lambda doesn't support app-specific JWT yet
                if let httpError = error as? JWTError,
                   case .httpError(let statusCode, _) = httpError,
                   statusCode == 400 {
                    Logger.auth.warning("JWT Lambda does not support app-specific JWT yet; using local fallback token.")
                    let localJWT = self?.createLocalJWT(for: user) ?? "local.jwt.token"
                    return Just(localJWT)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func refreshJWT() -> AnyPublisher<String, Error> {
        // For now, return failure as we need user context to refresh
        // This could be enhanced to automatically refresh using stored refresh tokens
        return Fail(error: JWTError.refreshNotSupported).eraseToAnyPublisher()
    }
    
    func storeJWT(_ jwt: String) {
        UserDefaults.standard.set(jwt, forKey: jwtStorageKey)
        
        // Store expiry time (24 hours from now)
        let expiryDate = Date().addingTimeInterval(24 * 60 * 60)
        UserDefaults.standard.set(expiryDate, forKey: jwtExpiryKey)
        
        Logger.auth.notice("Stored 24-hour RHEIR JWT in local cache.")
    }
    
    func getStoredJWT() -> String? {
        guard !isJWTExpired() else {
            clearJWT()
            return nil
        }
        return UserDefaults.standard.string(forKey: jwtStorageKey)
    }
    
    func clearJWT() {
        UserDefaults.standard.removeObject(forKey: jwtStorageKey)
        UserDefaults.standard.removeObject(forKey: jwtExpiryKey)
        Logger.auth.notice("Cleared stored RHEIR JWT from local cache.")
    }
    
    func hasValidJWT() -> Bool {
        return getStoredJWT() != nil
    }
    
    func isJWTExpired() -> Bool {
        guard let expiryDate = UserDefaults.standard.object(forKey: jwtExpiryKey) as? Date else {
            return true // No expiry date means expired
        }
        return Date() >= expiryDate
    }
    
    // MARK: - Private Methods
    
    private func performJWTRequest(url: URL, payload: [String: Any], requestType: String) -> AnyPublisher<String, Error> {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("RHEIR-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        let payloadKeys = payload.keys.sorted().joined(separator: ",")
        Logger.auth.info(
            "Calling JWT Lambda [requestType=\(requestType, privacy: .public), url=\(url.absoluteString, privacy: .public), keys=\(payloadKeys, privacy: .public)]"
        )
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .handleEvents(
                receiveOutput: { data, response in
                    if let httpResponse = response as? HTTPURLResponse {
                        Logger.auth.debug(
                            "JWT Lambda response received [requestType=\(requestType, privacy: .public), status=\(httpResponse.statusCode, privacy: .public), bytes=\(data.count, privacy: .public)]"
                        )
                    }
                }
            )
            .tryMap { data, response -> String in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw JWTError.invalidResponse
                }
                
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                
                guard httpResponse.statusCode == 200 else {
                    throw JWTError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let jwt = json["jwt"] as? String else {
                    throw JWTError.noJWTInResponse
                }
                
                Logger.auth.notice("Successfully received JWT from Auth Lambda.")
                return jwt
            }
            .eraseToAnyPublisher()
    }
    
    private func createLocalJWT(for user: User) -> String {
        let header: [String: Any] = [
            "alg": "HS256",
            "typ": "JWT"
        ]
        
        let payload: [String: Any] = [
            "sub": user.id,
            "email": user.email.isEmpty ? "user@rheirhome.com" : user.email,
            "app": "RHEIR",
            "platform": "iOS",
            "iat": Int(Date().timeIntervalSince1970),
            "exp": Int(Date().timeIntervalSince1970) + (24 * 60 * 60), // 24 hours
            "version": "1.0"
        ]
        
        // Create a simple base64 encoded token for local development
        // In production, this should be properly signed
        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            return "local.jwt.token"
        }
        
        let headerB64 = headerData.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let payloadB64 = payloadData.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let signature = "local_signature_\(user.id.suffix(8))" // Simple signature for local use
        
        let jwt = "\(headerB64).\(payloadB64).\(signature)"
        Logger.auth.notice(
            "Created local JWT fallback [user=\(user.id, privacy: .private(mask: .hash))]"
        )
        return jwt
    }
}

// MARK: - JWT Errors
enum JWTError: LocalizedError {
    case invalidAppleToken
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case noJWTInResponse
    case refreshNotSupported
    
    var errorDescription: String? {
        switch self {
        case .invalidAppleToken:
            return "Invalid Apple identity token"
        case .invalidURL:
            return "Invalid Auth Lambda URL"
        case .invalidResponse:
            return "Invalid response from Auth Lambda"
        case .httpError(let statusCode, let body):
            return "Auth Lambda failed (\(statusCode)): \(body)"
        case .noJWTInResponse:
            return "No JWT found in Auth Lambda response"
        case .refreshNotSupported:
            return "JWT refresh not supported"
        }
    }
}
