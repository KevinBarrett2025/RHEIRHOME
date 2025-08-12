import Combine
import os

public extension Publisher {
    /// Logs every value, completion, and error to the console (or unified logging).
    func debugLog(_ prefix: String = "") -> AnyPublisher<Output, Failure> {
        #if DEBUG
        return handleEvents(
            receiveSubscription: { _ in os_log("%{public}@ — subscribed", prefix) },
            receiveOutput: { value in os_log("%{public}@ → output: %{public}@", prefix, String(describing: value)) },
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("%{public}@ — finished", prefix)
                case .failure(let err):
                    os_log("%{public}@ — failure: %{public}@", prefix, String(describing: err))
                }
            },
            receiveCancel: { os_log("%{public}@ — cancelled", prefix) }
        )
        .eraseToAnyPublisher()
        #else
        return eraseToAnyPublisher()
        #endif
    }
}
