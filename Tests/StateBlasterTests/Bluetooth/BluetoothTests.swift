//
//  BluetoothTests.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

#if canImport(CoreBluetooth)
@preconcurrency import CoreBluetooth
import Foundation
import Testing
@testable import StateBlaster

@Test
func scansConnectsTwoValidPeripheralsAndRejectsInvalidUUID() {
    let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    let central = BLECentralManagerMock(state: .poweredOn)
    let manager = BLEManager(centralManager: central)
    let first = BLEPeripheralMock(identifier: firstID, name: "First")
    let second = BLEPeripheralMock(identifier: secondID, name: "Second")
    let invalid = BLEPeripheralMock(
        identifier: BLEManager.invalidPeripheralUUID,
        name: "Invalid"
    )

    #expect(manager.state.kind == .idle)

    manager.scanForPeripherals()
    #expect(manager.state.kind == .scanning)
    #expect(central.scanCalls == 1)

    central.discover(first)
    #expect(manager.state.kind == .connecting)
    #expect(central.connectCalls == [firstID])

    central.didConnect(first)
    #expect(manager.state.kind == .scanning)
    #expect(manager.session.connectedPeripherals[firstID] != nil)

    central.discover(second)
    #expect(manager.state.kind == .connecting)
    #expect(central.connectCalls == [firstID, secondID])

    central.didConnect(second)
    #expect(manager.state.kind == .scanning)
    #expect(manager.session.connectedPeripherals.count == 2)

    central.discover(invalid)

    #expect(manager.state.kind == .scanning)
    #expect(central.connectCalls == [firstID, secondID])
    #expect(manager.session.discoveredPeripherals.count == 2)
    #expect(manager.session.connectedPeripherals.count == 2)
    #expect(manager.session.rejectedPeripheralIDs == [BLEManager.invalidPeripheralUUID])
    #expect(
        manager.transitionFailures == [
            .invalidPeripheralUUID(BLEManager.invalidPeripheralUUID)
        ]
    )
}

#endif
