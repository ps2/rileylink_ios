//
//  PeripheralManager+RileyLink.swift
//  xDripG5
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import CoreBluetooth
import os.log


protocol CBUUIDRawValue: RawRepresentable {}
extension CBUUIDRawValue where RawValue == String {
    var cbUUID: CBUUID {
        return CBUUID(string: rawValue)
    }
}


enum RileyLinkServiceUUID: String, CBUUIDRawValue {
    case main = "0235733B-99C5-4197-B856-69219C2A3845"
}

enum MainServiceCharacteristicUUID: String, CBUUIDRawValue {
    case data            = "C842E849-5028-42E2-867C-016ADADA9155"
    case responseCount   = "6E6C7910-B89E-43A5-A0FE-50C5E2B81F4A"
    case customName      = "D93B2AF0-1E28-11E4-8C21-0800200C9A66"
    case timerTick       = "6E6C7910-B89E-43A5-78AF-50C5E2B86F7E"
    case firmwareVersion = "30D99DC9-7C91-4295-A051-0A104D238CF2"
}


extension PeripheralManager.Configuration {
    static var rileyLink: PeripheralManager.Configuration {
        return PeripheralManager.Configuration(
            serviceCharacteristics: [
                RileyLinkServiceUUID.main.cbUUID: [
                    MainServiceCharacteristicUUID.data.cbUUID,
                    MainServiceCharacteristicUUID.responseCount.cbUUID,
                    MainServiceCharacteristicUUID.customName.cbUUID,
                    MainServiceCharacteristicUUID.timerTick.cbUUID,
                    MainServiceCharacteristicUUID.firmwareVersion.cbUUID
                ]
            ],
            notifyingCharacteristics: [
                RileyLinkServiceUUID.main.cbUUID: [
                    MainServiceCharacteristicUUID.responseCount.cbUUID
                    // TODO: Should timer tick default to on?
                ]
            ],
            valueUpdateMacros: [
                // When the responseCount changes, the data characteristic should be read.
                MainServiceCharacteristicUUID.responseCount.cbUUID: { (manager: PeripheralManager) in
                    guard let dataCharacteristic = manager.peripheral.getCharacteristicWithUUID(.data)
                    else {
                        return
                    }

                    manager.peripheral.readValue(for: dataCharacteristic)
                }
            ]
        )
    }
}


fileprivate extension CBPeripheral {
    func getCharacteristicWithUUID(_ uuid: MainServiceCharacteristicUUID, serviceUUID: RileyLinkServiceUUID = .main) -> CBCharacteristic? {
        guard let service = services?.itemWithUUID(serviceUUID.cbUUID) else {
            return nil
        }

        return service.characteristics?.itemWithUUID(uuid.cbUUID)
    }
}


extension CBCentralManager {
    func scanForPeripherals(withOptions options: [String: Any]? = nil) {
        scanForPeripherals(withServices: [RileyLinkServiceUUID.main.cbUUID], options: options)
    }
}


private let log = OSLog(category: "PeripheralManager+RileyLink")


extension PeripheralManager {
    static let expectedMaxBLELatency: TimeInterval = 2

    var timerTickEnabled: Bool {
        return peripheral.getCharacteristicWithUUID(.timerTick)?.isNotifying ?? false
    }

    func setTimerTickEnabled(_ enabled: Bool, timeout: TimeInterval = expectedMaxBLELatency, completion: ((_ error: RileyLinkDeviceError?) -> Void)? = nil) {
        perform { (manager) in
            do {
                guard let characteristic = manager.peripheral.getCharacteristicWithUUID(.timerTick) else {
                    throw PeripheralManagerError.unknownCharacteristic
                }

                try manager.setNotifyValue(enabled, for: characteristic, timeout: timeout)
                completion?(nil)
            } catch let error as PeripheralManagerError {
                completion?(.peripheralManagerError(error))
            } catch {
                assertionFailure()
            }
        }
    }

