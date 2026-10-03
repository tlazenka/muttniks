//
//  BluetoothManager.swift
//  StateBlaster
//
//  Created by Francis Lazenka on 9/15/26.
//

#if canImport(CoreBluetooth)
@preconcurrency import CoreBluetooth
import Foundation
import StateBlaster

public final class BLESession: @unchecked Sendable {
    public var managerState: CBManagerState = .unknown
    public var discoveredPeripherals: [UUID: any BLEPeripheral] = [:]
    public var connectedPeripherals: [UUID: any BLEPeripheral] = [:]
    public var rejectedPeripheralIDs: [UUID] = []
}

public enum BLETransitionFailure: Equatable, Sendable {
    case invalidPeripheralUUID(UUID)
    case unexpectedPeripheral(expected: UUID, actual: UUID)
}

@StateMachine(mode: .transitionAuthority)
public enum BLECentralState {
    @MachineState(initial: true, transitions: ["unavailable", "idle"])
    case unknown(session: BLESession)

    @MachineState(transitions: ["idle"])
    case unavailable(session: BLESession)

    @MachineState(transitions: ["scanning", "unavailable"])
    case idle(session: BLESession)

    @MachineState(transitions: ["connecting", "unavailable"])
    case scanning(session: BLESession)

    @MachineState(transitions: ["scanning", "unavailable"])
    case connecting(session: BLESession, targetPeripheral: any BLEPeripheral)
}

@StateMachineModel(BLECentralState.self)
public final class BLEManager: NSObject {
    public typealias Machine = BLECentralStateMachine

    public static let invalidPeripheralUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    public var centralManager: (any BLECentralManagerProtocol)!
    public private(set) var state: Machine.State
    public private(set) var transitionFailures: [BLETransitionFailure] = []
    public let session: BLESession

    public init(centralManager: any BLECentralManagerProtocol) {
        let session = BLESession()
        self.session = session
        self.state = Machine.initialState(session: session)
        super.init()

        self.centralManager = centralManager
        self.centralManager.centraManagerDelegate = self
        updateManagerState()
    }

    public func scanForPeripherals() {
        guard case .idle(let witness, _) = state,
            let authority = machine.authorizeScanningFromIdle(using: witness)
        else {
            return
        }

        machine.state = .scanning(consume authority)
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func updateManagerState() {
        session.managerState = centralManager.state

        if centralManager.state == .poweredOn {
            switch state {
            case .unknown(let witness, _):
                guard let authority = machine.authorizeIdleFromUnknown(using: witness) else { return }
                machine.state = .idle(consume authority)
            case .unavailable(let witness, _):
                guard let authority = machine.authorizeIdleFromUnavailable(using: witness) else { return }
                machine.state = .idle(consume authority)
            default:
                break
            }
        } else {
            switch state {
            case .unknown(let witness, _):
                guard let authority = machine.authorizeUnavailableFromUnknown(using: witness) else { return }
                machine.state = .unavailable(consume authority)
            case .idle(let witness, _):
                guard let authority = machine.authorizeUnavailableFromIdle(using: witness) else { return }
                machine.state = .unavailable(consume authority)
            case .scanning(let witness, _):
                guard let authority = machine.authorizeUnavailableFromScanning(using: witness) else { return }
                machine.state = .unavailable(consume authority)
            case .connecting(let witness, _, _):
                guard let authority = machine.authorizeUnavailableFromConnecting(using: witness) else { return }
                machine.state = .unavailable(consume authority)
            case .unavailable:
                break
            }
        }
    }
}

extension BLEManager: BLECentralManagerDelegate {
    public func bleCentralManagerDidUpdateState(_ central: any BLECentralManagerProtocol) {
        updateManagerState()
    }

    public func bleCentralManager(
        _ central: any BLECentralManagerProtocol,
        didDiscover peripheral: any BLEPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard case .scanning(let witness, _) = state else { return }

        guard peripheral.identifier != Self.invalidPeripheralUUID else {
            session.rejectedPeripheralIDs.append(peripheral.identifier)
            transitionFailures.append(.invalidPeripheralUUID(peripheral.identifier))
            return
        }

        session.discoveredPeripherals[peripheral.identifier] = peripheral

        guard let authority = machine.authorizeConnecting(using: witness) else { return }
        machine.state = .connecting(consume authority, targetPeripheral: peripheral)
        centralManager.connect(peripheral, options: nil)
    }

    public func bleCentralManager(
        _ central: any BLECentralManagerProtocol,
        didConnect peripheral: any BLEPeripheral
    ) {
        guard case .connecting(let witness, _, let expected) = state else { return }

        guard expected.identifier == peripheral.identifier else {
            transitionFailures.append(
                .unexpectedPeripheral(
                    expected: expected.identifier,
                    actual: peripheral.identifier
                )
            )
            return
        }

        session.connectedPeripherals[peripheral.identifier] = peripheral

        guard let authority = machine.authorizeScanningFromConnecting(using: witness) else { return }
        machine.state = .scanning(consume authority)
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bleCentralManagerDidUpdateState(central)
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        bleCentralManager(
            central,
            didDiscover: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI
        )
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        bleCentralManager(central, didConnect: peripheral)
    }
}
#endif
