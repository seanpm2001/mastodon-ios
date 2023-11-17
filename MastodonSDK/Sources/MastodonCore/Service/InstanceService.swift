//
//  InstanceService.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-10-9.
//

import Foundation
import Combine
import MastodonSDK

public final class InstanceService {
    
    var disposeBag = Set<AnyCancellable>()

    // input
    weak var apiService: APIService?
    weak var authenticationService: AuthenticationService?
    
    // output

    init(
        apiService: APIService,
        authenticationService: AuthenticationService
    ) {
        self.apiService = apiService
        self.authenticationService = authenticationService
        
        authenticationService.$mastodonAuthenticationBoxes
            .receive(on: DispatchQueue.main)
            .compactMap { $0.first?.domain }
            .removeDuplicates()     // prevent infinity loop
            .sink { [weak self] domain in
                guard let self = self else { return }
                self.updateInstance(domain: domain)
            }
            .store(in: &disposeBag)
    }
    
}

extension InstanceService {
    func updateInstance(domain: String) {
        guard let apiService = self.apiService else { return }
        apiService.instance(domain: domain)
            .flatMap { [unowned self] response -> AnyPublisher<Void, Error> in
                if response.value.version?.majorServerVersion(greaterThanOrEquals: 4) == true {
                    return apiService.instanceV2(domain: domain)
                        .flatMap { return self.updateInstanceV2(domain: domain, response: $0) }
                        .eraseToAnyPublisher()
                } else {
                    return self.updateInstance(domain: domain, response: response)
                }
            }
//            .flatMap { [unowned self] response -> AnyPublisher<Void, Error> in
//                return
//            }
            .sink { _ in
            } receiveValue: { [weak self] response in
                guard let _ = self else { return }
                // do nothing
            }
            .store(in: &disposeBag)
    }
    
    private func updateInstance(domain: String, response: Mastodon.Response.Content<Mastodon.Entity.Instance>) -> AnyPublisher<Void, Error> {
        AuthenticationServiceProvider.shared.update(instance: response.value, where: domain)
        return Just(Void()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    private func updateInstanceV2(domain: String, response: Mastodon.Response.Content<Mastodon.Entity.V2.Instance>) -> AnyPublisher<Void, Error> {
        AuthenticationServiceProvider.shared.update(instanceV2: response.value, where: domain)
        return Just(Void()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}

public extension InstanceService {
    func updateMutesAndBlocks() {
        Task {
            for authBox in authenticationService?.mastodonAuthenticationBoxes ?? [] {
                do {
                    try await apiService?.getMutes(
                        authenticationBox: authBox
                    )
                    
                    try await apiService?.getBlocked(
                        authenticationBox: authBox
                    )
                    
                } catch {
                }
            }
        }
    }
}
