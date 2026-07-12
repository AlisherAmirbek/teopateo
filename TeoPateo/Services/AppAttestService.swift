import CryptoKit
import DeviceCheck
import Foundation

protocol AppAttestAuthorizing {
    func authorize(_ request: URLRequest) async throws -> URLRequest
    func invalidateKey() async
}

enum AppAttestClientError: LocalizedError {
    case unsupported
    case invalidRequest
    case invalidServerResponse
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        "The coach is unavailable right now. Your message was saved."
    }
}

struct AppAttestClientData: Codable, Equatable {
    let bodySha256: String
    let challenge: String
    let method: String
    let path: String

    static func encoded(
        challenge: Data,
        requestBody: Data,
        method: String,
        path: String
    ) throws -> Data {
        let clientData = AppAttestClientData(
            bodySha256: Data(SHA256.hash(data: requestBody)).base64URLEncodedString(),
            challenge: challenge.base64URLEncodedString(),
            method: method,
            path: path
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(clientData)
    }
}

actor LiveAppAttestAuthorizer: AppAttestAuthorizing {
    private let endpointURL: URL
    private let session: URLSession
    private let service: DCAppAttestService
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let keyIDDefaultsKey = "TeoPateo.AppAttest.KeyID"
    private let registeredKeyDefaultsKey = "TeoPateo.AppAttest.RegisteredKeyID"

    init(
        endpointURL: URL,
        session: URLSession = .shared,
        service: DCAppAttestService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.endpointURL = endpointURL
        self.session = session
        self.service = service
        self.defaults = defaults
    }

    func authorize(_ request: URLRequest) async throws -> URLRequest {
        guard service.isSupported else {
            throw AppAttestClientError.unsupported
        }
        guard
            let requestBody = request.httpBody,
            let method = request.httpMethod,
            let path = request.url?.path
        else {
            throw AppAttestClientError.invalidRequest
        }

        let keyID = try await registeredKeyID()
        let challenge = try await fetchChallenge(purpose: "assertion")
        let clientData = try AppAttestClientData.encoded(
            challenge: challenge.value,
            requestBody: requestBody,
            method: method,
            path: path
        )
        let assertion = try await generateAssertion(
            keyID: keyID,
            clientDataHash: Data(SHA256.hash(data: clientData))
        )

        var authorizedRequest = request
        authorizedRequest.setValue(
            keyID,
            forHTTPHeaderField: "X-TeoPateo-App-Attest-Key-Id"
        )
        authorizedRequest.setValue(
            challenge.identifier,
            forHTTPHeaderField: "X-TeoPateo-App-Attest-Challenge-Id"
        )
        authorizedRequest.setValue(
            assertion.base64EncodedString(),
            forHTTPHeaderField: "X-TeoPateo-App-Attest-Assertion"
        )
        authorizedRequest.setValue(
            clientData.base64EncodedString(),
            forHTTPHeaderField: "X-TeoPateo-App-Attest-Client-Data"
        )
        return authorizedRequest
    }

    func invalidateKey() async {
        defaults.removeObject(forKey: keyIDDefaultsKey)
        defaults.removeObject(forKey: registeredKeyDefaultsKey)
    }

    private func registeredKeyID() async throws -> String {
        if
            let keyID = defaults.string(forKey: keyIDDefaultsKey),
            defaults.string(forKey: registeredKeyDefaultsKey) == keyID
        {
            return keyID
        }

        let keyID: String
        if let savedKeyID = defaults.string(forKey: keyIDDefaultsKey) {
            keyID = savedKeyID
        } else {
            keyID = try await generateKey()
            defaults.set(keyID, forKey: keyIDDefaultsKey)
        }

        let challenge = try await fetchChallenge(purpose: "attestation")
        do {
            let attestationObject = try await attestKey(
                keyID: keyID,
                clientDataHash: Data(SHA256.hash(data: challenge.value))
            )
            try await register(
                keyID: keyID,
                challengeID: challenge.identifier,
                attestationObject: attestationObject
            )
        } catch {
            defaults.removeObject(forKey: keyIDDefaultsKey)
            defaults.removeObject(forKey: registeredKeyDefaultsKey)
            throw error
        }
        defaults.set(keyID, forKey: registeredKeyDefaultsKey)
        return keyID
    }

    private func fetchChallenge(purpose: String) async throws -> AppAttestChallenge {
        var request = URLRequest(url: try appAttestURL(path: "/v1/app-attest/challenge"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(AppAttestChallengeRequest(purpose: purpose))
        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        let payload = try decoder.decode(AppAttestChallengeResponse.self, from: data)
        guard let value = Data(base64Encoded: payload.challenge), !value.isEmpty else {
            throw AppAttestClientError.invalidServerResponse
        }
        return AppAttestChallenge(identifier: payload.challengeID, value: value)
    }

    private func register(
        keyID: String,
        challengeID: String,
        attestationObject: Data
    ) async throws {
        var request = URLRequest(url: try appAttestURL(path: "/v1/app-attest/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(AppAttestRegistrationRequest(
            challengeID: challengeID,
            keyID: keyID,
            attestationObject: attestationObject.base64EncodedString()
        ))
        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppAttestClientError.invalidServerResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw AppAttestClientError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }

    private func appAttestURL(path: String) throws -> URL {
        guard
            var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        else {
            throw AppAttestClientError.invalidRequest
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw AppAttestClientError.invalidRequest
        }
        return url
    }

    private func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            service.generateKey { keyID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let keyID {
                    continuation.resume(returning: keyID)
                } else {
                    continuation.resume(throwing: AppAttestClientError.invalidServerResponse)
                }
            }
        }
    }

    private func attestKey(keyID: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.attestKey(keyID, clientDataHash: clientDataHash) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let object {
                    continuation.resume(returning: object)
                } else {
                    continuation.resume(throwing: AppAttestClientError.invalidServerResponse)
                }
            }
        }
    }

    private func generateAssertion(keyID: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.generateAssertion(keyID, clientDataHash: clientDataHash) { assertion, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let assertion {
                    continuation.resume(returning: assertion)
                } else {
                    continuation.resume(throwing: AppAttestClientError.invalidServerResponse)
                }
            }
        }
    }
}

private struct AppAttestChallenge {
    let identifier: String
    let value: Data
}

private struct AppAttestChallengeRequest: Encodable {
    let purpose: String
}

private struct AppAttestChallengeResponse: Decodable {
    let challengeID: String
    let challenge: String

    private enum CodingKeys: String, CodingKey {
        case challengeID = "challengeId"
        case challenge
    }
}

private struct AppAttestRegistrationRequest: Encodable {
    let challengeID: String
    let keyID: String
    let attestationObject: String

    private enum CodingKeys: String, CodingKey {
        case challengeID = "challengeId"
        case keyID = "keyId"
        case attestationObject
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
