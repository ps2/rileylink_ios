//
//  MessageTests.swift
//  OmniKitTests
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import OmniKit

class MessageTests: XCTestCase {
    
    func testMessageData() {
        // 2016-06-26T20:33:28.412197 ID1:1f01482a PTYPE:PDM SEQ:13 ID2:1f01482a B9:10 BLEN:3 BODY:0e0100802c CRC:88
        
        let msg = Message(address: 0x1f01482a, messageBlocks: [GetStatusCommand()], sequenceNum: 4)
        
        XCTAssertEqual("1f01482a10030e0100802c", msg.encoded().hexadecimalString)
    }
    
    func testMessageDecoding() {
        do {
            let msg = try Message(encodedData: Data(hexadecimalString: "1f00ee84300a1d18003f1800004297ff8128")!)
            
            XCTAssertEqual(0x1f00ee84, msg.address)
            XCTAssertEqual(12, msg.sequenceNum)
            
            let messageBlocks = msg.messageBlocks
            
            XCTAssertEqual(1, messageBlocks.count)
            
            let statusResponse = messageBlocks[0] as! StatusResponse
            
            XCTAssertEqual(50, statusResponse.reservoirLevel)
            XCTAssertEqual(TimeInterval(minutes: 4261), statusResponse.timeActive)

            XCTAssertEqual(.basalRunning, statusResponse.deliveryStatus)
            XCTAssertEqual(.aboveFiftyUnits, statusResponse.reservoirStatus)
            XCTAssertEqual(6.3, statusResponse.insulin, accuracy: 0.01)
            XCTAssertEqual(0, statusResponse.insulinNotDelivered)
            XCTAssertEqual(3, statusResponse.podMessageCounter)
            XCTAssert(statusResponse.alarms.isEmpty)

            XCTAssertEqual("1f00ee84300a1d18003f1800004297ff8128", msg.encoded().hexadecimalString)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testAssemblingMultiPacketMessage() {
        do {
            let packet1 = try Packet(encodedData: Data(hexadecimalString: "ffffffffe4ffffffff041d011b13881008340a5002070002070002030000a62b0004479420")!)
            XCTAssertEqual(packet1.data.hexadecimalString, "ffffffff041d011b13881008340a5002070002070002030000a62b00044794")
            XCTAssertEqual(packet1.packetType, .pod)

            XCTAssertThrowsError(try Message(encodedData: packet1.data)) { error in
                XCTAssertEqual(String(describing: error), "notEnoughData")
            }
            
            let packet2 = try Packet(encodedData: Data(hexadecimalString: "ffffffff861f00ee878352ff")!)
            XCTAssertEqual(packet2.address, 0xffffffff)
            XCTAssertEqual(packet2.data.hexadecimalString, "1f00ee878352")
            XCTAssertEqual(packet2.packetType, .con)
            
            let messageBody = packet1.data + packet2.data
            XCTAssertEqual(messageBody.hexadecimalString, "ffffffff041d011b13881008340a5002070002070002030000a62b000447941f00ee878352")

            let message = try Message(encodedData: messageBody)
            XCTAssertEqual(message.messageBlocks.count, 1)

        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testParsingConfigResponse() {
        do {
            let config = try ConfigResponse(encodedData: Data(hexadecimalString: "011502070002070002020000a64000097c279c1f08ced2")!)
            XCTAssertEqual(23, config.data.count)
            XCTAssertEqual(0x1f08ced2, config.address)
            XCTAssertEqual(42560, config.lot)
            XCTAssertEqual(621607, config.tid)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testParsingLongConfigResponse() {
        do {
            let message = try Message(encodedData: Data(hexadecimalString: "ffffffff041d011b13881008340a5002070002070002030000a62b000447941f00ee878352")!)
            let config = message.messageBlocks[0] as! ConfigResponse
            XCTAssertEqual(29, config.data.count)
            XCTAssertEqual(0x1f00ee87, config.address)
            XCTAssertEqual(42539, config.lot)
            XCTAssertEqual(280468, config.tid)
            XCTAssertEqual("2.7.0", String(describing: config.piVersion))
            XCTAssertEqual("2.7.0", String(describing: config.pmVersion))
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    func testParsingConfigWithPairingExpired() {
        do {
            let message = try Message(encodedData: Data(hexadecimalString: "ffffffff04170115020700020700020e0000a5ad00053030971f08686301fd")!)
            let config = message.messageBlocks[0] as! ConfigResponse
            XCTAssertEqual(.pairingExpired, config.pairingState)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    func testAssignAddressCommand() {
        do {
            // Encode
            let encoded = AssignAddressCommand(address: 0x1f01482a)
            XCTAssertEqual("07041f01482a", encoded.data.hexadecimalString)

            // Decode
            let decoded = try AssignAddressCommand(encodedData: Data(hexadecimalString: "07041f01482a")!)
            XCTAssertEqual(0x1f01482a, decoded.address)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testConfirmPairingCommand() {
        do {
            var components = DateComponents()
            components.day = 6
            components.month = 12
            components.year = 2016
            components.hour = 13
            components.minute = 47

            // Decode
            let decoded = try ConfirmPairingCommand(encodedData: Data(hexadecimalString: "03131f0218c31404060c100d2f0000a4be0004e4a1")!)
            XCTAssertEqual(0x1f0218c3, decoded.address)
            XCTAssertEqual(components, decoded.dateComponents)
            XCTAssertEqual(0x0000a4be, decoded.lot)
            XCTAssertEqual(0x0004e4a1, decoded.tid)

            // Encode
            let encoded = ConfirmPairingCommand(address: 0x1f0218c3, dateComponents: components, lot: 0x0000a4be, tid: 0x0004e4a1)
            XCTAssertEqual("03131f0218c31404060c100d2f0000a4be0004e4a1", encoded.data.hexadecimalString)            

        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testSetBolusCommand() {
        //    2017-09-11T11:07:57.476872 ID1:1f08ced2 PTYPE:PDM SEQ:18 ID2:1f08ced2 B9:18 BLEN:31 MTYPE:1a0e BODY:bed2e16b02010a0101a000340034170d000208000186a0 CRC:fd
        //    2017-09-11T11:07:57.552574 ID1:1f08ced2 PTYPE:ACK SEQ:19 ID2:1f08ced2 CRC:b8
        //    2017-09-11T11:07:57.734557 ID1:1f08ced2 PTYPE:CON SEQ:20 CON:00000000000003c0 CRC:a9

        do {
            // Decode
            let cmd = try SetInsulinScheduleCommand(encodedData: Data(hexadecimalString: "1a0ebed2e16b02010a0101a000340034")!)
            XCTAssertEqual(0xbed2e16b, cmd.nonce)
            
            if case SetInsulinScheduleCommand.DeliverySchedule.bolus(let units, let multiplier) = cmd.deliverySchedule {
                XCTAssertEqual(2.6, units)
                XCTAssertEqual(0x8, multiplier)
            } else {
                XCTFail("Expected ScheduleEntry.bolus type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let scheduleEntry = SetInsulinScheduleCommand.DeliverySchedule.bolus(units: 2.6, multiplier: 0x8)
        let cmd = SetInsulinScheduleCommand(nonce: 0xbed2e16b, deliverySchedule: scheduleEntry)
        XCTAssertEqual("1a0ebed2e16b02010a0101a000340034", cmd.data.hexadecimalString)
    }
    
    func testInsertCannula() {
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:PDM SEQ:17 ID2:1f00ee85 B9:38 BLEN:31 BODY:1a0e7e30bf16020065010050000a000a170d000064000186a0 CRC:33
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:ACK SEQ:18 ID2:1f00ee85 CRC:89
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:CON SEQ:19 CON:000000000000808c CRC:6f
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:POD SEQ:20 ID2:1f00ee85 B9:3c BLEN:10 BODY:1d570016f00a00000bff8099 CRC:86
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:ACK SEQ:21 ID2:1f00ee85 CRC:a0

        do {
            // Decode
            let cmd = try SetInsulinScheduleCommand(encodedData: Data(hexadecimalString: "1a0ebed2e16b02010a0101a000340034")!)
            XCTAssertEqual(0xbed2e16b, cmd.nonce)
            
            if case SetInsulinScheduleCommand.DeliverySchedule.bolus(let units, let multiplier) = cmd.deliverySchedule {
                XCTAssertEqual(2.6, units)
                XCTAssertEqual(0x8, multiplier)
            } else {
                XCTFail("Expected ScheduleEntry.bolus type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    
    func testBolusExtraCommand() {
        // 30U bolus
        // 170d 7c 1770 00030d40 000000000000
        
        do {
            // Decode
            let cmd = try BolusExtraCommand(encodedData: Data(hexadecimalString: "170d7c177000030d40000000000000")!)
            XCTAssertEqual(30.0, cmd.units)
            XCTAssertEqual(0x7c, cmd.byte2)
            XCTAssertEqual(Data(hexadecimalString: "00030d40"), cmd.unknownSection)

        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
        
        // Encode
        let cmd = BolusExtraCommand(units: 2.6, byte2: 0, unknownSection: Data(hexadecimalString: "000186a0")!)
        XCTAssertEqual("170d000208000186a0000000000000", cmd.data.hexadecimalString)
    }
    
    func testStatusResponseAlarmsParsing() {
        // 1d 28 0082 00 0044 46eb ff
        
        do {
            // Decode
            let status = try StatusResponse(encodedData: Data(hexadecimalString: "1d28008200004446ebff")!)
            XCTAssert(status.alarms.contains(.oneHourExpiry))
            XCTAssert(status.alarms.contains(.podExpired))
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testConfigureAlertsCommand() {
        // 79a4 10df 0502
        // Pod expires 1 minute short of 3 days
        let podSoftExpirationTime = TimeInterval(hours:72) - TimeInterval(minutes:1)
        let alertConfig1 = ConfigureAlertsCommand.AlertConfiguration(alertType: .timerLimit, audible: true, autoOffModifier: false, duration: .hours(7), expirationType: .time(podSoftExpirationTime), beepType: 0x0502)
        XCTAssertEqual("79a410df0502", alertConfig1.data.hexadecimalString)

        // 2800 1283 0602
        let podHardExpirationTime = TimeInterval(hours:79) - TimeInterval(minutes:1)
        let alertConfig2 = ConfigureAlertsCommand.AlertConfiguration(alertType: .endOfService, audible: true, autoOffModifier: false, duration: .minutes(0), expirationType: .time(podHardExpirationTime), beepType: 0x0602)
        XCTAssertEqual("280012830602", alertConfig2.data.hexadecimalString)

        // 020f 0000 0202
        let alertConfig3 = ConfigureAlertsCommand.AlertConfiguration(alertType: .autoOff, audible: false, autoOffModifier: true, duration: .minutes(15), expirationType: .time(0), beepType: 0x0202)
        XCTAssertEqual("020f00000202", alertConfig3.data.hexadecimalString)
        
        let configureAlerts = ConfigureAlertsCommand(nonce: 0xfeb6268b, configurations:[alertConfig1, alertConfig2, alertConfig3])
        XCTAssertEqual("1916feb6268b79a410df0502280012830602020f00000202", configureAlerts.data.hexadecimalString)
        
        do {
            let decoded = try ConfigureAlertsCommand(encodedData: Data(hexadecimalString: "1916feb6268b79a410df0502280012830602020f00000202")!)
            XCTAssertEqual(3, decoded.configurations.count)
            
            let config1 = decoded.configurations[0]
            XCTAssertEqual(.timerLimit, config1.alertType)
            XCTAssertEqual(true, config1.audible)
            XCTAssertEqual(false, config1.autoOffModifier)
            XCTAssertEqual(.hours(7), config1.duration)
            if case ConfigureAlertsCommand.ExpirationType.time(let duration) = config1.expirationType {
                XCTAssertEqual(podSoftExpirationTime, duration)
            }
            XCTAssertEqual(0x0502, config1.beepType)
            
            let cfg = try ConfigureAlertsCommand.AlertConfiguration(encodedData: Data(hexadecimalString: "4c0000640102")!)
            XCTAssertEqual(.lowReservoir, cfg.alertType)
            XCTAssertEqual(true, cfg.audible)
            XCTAssertEqual(false, cfg.autoOffModifier)
            XCTAssertEqual(0, cfg.duration)
            if case ConfigureAlertsCommand.ExpirationType.reservoir(let volume) = cfg.expirationType {
                XCTAssertEqual(10, volume)
            }
            XCTAssertEqual(0x0102, cfg.beepType)


        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }


    }
}