    func startIdleListening(idleTimeout: TimeInterval, channel: UInt8, timeout: TimeInterval = expectedMaxBLELatency, completion: @escaping (_ error: RileyLinkDeviceError?) -> Void) {
        perform { (manager) in
            let command = GetPacket(listenChannel: channel, timeoutMS: UInt32(clamping: Int(idleTimeout.milliseconds)))

            do {
                _ = try manager.writeCommand(command, timeout: timeout, responseType: .none)
                completion(nil)
            } catch let error as RileyLinkDeviceError {
                completion(error)
            } catch {
                assertionFailure()
            }
        }
    }

    func setCustomName(_ name: String, timeout: TimeInterval = expectedMaxBLELatency, completion: ((_ error: RileyLinkDeviceError?) -> Void)? = nil) {
        guard let value = name.data(using: .utf8) else {
            completion?(.invalidInput(name))
            return
        }

        perform { (manager) in
            do {
                guard let characteristic = manager.peripheral.getCharacteristicWithUUID(.customName) else {
                    throw PeripheralManagerError.unknownCharacteristic
                }

                try manager.writeValue(value, for: characteristic, type: .withResponse, timeout: timeout)
                completion?(nil)
            } catch let error as PeripheralManagerError {
                completion?(.peripheralManagerError(error))
            } catch {
                assertionFailure()
            }
        }
    }
}


// MARK: - Synchronous commands
extension PeripheralManager {
    enum ResponseType {
        case single
        case buffered
        case none
    }

    /// - Throws: RileyLinkDeviceError
    func writeCommandData(_ commandData: Data, awaitingUpdateWithMinimumLength: Int, timeout: TimeInterval, responseType: ResponseType) throws -> (RileyLinkResponseCode, Data) {
        guard let characteristic = peripheral.getCharacteristicWithUUID(.data) else {
            throw RileyLinkDeviceError.peripheralManagerError(.unknownCharacteristic)
        }
            
        var value = commandData
        
        // Data commands are encoded with their length as the first byte
        guard value.count <= 220 else {
            throw RileyLinkDeviceError.writeSizeLimitExceeded(maxLength: 220)
        }
        
        log.debug("RL Send: %{public}@", value.hexadecimalString)
        
        value.insert(UInt8(value.count), at: 0)
        
        do {
            switch (responseType) {
            case .single:
                return try writeCommand(value,
                                        for: characteristic, timeout: timeout)
            case .buffered:
                return try writeCommand(value,
                                        for: characteristic,
                                        timeout: timeout,
                                        awaitingUpdateWithMinimumLength: awaitingUpdateWithMinimumLength,
                                        endOfResponseMarker: 0x00
                )
            default:
                try writeValue(value, for: characteristic, type: .withResponse, timeout: timeout)
                return (.success, Data())
            }
        } catch let error as PeripheralManagerError {
            throw RileyLinkDeviceError.peripheralManagerError(error)
        }
    }
    
    /// - Throws: RileyLinkDeviceError
    func writeCommand(_ command: Command, timeout: TimeInterval, responseType: ResponseType) throws -> (RileyLinkResponseCode, Data) {
        return try writeCommandData(command.data, awaitingUpdateWithMinimumLength:command.expectedResponseLength, timeout:timeout, responseType: responseType)
    }

    /// - Throws: RileyLinkDeviceError
    func readRadioFirmwareVersion(timeout: TimeInterval, responseType: ResponseType) throws -> String {
        let (_, data) = try writeCommand(GetVersion(), timeout: timeout, responseType: responseType)
        
        guard let version = String(bytes: data, encoding: .utf8) else {
            throw RileyLinkDeviceError.invalidResponse(data)
        }

        return version
    }

    /// - Throws: RileyLinkDeviceError
    func readBluetoothFirmwareVersion(timeout: TimeInterval) throws -> String {
        guard let characteristic = peripheral.getCharacteristicWithUUID(.firmwareVersion) else {
            throw RileyLinkDeviceError.peripheralManagerError(.unknownCharacteristic)
        }

        guard let data = try readValue(for: characteristic, timeout: timeout) else {
            // TODO: This is an "unknown value" issue, not a timeout
            throw RileyLinkDeviceError.peripheralManagerError(.timeout)
        }

        guard let version = String(bytes: data, encoding: .utf8) else {
            throw RileyLinkDeviceError.invalidResponse(data)
        }

        return version
    }
}


