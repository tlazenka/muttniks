//
//  BluetoothModels.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

#if canImport(CoreBluetooth)
@preconcurrency import CoreBluetooth
import Foundation

public protocol BLECentralManagerProtocol: AnyObject {
    var state: CBManagerState { get }
    var centraManagerDelegate: (any BLECentralManagerDelegate)? { get set }

    func scanForPeripherals(
        withServices serviceUUIDs: [CBUUID]?,
        options: [String: Any]?
    )

    func connect(_ peripheral: any BLEPeripheral, options: [String: Any]?)
}

public protocol BLECentralManagerDelegate: NSObjectProtocol, CBCentralManagerDelegate {
    func bleCentralManagerDidUpdateState(_ central: any BLECentralManagerProtocol)

    func bleCentralManager(
        _ central: any BLECentralManagerProtocol,
        didDiscover peripheral: any BLEPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    )

    func bleCentralManager(
        _ central: any BLECentralManagerProtocol,
        didConnect peripheral: any BLEPeripheral
    )
}

public protocol BLEPeripheral: AnyObject, Sendable {
    var identifier: UUID { get }
    var name: String? { get }
}

extension CBCentralManager: BLECentralManagerProtocol {
    public var centraManagerDelegate: (any BLECentralManagerDelegate)? {
        get { delegate as? any BLECentralManagerDelegate }
        set { delegate = newValue }
    }

    public func connect(
        _ peripheral: any BLEPeripheral,
        options: [String: Any]? = nil
    ) {
        guard let peripheral = peripheral as? CBPeripheral else { return }
        connect(peripheral, options: options)
    }
}

extension CBPeripheral: @retroactive @unchecked Sendable {}
extension CBPeripheral: BLEPeripheral {}
#endif
