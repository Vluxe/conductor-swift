//////////////////////////////////////////////////////////////////////////////////////////////////
//
//   Conductor.swift
//
//  Created by Dalton Cherry on 8/28/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
import Starscream

public enum ConOpCode: UInt16 {
    case Bind        = 0
    case Unbind      = 1
    case Write       = 2
    case Server      = 3
    case CleanUp     = 4
    case StreamStart = 5
    case StreamEnd   = 6
    case StreamWrite = 7
}

//This represents messages that come back from the channel
public struct Message {
    public let opcode: UInt16
    let uuidSize: UInt16
    public let uuid: String
    let nameSize: UInt16
    public let channelName: String
    let bodySize: UInt32
    public let body: Data

    func marshal() -> Data {
        var buffer = Data()
        buffer.append(convertToBytes(opcode.littleEndian), count: 2)

        buffer.append(convertToBytes(uuidSize.littleEndian), count: 2)
        buffer.append(uuid.data(using: .utf8) ?? Data())

        buffer.append(convertToBytes(nameSize.littleEndian), count: 2)
        buffer.append(channelName.data(using: .utf8) ?? Data())

        buffer.append(convertToBytes(bodySize.littleEndian), count: 4)
        buffer.append(body)
        return buffer
    }

    func convertToBytes<T>(_ source: T) -> [UInt8] {
        var value = source
        let bytes = withUnsafePointer(to: &value) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: source)) {
                Array(UnsafeBufferPointer(start: $0, count: MemoryLayout.size(ofValue: source)))
            }
        }
        return bytes
    }

}

//This is where the main logic happens
public class Conductor : WebSocketDelegate {
    let socket: WebSocket
    var channels = Dictionary<String,((Message) -> Void)>()
    var serverChannel:((Message) -> Void)?
    public var connectionStatus:((Bool) -> Void)?
    var connection = false
    var kAllMessages = "*"
    public var isConnected: Bool { return connection }
    
    ///url is the conductor server to connect to and authToken is the token to use.
    public init(request: URLRequest) {
        socket = WebSocket(request: request)
        socket.delegate = self
    }
    
    ///Bind to a channel by its name and get messages from it
    public func bind(channelName: String, messages: @escaping ((Message) -> Void)) {
        channels[channelName] = messages
        if channelName != kAllMessages {
            writeMessage(opcode: .Bind, channelName: channelName, body: Data())
        }
    }
    
    ///Unbind from a channel by its name and stop getting messages from it
    public func unbind(channelName: String) {
        channels.removeValue(forKey: channelName)
        if channelName != kAllMessages {
            writeMessage(opcode: .Unbind, channelName: channelName, body: Data())
        }
    }
    
    ///Bind to the "server channel" and get messages that are from the server opcode
    public func serverBind(messages:@escaping ((Message) -> Void)) {
        self.serverChannel = messages
    }
    
    ///UnBind to the "server channel" and get messages that are from the server opcode
    public func serverUnBind() {
        if self.serverChannel != nil {
            self.serverChannel = nil
        }
    }
    
    ///send a message to a channel with the write opcode
    public func sendMessage(channelName: String, body: Data) {
        writeMessage(opcode: .Write, channelName: channelName, body: body)
    }
    
    ///send a message to a channel with the server opcode. 
    ///note that channelName is optional in this case and is only used for context.
    public func sendServerMessage(channelName: String, body: Data) {
        writeMessage(opcode: .Server, channelName: channelName, body: body)
    }
    
    ///connect to the stream, if not connected
    public func connect() {
        if !connection {
            channels.removeAll()
            socket.connect()
        }
    }
    
    //disconnect from the stream, if connected
    public func disconnect() {
        if connection {
            channels.removeAll()
            socket.disconnect()
        }
    }
    
    ///writes the message to the websocket
    private func writeMessage(opcode: ConOpCode, channelName: String, body: Data) {
        let uuid = UUID().uuidString
        let message =  Message(opcode: opcode.rawValue, uuidSize: UInt16(uuid.count), uuid: uuid, nameSize: UInt16(channelName.count), channelName: channelName, bodySize: UInt32(body.count), body: body)
        socket.write(data: message.marshal())
    }

    private func unmarshal(data: Data) -> Message {
        var offset: Int = 0
        
        //opcode
        var opcode: UInt16 = 0
        offset += read(value: &opcode, data: data, offset: offset)

        //uuid
        var uuidSize: UInt16 = 0
        offset += read(value: &uuidSize, data: data, offset: offset)

        let uuidEnd = offset + Int(uuidSize)
        let uuid = String(data: data.subdata(in: offset..<uuidEnd), encoding: .utf8) ?? ""
        offset += uuid.count

        //name
        var nameSize: UInt16 = 0
        offset += read(value: &nameSize, data: data, offset: offset)

        let nameEnd = offset + Int(nameSize)
        let channelName = String(data: data.subdata(in: offset..<nameEnd), encoding: .utf8) ?? ""
        offset += channelName.count

        //body
        var bodySize: UInt32 = 0
        offset += read(value: &bodySize, data: data, offset: offset)

        let bodyEnd = offset + Int(bodySize)
        let body = data.subdata(in: offset..<bodyEnd)

        return Message(opcode: opcode, uuidSize: uuidSize, uuid: uuid, nameSize: nameSize, channelName: channelName, bodySize: bodySize, body: body)
    }

    private func read<T>(value: inout T, data: Data, offset: Int) -> Int {
        let subEnd = offset + MemoryLayout<T>.size
        let subData = data.subdata(in: offset..<subEnd)
        value = subData.withUnsafeBytes { (ptr: UnsafePointer<T>) -> T in
            return ptr.pointee
        }
        return MemoryLayout<T>.size
    }
    
    //MARK: Websocket delegate methods
    
    ///Websocket did connect
    public func websocketDidConnect(socket: WebSocketClient) {
        connection = true
        if let status = connectionStatus {
            status(connection)
        }
    }
    
    ///Websocket did disconnect
    public func websocketDidDisconnect(socket ws: WebSocketClient, error: Error?) {
        connection = false
        if let status = connectionStatus {
            status(connection)
        }
    }

    ///everything is over binary now!
    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {

    }

    ///take the message and serialize it to the  Message object then send it to the proper channel
    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        let message = unmarshal(data: data)
        if message.opcode == ConOpCode.Server.rawValue {
            if let callback = serverChannel {
                callback(message)
            }
        } else {
            if let callback = channels[message.channelName] {
                callback(message)
            }
            if let callback = channels[kAllMessages] {
                callback(message)
            }
        }
    }
}