// MARK: - Lower-level helper operations
extension PeripheralManager {

    /// - Throws:
    ///     - PeripheralManagerError
    ///     - RileyLinkResponseError
    func writeCommand(_ value: Data,
        for characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType = .withResponse,
        timeout: TimeInterval) throws -> (RileyLinkResponseCode, Data)
    {

        try runCommand(timeout: timeout) {
            if case .withResponse = type {
                addCondition(.write(characteristic: characteristic))
            }

            addCondition(.valueUpdate(characteristic: characteristic, matching: { value in
                guard let value = value, value.count > 0 else {
                    return false
                }

                log.debug("RL Recv(single): %{public}@", value.hexadecimalString)
                
                let responseCode = RileyLinkResponseCode(rawValue: value[0])
                
                switch responseCode {
                case .none:
                    // We don't recognize the error. Keep listening.
                    log.error("RileyLink response unexpected: %{public}@", String(describing: value))
                    return false
                case .commandInterrupted?:
                    // This is expected in cases where an "Idle" GetPacket command is running
                    log.debug("RileyLink response: commandInterrupted: %{public}@", String(describing: value))
                    return false
                case .rxTimeout?, .zeroData?:
                    log.debug("RileyLink response: %{public}@: %{public}@", String(describing: responseCode!), String(describing: value))
                    return true
                case .success?, .invalidParam?:
                    return true
                }
            }))

            peripheral.writeValue(value, for: characteristic, type: type)
        }

        guard let value = characteristic.value else {
            // TODO: This is an "unknown value" issue, not a timeout
            throw RileyLinkDeviceError.peripheralManagerError(.timeout)
        }

        guard value.count >= 0 else {
            // TODO: This is a empty response issue, not a timeout
            throw RileyLinkDeviceError.responseTimeout
        }

        guard let responseCode = RileyLinkResponseCode(rawValue: value[0]) else {
            throw RileyLinkDeviceError.invalidResponse(value)
        }

        return (responseCode, value.subdata(in: 1..<value.count))
        
    }

    /// - Throws: PeripheralManagerError
    func writeCommand(_ value: Data,
        for characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType = .withResponse,
        timeout: TimeInterval,
        awaitingUpdateWithMinimumLength minimumLength: Int,
        endOfResponseMarker: UInt8) throws -> (RileyLinkResponseCode, Data)
    {
        var response = Data()
        var buffer = Data()
        var responseCode: RileyLinkResponseCode = .success

        try runCommand(timeout: timeout) {
            if case .withResponse = type {
                addCondition(.write(characteristic: characteristic))
            }

            addCondition(.valueUpdate(characteristic: characteristic, matching: { value in
                
                guard let value = value else {
                    return false
                }

                log.debug("RL Recv(buffered): %{public}@", value.hexadecimalString)
                
                buffer = buffer + value

                guard let end = buffer.index(of: endOfResponseMarker) else {
                    return false
                }
                
                response = buffer.subdata(in: 0..<end)
                buffer = buffer.subdata(in: end..<buffer.count)
                
                if response.count == 1 {
                    let possibleResponseCode = RileyLinkResponseCode(rawValue: response[0])
                    switch possibleResponseCode {
                    case .none:
                        break
                    case .commandInterrupted?:
                        // This is expected in cases where an "Idle" GetPacket command is running
                        log.debug("RileyLink response error: commandInterrupted")
                        guard buffer.count > 0, let endOfSecondResponse = buffer.index(of: endOfResponseMarker) else {
                                return false
                        }
                        response = buffer.subdata(in: 0..<endOfSecondResponse)
                        responseCode = possibleResponseCode!
                    case .rxTimeout?, .zeroData?:
                        responseCode = possibleResponseCode!
                        log.debug("RileyLink response error: %{public}@: %{public}@", String(describing: responseCode), String(describing: response))
                        return true
                    default:
                        break
                    }
                }

                return response.count >= minimumLength
            }))

            peripheral.writeValue(value, for: characteristic, type: type)
        }
        
        return (responseCode, response)

    }
}
