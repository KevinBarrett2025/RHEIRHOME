import Foundation
import Combine
import os

public extension URLSession {
    /// Emits the same output as dataTaskPublisher, but logs request/response details.
    func debugDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        #if DEBUG
        os_log("➡️ Request: %{public}@ %{public}@", request.httpMethod ?? "", request.url?.absoluteString ?? "")
        if let headers = request.allHTTPHeaderFields {
            os_log("Headers: %{public}@", String(describing: headers))
        }
        if let body = request.httpBody, let str = String(data: body, encoding: .utf8) {
            os_log("Body: %{public}@", str)
        }
        #endif

        return dataTaskPublisher(for: request)
            .handleEvents(receiveOutput: { data, resp in
                #if DEBUG
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                os_log("⬅️ Response: %d", code)
                if let str = String(data: data, encoding: .utf8) {
                    os_log("Data: %{public}@", str)
                }
                #endif
            })
            .eraseToAnyPublisher()
    }
}
