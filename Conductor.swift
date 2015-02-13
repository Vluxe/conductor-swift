//////////////////////////////////////////////////////////////////////////////////////////////////
//
//   Conductor.swift
//
//  Created by Dalton Cherry on 8/28/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
//#if os(iOS)
//    import Starscream
//#elseif os(OSX)
//    import StarscreamOSX
//#endif

public enum ConOpCode: Int {
    case Bind   = 1
    case Unbind = 2
    case Write  = 3
    case Info   = 4
    case Server = 7
    case Invite = 8
}

enum MessageType: String {
    case name = "name"
    case channelName = "channel_name"
    case body = "body"
    case opCode = "opcode"
    case additional = "additional"
}
//This represents messages that come back from the channel
public struct Message {
    
    public var name: String?
    var body: String?
    var channelName: String?
    var opcode: ConOpCode
    var additional: AnyObject?
    
    init(body: String?, name: String?, channelName: String?, code: Int, additional: AnyObject?) {
        self.opcode = ConOpCode(rawValue: code)!
        self.name = name
        self.channelName = channelName
        self.body = body
        self.additional = additional
    }
    //create a message from a JSON string
    public static func messageFromString(jsonString: String) -> Message {
        let data = jsonString.dataUsingEncoding(NSUTF8StringEncoding)
        let dict = NSJSONSerialization.JSONObjectWithData(data!, options: .allZeros, error: nil) as Dictionary<String, AnyObject>
        let opcode = dict[MessageType.opCode.rawValue] as? Int
        return Message(body: dict[MessageType.body.rawValue] as? String, name: dict[MessageType.name.rawValue] as? String,
            channelName: dict[MessageType.channelName.rawValue] as? String, code: opcode!, additional: dict[MessageType.additional.rawValue])
   }
    // convert the data to a JSON string
    public func toJSONString() -> String {
        var dict = Dictionary<String,AnyObject>()
        
        if(body != nil) {
            dict[MessageType.body.rawValue] = body
        }
        if(name != nil) {
            dict[MessageType.name.rawValue] = name
        }
        if(channelName != nil) {
            dict[MessageType.channelName.rawValue] = channelName
        }
        if(additional != nil) {
            dict[MessageType.additional.rawValue] = additional
        }
        dict[MessageType.opCode.rawValue] = opcode.rawValue
        let data = NSJSONSerialization.dataWithJSONObject(dict, options: .allZeros, error: nil)
        return NSString(data: data!, encoding: NSUTF8StringEncoding)!
    }
}

//This is where the main logic happens
public class Conductor : WebSocketDelegate {
    var socket: WebSocket!
    var channels = Dictionary<String,((Message) -> Void)>()
    var serverChannel:((Message) -> Void)?
    var connectionStatus:((Bool) -> Void)?
    var connection = false
    var kAllMessages = "*"
    public var isConnected: Bool { return connection }
    
    ///url is the conductor server to connect to and authToken is the token to use.
    public init(_ url: NSURL, _ authToken: String) {
        //setup and use websocket
        socket = WebSocket(url: url)
        socket.delegate = self
        socket.headers["Token"] = authToken
        //socket.connect()
    }
    
    ///set the authToken of the client
    public func setAuthToken(token: String) {
        socket.headers["Token"] = token
    }
    
    ///Bind to a channel by its name and get messages from it
    public func bind(channelName: String, _ messages:((Message) -> Void)) {
        channels[channelName] = messages
        if channelName != kAllMessages {
            writeMessage("", channelName, .Bind, nil)
        }
    }
    
    ///Unbind from a channel by its name and stop getting messages from it
    public func unbind(channelName: String) {
        channels.removeValueForKey(channelName)
        if channelName != kAllMessages {
            writeMessage("", channelName, .Unbind, nil)
        }
    }
    
    ///Bind to the "server channel" and get messages that are from the server opcode
    public func serverBind(messages:((Message) -> Void)) {
        self.serverChannel = messages
    }
    
    ///UnBind to the "server channel" and get messages that are from the server opcode
    public func serverUnBind() {
        if self.serverChannel != nil {
            self.serverChannel = nil
        }
    }
    
    ///send a message to a channel with the write opcode
    public func sendMessage(body: String, _ channelName: String, _ additional: AnyObject?) {
        writeMessage(body, channelName,.Write, additional)
    }
    
    ///send a message to a channel with the info opcode
    public func sendInfo(body: String, _ channelName: String, _ additional: AnyObject?) {
        writeMessage(body, channelName,.Info, additional)
    }
    
    ///send a invite to a channel to a user
    public func sendInvite(name: String, _ channelName: String, _ additional: AnyObject? = nil) {
        writeMessage(name, channelName, .Invite, additional)
    }
    
    ///send a message to a channel with the server opcode. 
    ///note that channelName is optional in this case and is only used for context.
    public func sendServerMessage(body: String, _ channelName: String?, _ additional: AnyObject?) {
        writeMessage(body,channelName,.Server,additional)
    }
    
    ///connect to the stream, if not connected
    public func connect() {
        if !connection {
            channels.removeAll(keepCapacity: false)
            socket.connect()
        }
    }
    
    //disconnect from the stream, if connected
    public func disconnect() {
        if connection {
            channels.removeAll(keepCapacity: false)
            socket.disconnect()
        }
    }
    
    ///writes the message to the websocket
    private func writeMessage(body: String, _ channelName: String?, _ opcode: ConOpCode, _ additional: AnyObject?) {
        let message =  Message(body: body, name: nil, channelName: channelName, code: opcode.rawValue, additional: additional)
        socket.writeString(message.toJSONString())
    }
    
    //MARK: Websocket delegate methods
    
    ///Websocket did connect
    public func websocketDidConnect(ws: WebSocket) {
        connection = true
        if let status = connectionStatus {
            status(connection)
        }
    }
    
    ///Websocket did disconnect
    public func websocketDidDisconnect(ws: WebSocket, error: NSError?) {
        connection = false
        if let status = connectionStatus {
            status(connection)
        }
    }
    
    ///take the message and serialize it to the  Message object then send it to the proper channel
    public func websocketDidReceiveMessage(ws: WebSocket, text: String) {
        let message =  Message.messageFromString(text)
        if message.opcode == .Server || message.opcode == .Invite {
            if let callback = serverChannel {
               callback(message)
            }
        } else {
            if let callback = channels[message.channelName!] {
                callback(message)
            }
            if let callback = channels[kAllMessages] {
                callback(message)
            }
        }
    }
    
    ///Shouldn't get anything on this.
    public func websocketDidReceiveData(ws: WebSocket, data: NSData) {
        
    }
}
