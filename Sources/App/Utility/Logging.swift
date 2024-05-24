//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation

//As of Swift 5.3 #file is now file name instead of filepath
/*
extension Encodable {
    public func expectOrLog<T>(_ block:()->T?) -> T? {
        return SaveCloud.expectOrLog(self, block)
    }

    public func tryOrLog<T>(_ block:() throws ->T) -> T? {
        return SaveCloud.tryOrLog(self, block)
    }

    public func tryOrLog<T>(info:String, _ block:() throws ->T) -> T? {
        return SaveCloud.tryOrLog(self, info:info, block)
    }

    public func tryOrLogInput<T, R>(_ info:R, _ block:(_ input:R) throws ->T) -> T? {
        return SaveCloud.tryOrLogInput(self, info, block)
    }

    public func logExceptionSilent(_ error:Error, _ info:String? = nil) {
 SaveCloud.logExceptionSilent(self, error, info)
    }

    public func logErrorSilent(_ error:String) {
 SaveCloud.logErrorSilent(self, error)
    }

    public func logNil(_ info: String? = nil) {
 SaveCloud.logNil(self, info)
    }
}*/

public enum MessageId : UInt16, Sendable {
    case trace
    case debug
    case info
    case warning
    case error
    case fatal
    case instanceInit
    case instanceDeint
}

public struct LogMessage : LosslessStringConvertible, Sendable {
    public init(source: SourceInfo, messageId: MessageId, data: String? = nil) {
        self.source = source
        self.messageId = messageId
        self.data = data
    }
    
    public init?(_ description: String) {
        let subStr = description.substring(from: 0)
        var scanner = StringScanner(span: subStr, pos: 0, dir: 1)
        do {
            let id = try scanner.readInt64()
            try scanner.expect(c: " ")
            try scanner.expect(c: "\"")
            let typeStr = try scanner.readUntilMatch(c: "\"", maxChars: 255)
            self.source = SourceInfo(instanceId: id, type: String(typeStr))
            let messageId = try scanner.readUInt16()
            guard let msgId = MessageId(rawValue: messageId) else { return nil }
            self.messageId = msgId
            let dataStr = try scanner.read()
            if dataStr.count > 0 {
                self.data = String(dataStr)
            } else {
                self.data = nil
            }
        } catch {
            return nil
        }
    }
    
    public var description: String {
        if let data = data {
            return "\(source.description) \(messageId.rawValue) \(data)"
        } else {
            return "\(source.description) \(messageId.rawValue)"
        }
    }
    
    //2022/09/14 16:27:57:652  1235123123 "Student Sync" 123 Found 0 local only subjects.
    //let lineInfo:LineInfo
    public let source:SourceInfo
    public let messageId:MessageId
    //let dataId:UInt32 //error Id - will be embedded in string
    public let data:String?
}

public struct SourceInfo : LosslessStringConvertible, Sendable {
              
    public let instanceId:Int64
    public let type:String
    
    public init(instance: Any) {
        let mirror = Mirror(reflecting: instance)
        if (mirror.displayStyle == .class) { // Can also check via (type(of: instance) is AnyClass)
            self.instanceId = Int64(ObjectIdentifier(instance as AnyObject).hashValue)
        } else {
            self.instanceId = 0
        }
        self.type = String(describing: mirror.subjectType)
    }
    
    public init(type: String) {
        self.instanceId = 0
        self.type = URL(fileURLWithPath: type).lastPathComponent
    }
              
    public init(instanceId: Int64, type: String) {
        self.instanceId = instanceId
        self.type = type
    }
    
    public init?(_ description: String) {
        let subStr = description.substring(from: 0)
        var scanner = StringScanner(span: subStr, pos: 0, dir: 1)
        do {
            let id = try scanner.readInt64()
            try scanner.expect(c: " ")
            try scanner.expect(c: "\"")
            let typeStr = try scanner.readUntilMatch(c: "\"", maxChars: 255)
            self.instanceId = id
            self.type = String(typeStr)
        } catch {
            return nil
        }
    }
    
    public var description: String {
        return "\(instanceId) \"\(type)\""
    }
    
}

//NOTE: we could get nicer syntax if get rid of the below functions using any, but not sure if its practical to require encodable to pass instnace..
public func expectOrLog<T>(_ instance:Any, _ block:()->T?) -> T? {
    let result = block()
    if (result == nil) {
        logErrorSilent(instance, "Expected value for variable.")
    }
    return result
}

public func tryOrLog<T>(_ instance:Any, _ block:() throws ->T) -> T? {
    do {
        let result = try block()
        return result
    } catch let error {
        logExceptionSilent(instance, error)
    }
    return nil
}

public func tryOrLog<T>(_ instance:Any, info:String, _ block:() throws ->T) -> T? {
    do {
        let result = try block()
        return result
    } catch let error {
        logExceptionSilent(instance, error, info)
    }
    return nil
}

