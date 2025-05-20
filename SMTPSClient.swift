import Foundation

class SMTPSClient: NSObject, StreamDelegate {
    var inputStream: InputStream!
    var outputStream: OutputStream!

    var step = 0
    var buffer = [UInt8](repeating: 0, count: 1024)

    func connect() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(nil, "smtp.163.com" as CFString, 465, &readStream, &writeStream)

        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()

        inputStream.delegate = self
        outputStream.delegate = self

        inputStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
        outputStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)

        inputStream.schedule(in: .current, forMode: .default)
        outputStream.schedule(in: .current, forMode: .default)

        inputStream.open()
        outputStream.open()

        RunLoop.current.run()
    }

    func send(_ command: String) {
        print("C: \(command)")
        let data = Array((command + "\r\n").utf8)
        _ = data.withUnsafeBytes {
            outputStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
        }
    }

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            let bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
            if bytesRead > 0, let response = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                print("S: \(response)")
                step += 1
                proceedSMTPStep()
            }
        case .endEncountered:
            print("连接结束")
            inputStream.close()
            outputStream.close()
        case .errorOccurred:
            print("连接错误：\(String(describing: aStream.streamError))")
        default:
            break
        }
    }

    func proceedSMTPStep() {
        switch step {
        case 1:
            send("EHLO localhost")
        case 2:
            send("AUTH LOGIN")
        case 3:
            send(Data("your_email@example.com".utf8).base64EncodedString())  // 邮箱用户名
        case 4:
            send(Data("your_email_password".utf8).base64EncodedString())  // 邮箱密码或授权码
        case 5:
            send("MAIL FROM:<your_email@example.com>")
        case 6:
            send("RCPT TO:<receiver@example.com>")
        case 7:
            send("DATA")
        case 8:
            send("""
                Subject: Hello from Swift SMTPS

                This is a test email via SMTPS.
                .
                """)
        case 9:
            send("QUIT")
            inputStream.close()
            outputStream.close()
            exit(0)
        default:
            break
        }
    }
}

let client = SMTPSClient()
client.connect()

///账户
class SMTPAccount:NSObject {
    var email: String
    var password: String

    init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

///邮件
class Mail:NSObject {
    var subject: String
    var body: String
    var to: String
    var from: String

    init(subject: String, body: String, to: String, from: String) {
        self.subject = subject
        self.body = body
        self.to = to
        self.from = from
    }
}