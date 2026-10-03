//
//  BluetoothMocks.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

#if canImport(CoreBluetooth)
@preconcurrency import CoreBluetooth
import Foundation

@testable import StateBlaster

final class BLECentralManagerMock: BLECentralManagerProtocol {
    var state: CBManagerState
    weak var centraManagerDelegate: (any BLECentralManagerDelegate)?

    private(set) var scanCalls = 0
    private(set) var connectCalls: [UUID] = []

    init(state: CBManagerState = .poweredOn) {
        self.state = state
    }

    func scanForPeripherals(
        withServices serviceUUIDs: [CBUUID]?,
        options: [String: Any]?
    ) {
        scanCalls += 1
    }

    func connect(_ peripheral: any BLEPeripheral, options: [String: Any]?) {
        connectCalls.append(peripheral.identifier)
    }

    func discover(_ peripheral: any BLEPeripheral) {
        centraManagerDelegate?.bleCentralManager(
            self,
            didDiscover: peripheral,
            advertisementData: [:],
            rssi: -50
        )
    }

    func didConnect(_ peripheral: any BLEPeripheral) {
        centraManagerDelegate?.bleCentralManager(self, didConnect: peripheral)
    }
}

final class BLEPeripheralMock: BLEPeripheral, @unchecked Sendable {
    let identifier: UUID
    let name: String?

    init(identifier: UUID, name: String? = nil) {
        self.identifier = identifier
        self.name = name
    }
}
#endif