public func tryOrLogInput<T, R>(_ instance:Any, _ info:R, _ block:(_ input:R) throws ->T) -> T? {
    do {
        let result = try block(info)
        return result
    } catch let error {
        logExceptionSilent(instance, error, String.init(describing: info))
    }
    return nil
}

public func logMessage(_ instance:Any, _ messageId:MessageId, _ data:String? = nil) {
    let source = SourceInfo(instance: instance)
    let lm = LogMessage(source: source, messageId: messageId, data: data)
    writeToFile(lm.description)
}

public func logMessageFile(_ messageId:MessageId, _ data:String, file:String = #file) {
    let source = SourceInfo(type: file)
    let lm = LogMessage(source: source, messageId: messageId, data: data)
    writeToFile(lm.description)
}

//Note: Silent == Silent to the user
public func logExceptionSilent(_ instance:Any, _ error:Error, _ info:String? = nil) {
    //CrashReporter.capture(error, info: info)
    let msg = "Exception Thrown: \(String(describing:error)) - \(info ?? "")"
    logMessage(instance, .fatal, msg)
}

public func logErrorSilent(_ instance:Any, _ error:String) {
    let message = "Handled Error: \(error)"
    //CrashReporter.capture(message)
    logMessage(instance, .error, message)
}

public func logNil(_ instance:Any, _ info: String? = nil) {
    let message = "Unexpected nil \(info ?? "")"
    //CrashReporter.capture(message)
    logMessage(instance, .error, message)
}

/// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

public func expectOrLog<T>(_ sourceInfo:SourceInfo, _ block:()->T?) -> T? {
    let result = block()
    if (result == nil) {
        logErrorSilent(sourceInfo, "Expected value for variable.")
    }
    return result
}

public func tryOrLog<T>(_ sourceInfo:SourceInfo, _ block:() throws ->T) -> T? {
    do {
        let result = try block()
        return result
    } catch let error {
        logExceptionSilent(sourceInfo, error)
    }
    return nil
}

public func tryOrLog<T>(_ sourceInfo:SourceInfo, info:String, _ block:() throws ->T) -> T? {
    do {
        let result = try block()
        return result
    } catch let error {
        logExceptionSilent(sourceInfo, error, info)
    }
    return nil
}

public func tryOrLogInput<T, R>(_ sourceInfo:SourceInfo, _ info:R, _ block:(_ input:R) throws ->T) -> T? {
    do {
        let result = try block(info)
        return result
    } catch let error {
        logExceptionSilent(sourceInfo, error, String.init(describing: info))
    }
    return nil
}

public func logMessage(_ sourceInfo:SourceInfo, _ messageId:MessageId, _ data:String? = nil) {
    let lm = LogMessage(source: sourceInfo, messageId: messageId, data: data)
    writeToFile(lm.description)
    if (messageId == .error) {
        let message = "Handled Error: \(data ?? "NA")"
        //CrashReporter.capture(message) //TODO: Not sure if this makes.. will need to analyze and refactor later
    }
}

public func logExceptionSilent(_ sourceInfo:SourceInfo, _ error:Error, _ info:String? = nil) {
    //CrashReporter.capture(error, info: info)
    let msg = "Exception Thrown: \(String(describing:error)) - \(info ?? "")"
    logMessage(sourceInfo, .fatal, msg)
}

public func logErrorSilent(_ sourceInfo:SourceInfo, _ error:String) {
    let message = "Handled Error: \(error)"
    logMessage(sourceInfo, .error, message)
    //CrashReporter.capture(message)
}

public func logErrorSilentFile(_ error:String, file:String = #file) {
    let message = "Handled Error: \(error)"
    logMessage(SourceInfo(type: file), .error, message)
    //CrashReporter.capture(message)
}

public func logNil(_ sourceInfo:SourceInfo, _ info: String? = nil) {
    let message = "Unexpected nil \(info ?? "")"
    logMessage(sourceInfo, .error, message)
    //CrashReporter.capture(message)
}

public func initLoggingLock() {
    pthread_rwlock_init(&lock, nil)
}

fileprivate var lastMessage:String = ""
fileprivate var lastMessageSize:Int = 0
fileprivate var repeatCount:Int = 0
fileprivate var lock = pthread_rwlock_t() //Had this as a function to avoid initLoggingLock but that seemed to cause a race condition

public func writeToFile(_ message:String) {
    pthread_rwlock_wrlock(&lock)
    //CrashReporter.writeToFile(message)
    pthread_rwlock_unlock(&lock)
}

fileprivate func makeTag(_ function: String, _ file: String, _ line: Int) -> String {
    return "\(file) \(function)[\(line)]"
}

//log(self, .fatal, "This crashed")
//logNil(self, .error, "This crashed")
