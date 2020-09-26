//
//  File.swift
//  
//
//  Created by daniele on 26/09/2020.
//

import Foundation
import CoreLocation

internal let IPServiceDecoder = CodingUserInfoKey(rawValue: "decoder")!

public enum IPServiceDecoders {
    case ipstack // IPStackService
    case ipdata // IPDataService
}

public protocol IPService: class {
    
    /// Decoder userd to read data from service.
    var jsonServiceDecoder: IPServiceDecoders { get }
    
    /// Timeout interval for request.
    var timeout: TimeInterval { get set }
    
    /// URLSession used to perform network call.
    var session: URLSession { get set }
    
    /// Active network call data task.
    var task: URLSessionDataTask? { get set }
    
    /// `true` if task received cancel command  when removed from request.
    var isCancelled: Bool { get set }
    
    /// Create the request.
    func buildRequest() throws -> URLRequest
    
    /// Execute network request and produce result.
    /// - Parameter completion: completion block.
    func execute(_ completion: @escaping ((Result<IPLocation, LocatorErrors>) -> Void))
    
    /// Cancel active request.
    func cancel()
    
}

// MARK: - IPService Extension

public extension IPService {
    
    func execute(_ completion: @escaping ((Result<IPLocation, LocatorErrors>) -> Void)) {
        do {
            let request = try buildRequest()
            self.task = session.dataTask(with: request) { [weak self] (data, response, error) in
                guard let self = self, self.isCancelled == false else {
                    completion(.failure(.cancelled))
                    return
                }
                
                if let error = error { // a generic error has occurred
                    completion(.failure(.generic(error)))
                    return
                }
                
                // not expected response
                guard let response = response as? HTTPURLResponse,
                      response.statusCode == 200,
                      let data = data else {
                    completion(.failure(.internalError))
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    decoder.userInfo = [IPServiceDecoder : self.jsonServiceDecoder]
                    let location = try decoder.decode(IPLocation.self, from: data)
                    completion(.success(location))
                } catch {
                    completion(.failure(.parsingError))
                }
                
            }
            task?.resume()
        } catch {
            completion(.failure(.internalError))
        }
    }
    
    func cancel() {
        guard isCancelled == false else {
            return
        }
        
        isCancelled = true
        task?.cancel()
    }
    
}
