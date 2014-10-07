//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  VLXConductor.swift
//
//  Created by Dalton Cherry on 8/28/14.
//  Copyright (c) 2014 Vluxe. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation

public enum VLXConOpCode: Int {
    case Bind   = 1
    case Unbind = 2
    case Write  = 3
    case Info   = 4
    case Server = 7
    case Invite = 8
}
//This represents messages that come back from the channel
public class VLXMessage {
    var name: String?
    var body: String?
    var channelName: String?
    var opcode: VLXConOpCode?
    var additional: AnyObject?
}

public class VLXConductor : WebsocketDelegate {
    var socket: Websocket!
    var channels = Dictionary<String,((VLXMessage) -> Void)>()
    var serverChannel:((VLXMessage) -> Void)?
    
    ///url is the conductor server to connect to and authToken is the token to use.
    init(_ url: NSURL, _ authToken: String) {
        //setup and use websocket
        self.socket = Websocket(url: url)
        self.socket.delegate = self
        self.socket.headers["Token"] = authToken
    }
    ///Bind to a channel by its name and get messages from it
    public func bind(channelName: String, _ messages:((VLXMessage) -> Void)) {
        if self.channels[channelName] == nil {
            writeMessage("", channelName, .Bind, nil)
        }
        self.channels[channelName] = messages
    }
    ///Unbind from a channel by its name and stop getting messages from it
    public func unbind(channelName: String) {
        if self.channels.removeValueForKey(channelName) != nil {
            writeMessage("", channelName, .Unbind, nil)
        }
    }
    ///Bind to the "server channel" and get messages that are from the server opcode
    public func serverBind(messages:((VLXMessage) -> Void)) {
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
        writeMessage(body,channelName,.Write,additional)
    }
    ///send a message to a channel with the info opcode
    public func sendInfo(body: String, _ channelName: String, _ additional: AnyObject?) {
        writeMessage(body,channelName,.Info,additional)
    }
    ///send a invite to a channel to a user
    public func sendInvite(name: String, _ channelName: String) {
        writeMessage(name,channelName,.Invite,nil)
    }
    ///send a message to a channel with the server opcode. 
    ///note that channelName is optional in this case and is only used for context.
    public func sendServerMessage(body: String, _ channelName: String?, _ additional: AnyObject?) {
        writeMessage(body,channelName,.Server,additional)
    }
    ///writes the message to the websocket
    private func writeMessage(body: String, _ channelName: String?, _ opcode: VLXConOpCode, _ additional: AnyObject?) {
        //send the message
    }
    
    ///Websocket did connect
    public func websocketDidConnect() {
        
    }
    ///Websocket did disconnect
    public func websocketDidDisconnect(error: NSError?) {
        
    }
    ///Got an error, that is less than ideal
    public func websocketDidWriteError(error: NSError?) {
        
    }
    ///take the message and serialize it to the VLXMessage object then send it to the proper channel
    public func websocketDidReceiveMessage(text: String) {
        
    }
    ///Shouldn't get anything on this.
    public func websocketDidReceiveData(data: NSData) {
        
    }
    
}

